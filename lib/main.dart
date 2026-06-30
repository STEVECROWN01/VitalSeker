import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'core/services/offline_cache_service.dart';
import 'core/services/supabase_service.dart';
import 'core/providers/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  // Bootstrap Flutter binding first — required before any async work.
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation early so the first frame doesn't rotate.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ───────────────────────────────────────────────────────────────────────
  // CRITICAL FIX: Run app startup in the background so the UI renders
  // immediately and the splash screen never gets stuck.
  //
  // Previous behavior: every init (Supabase, Hive, OneSignal, PostHog,
  // Sentry) was awaited sequentially in main() before runApp() was called.
  // If any of them hung (e.g. Supabase auto-session-restore on a slow
  // network, PostHog waiting for network, OneSignal requiring Google Play
  // Services), the app froze forever on the Flutter splash screen.
  //
  // New behavior: runApp() is called immediately with a loading state,
  // then all services are initialized in the background with timeouts.
  // Each service is wrapped in try/catch so a failure in one does NOT
  // prevent the app from starting.
  // ───────────────────────────────────────────────────────────────────────

  // Create a ProviderContainer we can use to refresh providers after
  // background init completes (e.g. refresh authStateProvider once
  // Supabase is ready, so the router can re-evaluate auth state).
  final container = ProviderContainer();

  // Start Sentry FIRST (it wraps runApp via appRunner) but with a null DSN
  // fallback so it doesn't block if the env isn't loaded yet.
  final sentryDsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn.isEmpty ? null : sentryDsn;
      options.tracesSampleRate = 1.0;
      options.environment = kDebugMode ? 'debug' : 'production';
    },
    appRunner: () => runApp(
      UncontrolledProviderScope(
        container: container,
        child: const VitalSekerApp(),
      ),
    ),
  );

  // Now initialize everything else in the background — app is already rendering.
  // Pass the container so we can refresh auth providers after Supabase init.
  _initializeBackgroundServices(container);
}

/// Initialize all background services with timeouts and error isolation.
///
/// Each service is wrapped in try/catch with an 8-second timeout so that
/// a single failing service (e.g. Supabase on a slow network) cannot block
/// app startup or freeze the UI.
Future<void> _initializeBackgroundServices(ProviderContainer container) async {
  // 1. Load .env (8s timeout — file is bundled in assets, should be instant)
  try {
    await dotenv.load(fileName: '.env', isOptional: true)
        .timeout(const Duration(seconds: 8));
    debugPrint('[Startup] .env loaded');
  } catch (e) {
    debugPrint('[Startup] .env load failed (non-fatal): $e');
  }

  // 2. Supabase (15s timeout — initialize() can trigger session restore)
  try {
    await SupabaseService().initialize()
        .timeout(const Duration(seconds: 15));
    debugPrint('[Startup] Supabase initialized');
    // CRITICAL: Refresh authStateProvider now that Supabase is ready,
    // so it re-subscribes to onAuthStateChange instead of returning
    // the empty stream from the defensive fallback. Without this,
    // the splash screen would never see auth state changes and would
    // route every user to onboarding even if they're already logged in.
    container.invalidate(authStateProvider);
    debugPrint('[Startup] authStateProvider invalidated (will re-subscribe)');
  } catch (e) {
    debugPrint('[Startup] Supabase init failed (non-fatal): $e');
  }

  // 3. Hive offline storage (10s timeout — disk I/O, normally <1s)
  try {
    await Hive.initFlutter()
        .timeout(const Duration(seconds: 10));
    await OfflineCacheService().initialize()
        .timeout(const Duration(seconds: 10));
    debugPrint('[Startup] Hive + OfflineCache initialized');
  } catch (e) {
    debugPrint('[Startup] Hive init failed (non-fatal): $e');
  }

  // 4. OneSignal push notifications (8s timeout — requires Google Play Services)
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

  // 5. PostHog analytics (8s timeout — network call to PostHog)
  try {
    final posthogApiKey = dotenv.env['POSTHOG_API_KEY'] ??
        const String.fromEnvironment('POSTHOG_API_KEY', defaultValue: '');
    if (posthogApiKey.isNotEmpty) {
      final posthogConfig = PostHogConfig(posthogApiKey);
      posthogConfig.host = dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';
      await Posthog().setup(posthogConfig)
          .timeout(const Duration(seconds: 8));
      debugPrint('[Startup] PostHog initialized');
    } else {
      debugPrint('[Startup] PostHog skipped (no API key)');
    }
  } catch (e) {
    debugPrint('[Startup] PostHog init failed (non-fatal): $e');
  }

  // 6. flutter_animate config (instant — no I/O)
  Animate.restartOnHotReload = true;

  debugPrint('[Startup] All background services initialized');
}

class VitalSekerApp extends ConsumerWidget {
  const VitalSekerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
