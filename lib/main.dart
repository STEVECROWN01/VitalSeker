import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/services/offline_cache_service.dart';
import 'core/services/supabase_service.dart';
import 'core/providers/auth_provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/locale_provider.dart';
import 'shared/theme/app_theme.dart';
import 'core/config/supabase_config.dart';

/// STEP-DIAGNOSTIC main().
///
/// Initializes services ONE AT A TIME and shows live progress on screen.
/// Each step has a 10-second timeout. If a step fails or times out, it's
/// logged on screen but the app continues to the next step.
///
/// After all steps complete (or fail), the real app runs.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Supabase DIRECTLY with hardcoded config (skip dotenv dependency
  // for the critical path — dotenv is a "nice to have" for overriding keys).
  final steps = <String>[];
  void logStep(String s) {
    debugPrint('[STEP] $s');
    steps.add(s);
  }

  // Step 1: Supabase (use hardcoded config — no dotenv needed)
  logStep('START Supabase');
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: false,
    ).timeout(const Duration(seconds: 10));
    SupabaseService().markInitialized();
    logStep('OK Supabase');
  } catch (e) {
    logStep('FAIL Supabase: $e');
  }

  // Step 2: Hive (offline cache)
  logStep('START Hive');
  try {
    await Hive.initFlutter().timeout(const Duration(seconds: 10));
    await OfflineCacheService().initialize().timeout(const Duration(seconds: 10));
    logStep('OK Hive');
  } catch (e) {
    logStep('FAIL Hive: $e');
  }

  // Step 3: dotenv (non-critical)
  logStep('START dotenv');
  try {
    await dotenv.load(fileName: '.env', isOptional: true)
        .timeout(const Duration(seconds: 5));
    logStep('OK dotenv');
  } catch (e) {
    logStep('FAIL dotenv: $e');
  }

  // Step 4: Sentry (with appRunner)
  logStep('START Sentry + runApp');
  final sentryDsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn.isEmpty ? null : sentryDsn;
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(
      ProviderScope(child: VitalSekerApp(initialSteps: steps)),
    ),
  );

  // Step 5: OneSignal (after app is running, non-blocking)
  logStep('START OneSignal');
  try {
    final onesignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ??
        const String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '');
    if (onesignalAppId.isNotEmpty) {
      OneSignal.initialize(onesignalAppId);
      logStep('OK OneSignal');
    } else {
      logStep('SKIP OneSignal (no App ID)');
    }
  } catch (e) {
    logStep('FAIL OneSignal: $e');
  }

  // Step 6: PostHog (after app is running, non-blocking)
  logStep('START PostHog');
  try {
    final posthogApiKey = dotenv.env['POSTHOG_API_KEY'] ??
        const String.fromEnvironment('POSTHOG_API_KEY', defaultValue: '');
    if (posthogApiKey.isNotEmpty) {
      final posthogConfig = PostHogConfig(posthogApiKey);
      posthogConfig.host = dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';
      await Posthog().setup(posthogConfig).timeout(const Duration(seconds: 8));
      logStep('OK PostHog');
    } else {
      logStep('SKIP PostHog (no API key)');
    }
  } catch (e) {
    logStep('FAIL PostHog: $e');
  }

  logStep('ALL DONE');
}

class VitalSekerApp extends ConsumerStatefulWidget {
  final List<String> initialSteps;

  const VitalSekerApp({super.key, required this.initialSteps});

  @override
  ConsumerState<VitalSekerApp> createState() => _VitalSekerAppState();
}

class _VitalSekerAppState extends ConsumerState<VitalSekerApp> {
  late List<String> _steps;

  @override
  void initState() {
    super.initState();
    _steps = List.from(widget.initialSteps);
  }

  void _addStep(String s) {
    setState(() {
      _steps.add(s);
    });
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
        // If we're still in early steps (less than 4 = before Sentry+runApp
        // completed), show the diagnostic overlay INSTEAD of the real router.
        // Once step 4 ("OK Sentry + runApp") is logged, show the real app.
        final allDone = _steps.any((s) => s.contains('ALL DONE'));
        if (!allDone) {
          return _DiagnosticOverlay(steps: _steps);
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

class _DiagnosticOverlay extends StatelessWidget {
  final List<String> steps;

  const _DiagnosticOverlay({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B7A5B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Icon(Icons.favorite, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'VitalSeker — Startup Diagnostic',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Initialization steps:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: steps.length,
                    itemBuilder: (context, i) {
                      final s = steps[i];
                      Color color = Colors.white70;
                      if (s.startsWith('OK')) color = Colors.lightGreenAccent;
                      if (s.startsWith('FAIL')) color = Colors.redAccent;
                      if (s.startsWith('START')) color = Colors.yellowAccent;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${i + 1}. $s',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'If this screen stays visible, one of the\n'
                  'services is hanging. The last "START"\n'
                  'line without a matching "OK" or "FAIL"\n'
                  'is the culprit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
