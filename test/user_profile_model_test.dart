import 'package:flutter_test/flutter_test.dart';
import 'package:vitalseker/core/models/user_profile.dart';

void main() {
  group('UserProfile model', () {
    test('round-trips basic fields through fromJson/toJson', () {
      final json = {
        'id': 'user-1',
        'email': 'test@example.com',
        'full_name': 'Test User',
        'phone': '+1234567890',
        'avatar_url': 'https://example.com/avatar.png',
        'date_of_birth': '1990-05-15T00:00:00.000Z',
        'blood_type': 'O+',
        'allergies': ['peanuts', 'shellfish'],
        'chronic_conditions': ['asthma'],
        'emergency_contacts': [
          {'name': 'Jane', 'phone': '+15551234', 'relationship': 'Spouse'}
        ],
        'preferred_language': 'en',
        'theme_preference': 'dark',
        'onboarding_completed': true,
        'gender': 'Female',
        'height_cm': 165.0,
        'weight_kg': 62.5,
        'notification_prefs': {
          'triage_reminders': true,
          'medication_reminders': false,
          'appointment_reminders': true,
          'vitals_logging_reminders': true,
          'health_tips': false,
          'weekly_report': true,
        },
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-06-15T12:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-1');
      expect(profile.email, 'test@example.com');
      expect(profile.fullName, 'Test User');
      expect(profile.bloodType, 'O+');
      expect(profile.allergies, ['peanuts', 'shellfish']);
      expect(profile.emergencyContacts.length, 1);
      expect(profile.emergencyContacts.first.name, 'Jane');
      expect(profile.onboardingCompleted, isTrue);
      expect(profile.gender, 'Female');
      expect(profile.heightCm, 165.0);
      expect(profile.weightKg, 62.5);
      expect(profile.notificationPrefs, isNotNull);
      expect(profile.notificationPrefs!.medicationReminders, isFalse);
      expect(profile.notificationPrefs!.weeklyReport, isTrue);

      // Round-trip back to JSON. Should preserve the extension fields.
      final outJson = profile.toJson();
      expect(outJson['gender'], 'Female');
      expect(outJson['height_cm'], 165.0);
      expect(outJson['weight_kg'], 62.5);
      expect(outJson['notification_prefs'], isA<Map>());
      expect((outJson['notification_prefs'] as Map)['medication_reminders'], false);
    });

    test('tolerates missing extension fields (migration 003 not yet applied)', () {
      final json = {
        'id': 'user-2',
        'email': 'minimal@example.com',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        // gender, height_cm, weight_kg, notification_prefs omitted
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.gender, isNull);
      expect(profile.heightCm, isNull);
      expect(profile.weightKg, isNull);
      expect(profile.notificationPrefs, isNull);
      expect(profile.onboardingCompleted, isFalse); // defaults
      expect(profile.allergies, isEmpty);
    });

    test('NotificationPrefs defaults all to true', () {
      const prefs = NotificationPrefs();
      expect(prefs.triageReminders, isTrue);
      expect(prefs.medicationReminders, isTrue);
      expect(prefs.appointmentReminders, isTrue);
      expect(prefs.vitalsLoggingReminders, isTrue);
      expect(prefs.healthTips, isTrue);
      expect(prefs.weeklyReport, isTrue);
    });

    test('NotificationPrefs.copyWith updates only the toggled field', () {
      const prefs = NotificationPrefs();
      final updated = prefs.copyWith(weeklyReport: false);
      expect(updated.weeklyReport, isFalse);
      expect(updated.triageReminders, isTrue); // unchanged
      expect(updated.medicationReminders, isTrue); // unchanged
    });

    test('UserProfile.copyWith preserves id and createdAt', () {
      final original = UserProfile(
        id: 'user-3',
        email: 'test@example.com',
        createdAt: DateTime.utc(2024, 1, 1),
        updatedAt: DateTime.utc(2024, 1, 1),
      );
      final updated = original.copyWith(
        fullName: 'New Name',
        heightCm: 180.0,
        gender: 'Male',
      );
      expect(updated.id, original.id); // immutable
      expect(updated.email, original.email); // immutable
      expect(updated.createdAt, original.createdAt); // immutable
      expect(updated.fullName, 'New Name');
      expect(updated.heightCm, 180.0);
      expect(updated.gender, 'Male');
      // updatedAt is bumped by copyWith itself.
      expect(updated.updatedAt, isNot(original.updatedAt));
    });
  });
}
