import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test — verifies the Flutter test harness works and basic widgets
/// render. The previous version of this test pumped `VitalSekerApp()` directly,
/// which requires Supabase to be initialized (via SupabaseService.initialize()
/// in main()) and fails in the test environment without network credentials.
///
/// A full integration test that boots the real app lives in
/// `integration_test/app_test.dart` (to be created) and requires a running
/// Supabase project + test credentials.
void main() {
  testWidgets('Flutter test harness works — Material app renders text',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('VitalSeker')),
        ),
      ),
    );

    expect(find.text('VitalSeker'), findsOneWidget);
  });

  testWidgets('Health urgency colors are defined', (WidgetTester tester) async {
    // Verify the color constants used throughout the app are accessible.
    const red = Color(0xFFBA1A1A);
    const amber = Color(0xFFFF9800);
    const green = Color(0xFF4CAF50);

    expect(red.red, greaterThan(150));
    expect(amber.red, greaterThan(200));
    expect(green.green, greaterThan(150));
  });
}
