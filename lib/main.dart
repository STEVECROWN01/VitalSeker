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
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env', isOptional: true);

  // Initialize Supabase
  await SupabaseService().initialize();

  // Initialize Hive for offline storage (per Cahier des Charges Section 2.3:
  // "Mode Hors-Ligne — Triage de base et passeport complet accessibles sans
  // internet"). Hive caches the health passport + symptom history locally.
  await Hive.initFlutter();

  // Open all Hive boxes for offline caching (passport, symptom logs, profile,
  // pending triage queue, vitals). Without this call, OfflineCacheService
  // methods silently no-op because the boxes are never opened.
  await OfflineCacheService().initialize();

  // Initialize OneSignal for push notifications (per Cahier des Charges
  // Section 3: "Notifications — OneSignal — Push notifications, rappels,
  // alertes santé"). The App ID is loaded from .env; if not set, OneSignal
  // runs in no-op mode (safe for dev).
  final onesignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ??
      const String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '');
  if (onesignalAppId.isNotEmpty) {
    OneSignal.initialize(onesignalAppId);
    // Prompt user for notification permission (can be deferred to onboarding).
    OneSignal.Notifications.requestPermission(true);
  }

  // Initialize PostHog for analytics (per Cahier des Charges Section 3:
  // "Analytics — PostHog — Tracking comportement, entonnoirs, rétention").
  // The API key is loaded from .env; if not set, PostHog is not initialized.
  final posthogApiKey = dotenv.env['POSTHOG_API_KEY'] ??
      const String.fromEnvironment('POSTHOG_API_KEY', defaultValue: '');
  if (posthogApiKey.isNotEmpty) {
    final posthogConfig = PostHogConfig(posthogApiKey);
    posthogConfig.host = dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';
    await Posthog().setup(posthogConfig);
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize flutter_animate
  Animate.restartOnHotReload = true;

  // Initialize Sentry for crash monitoring (per Cahier des Charges Section 3:
  // "Monitoring — Sentry — Suivi erreurs, crashs, disponibilité API").
  // The DSN is loaded from .env or String.fromEnvironment; if not set,
  // Sentry runs in no-op mode (safe for dev).
  final sentryDsn = dotenv.env['SENTRY_DSN'] ??
      const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn.isEmpty ? null : sentryDsn;
      options.tracesSampleRate = 1.0;
      options.environment = kDebugMode ? 'debug' : 'production';
    },
    appRunner: () => runApp(const ProviderScope(child: VitalSekerApp())),
  );
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
