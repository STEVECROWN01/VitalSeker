import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:app_links/app_links.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/edge_function_service.dart';
import 'core/services/offline_cache_service.dart';
import 'core/services/supabase_service.dart';
import 'core/config/supabase_config.dart';
import 'core/config/app_config.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/subscription_provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/user_profile_provider.dart';
import 'core/providers/health_passport_provider.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/app_colors.dart';

/// PRODUCTION main() — runApp() FIRST, then initialize ALL services
/// (including Sentry) from a widget's initState().
///
/// CRITICAL LESSON LEARNED (from diagnostic builds):
///   1. If main() awaits ANY service init before runApp(), the Dart
///      isolate blocks and the Flutter engine never paints its first
///      frame. Native Android splash stays visible forever.
///   2. Even SentryFlutter.init(appRunner: runApp) hangs — the await
///      on SentryFlutter.init blocks the event loop before appRunner
///      is called, so on devices where Sentry's native init is slow
///      (loading DSN, installing crash handler), the app freezes.
///
/// FIX: Call runApp() SYNCHRONOUSLY at the very first line of main().
/// Initialize Sentry (and all other services) from the widget's
/// initState() AFTER the widget tree is mounted and the event loop
/// is running.
///
/// FIX (audit H-35): wrap runApp() in runZonedGuarded so async errors
/// thrown outside the Flutter framework's zone (from _initializeServices,
/// stream subscriptions, Timer.periodic callbacks) are caught and sent
/// to Sentry. Without this, uncaught async errors hit the Dart VM's
/// uncaught error handler and are silently swallowed in release mode.
void main() {
  // Create the ProviderContainer up-front so we can invalidate providers
  // after Supabase finishes initializing in the background.
  final container = ProviderContainer();

  // Wrap runApp in runZonedGuarded so uncaught async errors reach Sentry.
  // The zone is set up BEFORE runApp so all async work inside the app
  // (including _initializeServices, connectivity listeners, periodic
  // timers) is guarded.
  runZonedGuarded(
    () {
      runApp(
        UncontrolledProviderScope(
          container: container,
          child: VitalSekerApp(container: container),
        ),
      );
    },
    (error, stackTrace) {
      // Forward to Sentry if it's been initialized. If Sentry isn't ready
      // yet (early in startup), this is a no-op — the error is at least
      // logged to console.
      Sentry.captureException(error, stackTrace: stackTrace).catchError((_) => SentryId.empty());
      debugPrint('[Zone] Uncaught async error: $error');
    },
  );
}

class VitalSekerApp extends ConsumerStatefulWidget {
  final ProviderContainer container;

  const VitalSekerApp({super.key, required this.container});

  @override
  ConsumerState<VitalSekerApp> createState() => _VitalSekerAppState();
}

