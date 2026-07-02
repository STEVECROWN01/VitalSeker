import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/offline_cache_service.dart';
import 'core/services/supabase_service.dart';
import 'core/config/supabase_config.dart';

/// STEP-DIAGNOSTIC main() — runApp() FIRST, then initialize services.
///
/// CRITICAL: The previous version awaited Supabase.initialize() BEFORE
/// runApp(), which hung the Dart isolate before any UI could render.
/// The native Android splash stayed visible forever.
///
/// This version calls runApp() IMMEDIATELY so the native splash is
/// dismissed, then initializes services from within the diagnostic
/// overlay's initState(). Each step updates the overlay live.
void main() {
  runApp(const DiagnosticApp());
}

class DiagnosticApp extends StatelessWidget {
  const DiagnosticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DiagnosticOverlay(),
    );
  }
}

class DiagnosticOverlay extends StatefulWidget {
  const DiagnosticOverlay({super.key});

  @override
  State<DiagnosticOverlay> createState() => _DiagnosticOverlayState();
}

class _DiagnosticOverlayState extends State<DiagnosticOverlay> {
  final List<String> _steps = [];
  bool _allDone = false;

  @override
  void initState() {
    super.initState();
    // Kick off service initialization AFTER the widget is mounted,
    // so the UI renders first and we can see live progress.
    _initializeServices();
  }

  void _log(String s) {
    debugPrint('[STEP] $s');
    if (mounted) {
      setState(() {
        _steps.add(s);
      });
    }
  }

  Future<void> _initializeServices() async {
    // Step 1: Supabase
    _log('START Supabase');
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        debug: false,
      ).timeout(const Duration(seconds: 10));
      SupabaseService().markInitialized();
      _log('OK Supabase');
    } catch (e) {
      _log('FAIL Supabase: $e');
    }

    // Step 2: Hive
    _log('START Hive');
    try {
      await Hive.initFlutter().timeout(const Duration(seconds: 10));
      await OfflineCacheService().initialize().timeout(const Duration(seconds: 10));
      _log('OK Hive');
    } catch (e) {
      _log('FAIL Hive: $e');
    }

    // Step 3: dotenv
    _log('START dotenv');
    try {
      await dotenv.load(fileName: '.env', isOptional: true)
          .timeout(const Duration(seconds: 5));
      _log('OK dotenv');
    } catch (e) {
      _log('FAIL dotenv: $e');
    }

    // Step 4: OneSignal
    _log('START OneSignal');
    try {
      final onesignalAppId = dotenv.env['ONESIGNAL_APP_ID'] ??
          const String.fromEnvironment('ONESIGNAL_APP_ID', defaultValue: '');
      if (onesignalAppId.isNotEmpty) {
        OneSignal.initialize(onesignalAppId);
        _log('OK OneSignal');
      } else {
        _log('SKIP OneSignal (no App ID)');
      }
    } catch (e) {
      _log('FAIL OneSignal: $e');
    }

    // Step 5: PostHog
    _log('START PostHog');
    try {
      final posthogApiKey = dotenv.env['POSTHOG_API_KEY'] ??
          const String.fromEnvironment('POSTHOG_API_KEY', defaultValue: '');
      if (posthogApiKey.isNotEmpty) {
        final posthogConfig = PostHogConfig(posthogApiKey);
        posthogConfig.host = dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';
        await Posthog().setup(posthogConfig).timeout(const Duration(seconds: 8));
        _log('OK PostHog');
      } else {
        _log('SKIP PostHog (no API key)');
      }
    } catch (e) {
      _log('FAIL PostHog: $e');
    }

    _log('ALL DONE');
    if (mounted) {
      setState(() {
        _allDone = true;
      });
    }
  }

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
                    itemCount: _steps.length,
                    itemBuilder: (context, i) {
                      final s = _steps[i];
                      Color color = Colors.white70;
                      if (s.startsWith('OK')) color = Colors.lightGreenAccent;
                      if (s.startsWith('FAIL')) color = Colors.redAccent;
                      if (s.startsWith('START')) color = Colors.yellowAccent;
                      if (s.startsWith('SKIP')) color = Colors.white54;
                      if (s.startsWith('ALL DONE')) color = Colors.cyanAccent;
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
              Center(
                child: Text(
                  _allDone
                      ? 'All services initialized.\nApp should proceed normally.'
                      : 'If this screen stays visible, one of the\n'
                          'services is hanging. The last "START"\n'
                          'line without a matching "OK" or "FAIL"\n'
                          'is the culprit.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
