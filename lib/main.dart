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
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/offline_cache_service.dart';
import 'core/services/supabase_service.dart';
import 'core/config/supabase_config.dart';
import 'core/providers/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'shared/theme/app_theme.dart';

/// PRODUCTION main() — runApp() FIRST, then initialize services from a
/// lightweight bootstrap widget's initState().
///
/// CRITICAL LESSON LEARNED (from diagnostic builds):
///   If main() awaits ANY service init before runApp(), and that service
///   hangs, the Dart isolate never reaches runApp(), so the Flutter engine
///   never paints its first frame, and the native Android splash stays
///   visible forever.
///
///   The diagnostic confirmed all 5 services (Supabase, Hive, dotenv,
///   OneSignal, PostHog) initialize successfully within 10 seconds when
///   called from a widget initState (event loop running). So this pattern
///   is safe and correct.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation early so the first frame doesn't rotate.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Create the ProviderContainer up-front so we can invalidate providers
  // after Supabase finishes initializing in the background.
  final container = ProviderContainer();

  // Sentry FIRST (it wraps runApp via appRunner). Null DSN fallback so
  // it doesn't block if env isn't loaded yet.
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
        child: VitalSekerApp(container: container),
      ),
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

  @override
  void initState() {
    super.initState();
    // Initialize services AFTER the widget is mounted. This guarantees
    // the UI renders first (native splash dismissed) and the event loop
    // is running so timeouts fire correctly.
    _initializeServices();
  }

  Future<void> _initializeServices() async {
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
        // While services are initializing, show a branded loading screen
        // INSTEAD of the real router. This prevents the splash screen's
        // _navigateNext() from firing before Supabase is ready (which
        // would route everyone to onboarding even if they're logged in).
        if (!_servicesReady) {
          return const _StartupLoadingScreen();
        }
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
