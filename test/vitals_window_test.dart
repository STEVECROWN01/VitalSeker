import 'package:flutter_test/flutter_test.dart';
import 'package:vitalseker/core/models/vital.dart';

void main() {
  group('VitalType enum', () {
    test('has all 7 expected types', () {
      expect(VitalType.values.length, 7);
      expect(VitalType.values, contains(VitalType.heartRate));
      expect(VitalType.values, contains(VitalType.bloodPressure));
      expect(VitalType.values, contains(VitalType.spO2));
      expect(VitalType.values, contains(VitalType.temperature));
      expect(VitalType.values, contains(VitalType.weight));
      expect(VitalType.values, contains(VitalType.bloodGlucose));
      expect(VitalType.values, contains(VitalType.respiratoryRate));
    });

    test('each type exposes a displayName, unit, and non-null color/icon', () {
      for (final t in VitalType.values) {
        expect(t.displayName, isNotEmpty);
        expect(t.unit, isNotEmpty);
        expect(t.color, isNotNull);
        expect(t.icon, isNotNull);
      }
    });
  });

  group('Vital model', () {
    final now = DateTime.now();

    Vital makeVital({
      required VitalType type,
      required double value,
      double? valueSecondary,
      DateTime? recordedAt,
    }) {
      return Vital(
        id: 'v1',
        userId: 'u1',
        type: type,
        value: value,
        valueSecondary: valueSecondary,
        recordedAt: recordedAt ?? now,
        source: 'manual',
        createdAt: now,
      );
    }

    test('blood pressure shows systolic/diastolic in displayValue', () {
      final v = makeVital(
        type: VitalType.bloodPressure,
        value: 120,
        valueSecondary: 80,
      );
      expect(v.displayValue.contains('120'), isTrue);
      expect(v.displayValue.contains('80'), isTrue);
    });

    test('segment-window filtering helper logic', () {
      // Simulates the windowing logic used by the VitalsScreen segment control.
      // The actual screen uses .where((v) => v.recordedAt.isAfter(windowStart))
      // on a List<Vital>, so we replicate that here to make sure the boundaries
      // behave as expected for the Day / Week / Month durations.
      final now = DateTime.now();
      final vitals = [
        makeVital(type: VitalType.heartRate, value: 70, recordedAt: now.subtract(const Duration(minutes: 30))),
        makeVital(type: VitalType.heartRate, value: 72, recordedAt: now.subtract(const Duration(days: 3))),
        makeVital(type: VitalType.heartRate, value: 75, recordedAt: now.subtract(const Duration(days: 20))),
        makeVital(type: VitalType.heartRate, value: 80, recordedAt: now.subtract(const Duration(days: 90))),
      ];

      Duration windowFor(int segment) {
        if (segment == 0) return const Duration(days: 1);
        if (segment == 1) return const Duration(days: 7);
        return const Duration(days: 30);
      }

      // Day window: only the 30-minute-ago reading
      final day = vitals.where((v) => v.recordedAt.isAfter(now.subtract(windowFor(0)))).toList();
      expect(day.length, 1);
      expect(day.first.value, 70);

      // Week window: 30m + 3d readings
      final week = vitals.where((v) => v.recordedAt.isAfter(now.subtract(windowFor(1)))).toList();
      expect(week.length, 2);

      // Month window: 30m + 3d + 20d readings
      final month = vitals.where((v) => v.recordedAt.isAfter(now.subtract(windowFor(2)))).toList();
      expect(month.length, 3);

      // The 90-day-ago reading is excluded from all three windows.
      expect(day.any((v) => v.value == 80), isFalse);
      expect(week.any((v) => v.value == 80), isFalse);
      expect(month.any((v) => v.value == 80), isFalse);
    });
  });
}