class _VitalSekerAppState extends ConsumerState<VitalSekerApp>
    with WidgetsBindingObserver {
  /// Tracks whether background service initialization has finished.
  /// While false, we show a branded loading screen. Once true, we show
  /// the real app (router-driven).

  /// Subscription to connectivity changes — when the device regains
  /// network access (e.g. user comes back online after being offline),
  /// we flush the locally-queued SOS events so they finally get
  /// delivered to the user's emergency contacts.
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Periodic timer that flushes the SOS queue every 5 minutes as a
  /// safety net — catches queued events that the connectivity listener
  /// might miss (e.g. if the connectivity event fired before Supabase
  /// finished initializing).
  Timer? _sosQueueFlushTimer;

  /// Subscription to incoming deep links (`vitalseker://...` and
  /// `https://passport.vitalseker.app/...` URLs declared as intent filters
  /// in AndroidManifest.xml / Info.plist). Routes the user to the
  /// appropriate screen when the app is opened via a deep link (e.g. the
  /// password-reset email link).
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    // Register as a lifecycle observer so we can:
    //   - Cancel the periodic SOS flush timer when the app is backgrounded
    //     (battery savings — Android throttles Timer.periodic anyway, but
    //     we also avoid unnecessary Supabase edge function invocations).
    //   - Restart the periodic flush + do an immediate flush attempt when
    //     the app is resumed (catches queued events that were missed while
    //     backgrounded).
    //   - Invalidate user-scoped providers on resume so data is fresh
    //     (e.g. after the user backgrounded the app for an hour, their
    //     appointments list should auto-complete past appointments, their
    //     subscription status should re-fetch, etc.).
    WidgetsBinding.instance.addObserver(this);

    // Ensure Flutter binding is initialized (required for async work in
    // StatefulWidget initState — main() no longer calls it since main()
    // must call runApp() synchronously).
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Initialize services AFTER the widget is mounted. This guarantees
    // the UI renders first (native splash dismissed) and the event loop
    // is running so timeouts fire correctly.
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _sosQueueFlushTimer?.cancel();
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Stop the periodic flush to save battery while backgrounded.
        // Android throttles Timer.periodic anyway, but we also avoid
        // unnecessary Supabase edge function invocations.
        _sosQueueFlushTimer?.cancel();
        _sosQueueFlushTimer = null;
        break;
      case AppLifecycleState.resumed:
        // Restart the periodic flush + do an immediate flush attempt
        // (catches queued SOS/triage events that were missed while
        // backgrounded).
        _sosQueueFlushTimer ??= Timer.periodic(
          const Duration(minutes: 5),
          (_) {
            EdgeFunctionService().flushPendingSosQueue().catchError((_) => 0);
            EdgeFunctionService().flushPendingTriageQueue().catchError((_) => 0);
          },
        );
        EdgeFunctionService().flushPendingSosQueue().catchError((_) => 0);
        EdgeFunctionService().flushPendingTriageQueue().catchError((_) => 0);
        // Refresh user-scoped providers so data is fresh after resume.
        try {
          widget.container.invalidate(userProfileProvider);
          widget.container.invalidate(healthPassportProvider);
          widget.container.invalidate(subscriptionProvider);
        } catch (e) {
          debugPrint('[Lifecycle] provider invalidation on resume failed: $e');
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No action needed.
        break;
    }
  }

  Future<void> _initializeServices() async {
    // 0. Sentry (init from widget, NOT from main — main() must call
    //    runApp() synchronously to dismiss the native splash)
    try {
      final sentryDsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      await SentryFlutter.init(
        (options) {
          options.dsn = sentryDsn.isEmpty ? null : sentryDsn;
          // Reduce trace sampling in production to control Sentry cost.
          // Audit M-36 fix.
          options.tracesSampleRate = kDebugMode ? 1.0 : 0.1;
          options.environment = kDebugMode ? 'debug' : 'production';
        },
      ).timeout(const Duration(seconds: 10));
      debugPrint('[Startup] Sentry initialized');
    } catch (e) {
      debugPrint('[Startup] Sentry init failed (non-fatal): $e');
    }
    if (!mounted) return;

    // ── SOS queue flush triggers — life-safety feature ──────────────────
    // CRITICAL FIX (audit C-20): the connectivity listener and 5-minute
    // periodic timer MUST be wired up regardless of whether Supabase
    // initializes successfully. If Supabase init fails (transient outage,
    // expired publishable key, SDK bug) and these triggers are inside the
    // Supabase try/catch, the only remaining flush trigger is the next app
    // restart — a queued SOS could sit in SharedPreferences indefinitely.
    //
    // flushPendingSosQueue() is safe to call even when Supabase isn't
    // ready: it checks SupabaseService().isInitialized and the current
    // session before attempting to invoke the edge function. If Supabase
    // isn't ready, it returns 0 and leaves the events in the queue for the
    // next flush.
    //
    // We still do the initial flush attempt AFTER Supabase init (below),
    // because that's the most likely time for it to succeed.

    // (a) Connectivity listener — flush the queue on network regain.
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final hasConnection = results.any(
          (r) => r != ConnectivityResult.none,
        );
        if (hasConnection) {
          EdgeFunctionService().flushPendingSosQueue().catchError((e) {
            debugPrint('[Connectivity] SOS queue flush failed: $e');
            return 0;
          });
          // FIX: also flush the pending triage queue (was previously queued
          // but never retried — the user was told "queued for later" but
          // the request was silently dropped).
          EdgeFunctionService().flushPendingTriageQueue().catchError((e) {
            debugPrint('[Connectivity] Triage queue flush failed: $e');
            return 0;
          });
        }
      },
      onError: (e) {
        debugPrint('[Connectivity] listener error: $e');
      },
    );

    // (b) Periodic 5-minute safety-net flush.
    _sosQueueFlushTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        EdgeFunctionService().flushPendingSosQueue().catchError((e) {
          debugPrint('[Timer] SOS queue flush failed: $e');
          return 0;
        });
        EdgeFunctionService().flushPendingTriageQueue().catchError((e) {
          debugPrint('[Timer] Triage queue flush failed: $e');
          return 0;
        });
      },
    );

    // 1. Supabase (use hardcoded config — no dotenv needed for critical path)
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        debug: false,
      ).timeout(const Duration(seconds: 15));
      SupabaseService().markInitialized();
      // Refresh authStateProvider now that Supabase is ready so it
      // re-subscribes to onAuthStateChange instead of returning the
      // empty stream from the defensive fallback.
      if (mounted) {
        widget.container.invalidate(authStateProvider);
      }
      debugPrint('[Startup] Supabase initialized');

      // Initial SOS queue flush — now that Supabase is ready, attempt to
      // deliver any queued events from a previous offline session.
      try {
        await EdgeFunctionService().flushPendingSosQueue();
        debugPrint('[Startup] Pending SOS queue flushed');
      } catch (e) {
        debugPrint('[Startup] SOS queue flush failed (non-fatal): $e');
      }
      // FIX: also flush pending triage requests that were queued while offline.
      try {
        final triageFlushed = await EdgeFunctionService().flushPendingTriageQueue();
        if (triageFlushed > 0) {
          debugPrint('[Startup] Pending triage queue flushed ($triageFlushed entries)');
        }
      } catch (e) {
        debugPrint('[Startup] Triage queue flush failed (non-fatal): $e');
      }
    } catch (e) {
      debugPrint('[Startup] Supabase init failed (non-fatal): $e');
    }
    if (!mounted) return;

    // 2. dotenv (non-critical — Supabase uses hardcoded config)
    try {
      await dotenv.load(fileName: '.env', isOptional: true)
          .timeout(const Duration(seconds: 5));
      debugPrint('[Startup] .env loaded');
    } catch (e) {
      debugPrint('[Startup] .env load failed (non-fatal): $e');
    }

    // 3. Hive offline storage
    try {
      await Hive.initFlutter().timeout(const Duration(seconds: 10));
      await OfflineCacheService().initialize().timeout(const Duration(seconds: 10));
      debugPrint('[Startup] Hive + OfflineCache initialized');
    } catch (e) {
      debugPrint('[Startup] Hive init failed (non-fatal): $e');
    }

    // 4. OneSignal push notifications (requires .env for App ID)
    try {
      final onesignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ??
          const String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '');
      if (onesignalAppId.isNotEmpty) {
        OneSignal.initialize(onesignalAppId);
        OneSignal.Notifications.requestPermission(true);
        debugPrint('[Startup] OneSignal initialized');
      } else {
        debugPrint('[Startup] OneSignal skipped (no App ID)');
      }
    } catch (e) {
      debugPrint('[Startup] OneSignal init failed (non-fatal): $e');
    }

    // 5. PostHog analytics (requires .env for API key)
    try {
      final posthogApiKey = dotenv.env['POSTHOG_API_KEY'] ??
          const String.fromEnvironment('POSTHOG_API_KEY', defaultValue: '');
      if (posthogApiKey.isNotEmpty) {
        final posthogConfig = PostHogConfig(posthogApiKey);
        posthogConfig.host = dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';
        await Posthog().setup(posthogConfig).timeout(const Duration(seconds: 8));
        debugPrint('[Startup] PostHog initialized');
      } else {
        debugPrint('[Startup] PostHog skipped (no API key)');
      }
    } catch (e) {
      debugPrint('[Startup] PostHog init failed (non-fatal): $e');
    }

    // Mark services as ready — triggers rebuild to show the real app.
    if (mounted) {
      setState(() {});
    }

    // Wire up the deep-link handler — must happen AFTER Supabase init so
    // the auth state is ready when a recovery link is processed.
    _setupDeepLinkHandler();

    debugPrint('[Startup] All background services initialized');
  }

  /// Subscribe to incoming deep links and route them through the GoRouter.
  ///
  /// Supported schemes/hosts (declared as intent filters in
  /// AndroidManifest.xml and associated domains in Info.plist):
  ///   - vitalseker://reset-password  → ResetPasswordScreen
  ///   - https://passport.vitalseker.app/v/{token}  → QrDisplayScreen (TODO)
  ///
  /// The handler also processes the initial link if the app was cold-started
  /// via a deep link (app_links returns it via `getInitialLink`).
  void _setupDeepLinkHandler() {
    try {
      final appLinks = AppLinks();
      // Process the initial link (cold start).
      appLinks.getInitialLink().then((uri) {
        if (uri != null) _handleDeepLink(uri);
      }).catchError((e) {
        debugPrint('[DeepLink] getInitialLink error: $e');
      });
      // Subscribe to link stream (warm start).
      _deepLinkSub = appLinks.uriLinkStream.listen(
        (uri) => _handleDeepLink(uri),
        onError: (e) {
          debugPrint('[DeepLink] stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[DeepLink] handler setup failed (non-fatal): $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('[DeepLink] received: $uri');
    final router = ref.read(routerProvider);
    // vitalseker://reset-password
    if (uri.scheme == 'vitalseker' && uri.host == 'reset-password') {
      router.go(AppConfig.resetPassword);
      return;
    }
    // https://passport.vitalseker.app/v/{token}  → QR display (TODO: requires
    // QrDisplayScreen to accept a token parameter and fetch the passport
    // server-side rather than via the current user's health_passport).
    // For now, route to the dashboard — the deep link is logged for the
    // operator to investigate.
    if (uri.scheme == 'https' &&
        (uri.host == 'passport.vitalseker.app' || uri.host == 'vitalseker.app')) {
      debugPrint('[DeepLink] passport link — routing to dashboard (QR viewer '
          'for arbitrary tokens is not yet implemented): $uri');
      router.go(AppConfig.dashboard);
      return;
    }
    debugPrint('[DeepLink] unhandled URI: $uri');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    // Watch the RevenueCat customerInfoStream so it stays alive for the
    // entire app session. The stream invalidates subscriptionProvider +
    // isProUserAsyncProvider whenever RevenueCat's SDK observes an
    // entitlement change (purchase, webhook sync, restore, expiration).
    // This is the fix for the "user has to restart the app to see their
    // Pro plan applied" bug. Result is discarded — we only need the
    // subscription to be alive.
    ref.watch(revenueCatCustomerInfoProvider);

    return MaterialApp.router(
      title: 'VitalSeker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        // Use the ACTUAL brightness from the theme (not the user preference)
        // to set the status bar style. This handles ThemeMode.system correctly.
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark
              ? SystemUiOverlayStyle.light.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: AppColors.darkBackground,
                  systemNavigationBarIconBrightness: Brightness.light,
                )
              : SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: AppColors.lightBackground,
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
