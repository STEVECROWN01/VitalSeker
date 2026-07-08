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
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/edge_function_service.dart';
import 'core/services/offline_cache_service.dart';
import 'core/services/supabase_service.dart';
import 'core/config/supabase_config.dart';
import 'core/providers/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
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
void main() {
  // Create the ProviderContainer up-front so we can invalidate providers
  // after Supabase finishes initializing in the background.
  final container = ProviderContainer();

  // runApp() IMMEDIATELY — no awaits, no Sentry wrapper.
  // The native splash is dismissed as soon as VitalSekerApp renders.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: VitalSekerApp(container: container),
    ),
  );
}

class VitalSekerApp extends ConsumerStatefulWidget {
  final ProviderContainer container;

  const VitalSekerApp({super.key, required this.container});

  @override
  ConsumerState<VitalSekerApp> createState() => _VitalSekerAppState();
}

class _VitalSekerAppState extends ConsumerState<VitalSekerApp> {
  /// Tracks whether background service initialization has finished.
  /// While false, we show a branded loading screen. Once true, we show
  /// the real app (router-driven).
  bool _servicesReady = false;

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

  @override
  void initState() {
    super.initState();
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
    _connectivitySub?.cancel();
    _sosQueueFlushTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    // 0. Sentry (init from widget, NOT from main — main() must call
    //    runApp() synchronously to dismiss the native splash)
    try {
      final sentryDsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      await SentryFlutter.init(
        (options) {
          options.dsn = sentryDsn.isEmpty ? null : sentryDsn;
          options.tracesSampleRate = 1.0;
          options.environment = kDebugMode ? 'debug' : 'production';
        },
      ).timeout(const Duration(seconds: 10));
      debugPrint('[Startup] Sentry initialized');
    } catch (e) {
      debugPrint('[Startup] Sentry init failed (non-fatal): $e');
    }

    // 1. Supabase (use hardcoded config — no dotenv needed for critical path)
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        debug: false,
      ).timeout(const Duration(seconds: 15));
      SupabaseService().markInitialized();
      // Refresh authStateProvider now that Supabase is ready so it
      // re-subscribes to onAuthStateChange instead of returning the
      // empty stream from the defensive fallback.
      widget.container.invalidate(authStateProvider);
      debugPrint('[Startup] Supabase initialized');

      // ── SOS queue flush — life-safety feature ──
      // If the user triggered an SOS while offline (the SOS was queued
      // locally in SharedPreferences by EdgeFunctionService.sendSosAlert),
      // we flush the queue now that Supabase is ready. We also set up:
      //   (a) a connectivity listener that flushes the queue the moment
      //       the device regains network access
      //   (b) a 5-minute periodic timer as a safety net
      // This ensures a queued SOS is NEVER silently dropped — it will be
      // delivered to the user's emergency contacts as soon as the device
      // is online, even if that's minutes or hours after the user
      // originally triggered it.
      try {
        await EdgeFunctionService().flushPendingSosQueue();
        debugPrint('[Startup] Pending SOS queue flushed');
      } catch (e) {
        debugPrint('[Startup] SOS queue flush failed (non-fatal): $e');
      }

      // (a) Connectivity listener — flush the queue on network regain.
      _connectivitySub = Connectivity().onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          // results is a list because the device may have multiple active
          // connections (e.g. wifi + mobile). If ANY of them is not "none",
          // we have connectivity.
          final hasConnection = results.any(
            (r) => r != ConnectivityResult.none,
          );
          if (hasConnection) {
            // Fire-and-forget — don't block the connectivity listener.
            EdgeFunctionService().flushPendingSosQueue().catchError((e) {
              debugPrint('[Connectivity] SOS queue flush failed: $e');
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
          });
        },
      );
    } catch (e) {
      debugPrint('[Startup] Supabase init failed (non-fatal): $e');
    }

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
      setState(() {
        _servicesReady = true;
      });
    }
    debugPrint('[Startup] All background services initialized');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

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

/// Branded loading screen shown while services initialize in the background.
///
/// Replaces the previous "frozen splash" with a clearly-visible loading
/// state. Shows the VitalSeker logo + a CircularProgressIndicator so the
/// user knows the app is alive and working.
class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B7A5B),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/images/branding/app_logo.png',
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'VitalSeker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your AI Health Companion',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
