import 'package:flutter/material.dart';

/// ULTRA-MINIMAL main() for diagnostic purposes.
///
/// This version does NOT initialize any services — no Sentry, no Supabase,
/// no Hive, no OneSignal, no PostHog, no dotenv. It just runs a simple
/// MaterialApp with a visible "DIAGNOSTIC MODE" screen.
///
/// If this renders, the Flutter engine is healthy and the hang is in one
/// of the service initializers. If this does NOT render, the problem is
/// native (MainActivity, AndroidManifest, or Flutter engine crash).
void main() {
  runApp(const DiagnosticApp());
}

class DiagnosticApp extends StatelessWidget {
  const DiagnosticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VitalSeker Diagnostic',
      debugShowCheckedModeBanner: false,
      home: const DiagnosticScreen(),
    );
  }
}

class DiagnosticScreen extends StatelessWidget {
  const DiagnosticScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B7A5B),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 80,
                ),
                SizedBox(height: 24),
                Text(
                  'VitalSeker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'DIAGNOSTIC MODE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 32),
                Text(
                  'If you see this screen, the Flutter engine is working.\n\n'
                  'The hang is in one of the service initializers.\n\n'
                  'Next step: add services back one by one to find the culprit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
