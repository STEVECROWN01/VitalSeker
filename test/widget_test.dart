import 'package:flutter_test/flutter_test.dart';
import 'package:vitalseker/main.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VitalSekerApp());

    // Verify that the app name appears on splash
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('VitalSeker'), findsOneWidget);
  });
}
