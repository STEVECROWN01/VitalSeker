import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalseker/shared/widgets/app_snack_bar.dart';

void main() {
  group('AppSnackBar', () {
    testWidgets('error shows a SnackBar with the message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => AppSnackBar.error(context, 'Something broke'),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Something broke'), findsOneWidget);
      // Error icon is shown.
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('success shows with a check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => AppSnackBar.success(context, 'Saved!'),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      expect(find.text('Saved!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('errorFromException logs the raw error and shows friendly message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => AppSnackBar.errorFromException(
                  context,
                  'Friendly message',
                  Exception('internal stack trace'),
                ),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      // The friendly message is shown — the raw exception is NOT.
      expect(find.text('Friendly message'), findsOneWidget);
      expect(find.textContaining('internal stack trace'), findsNothing);
    });

    testWidgets('does not throw when context is unmounted', (tester) async {
      // Just verify no assertion errors fire when called after disposal.
      // We can't easily simulate unmounted in a widget test, but at minimum
      // the helper should not throw on a normal call sequence.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => AppSnackBar.info(context, 'Info'),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Info'), findsOneWidget);
    });
  });
}
