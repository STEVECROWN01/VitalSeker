import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vitalseker/core/models/appointment.dart';
import 'package:vitalseker/core/models/medication.dart';
import 'package:vitalseker/core/models/vital.dart';
import 'package:vitalseker/core/providers/appointments_provider.dart';
import 'package:vitalseker/core/providers/auth_provider.dart';
import 'package:vitalseker/core/providers/medications_provider.dart';
import 'package:vitalseker/core/providers/vitals_provider.dart';
import 'package:vitalseker/core/services/database_service.dart';

/// Fake DatabaseService that records every call and returns canned data.
///
/// The real DatabaseService talks to Supabase; for unit tests we override
/// `databaseServiceProvider` with this fake so we can verify the notifiers
/// call the right methods with the right arguments, without needing a
/// network connection or a real Supabase project.
class FakeDatabaseService implements DatabaseService {
  /// All insert/update/delete calls recorded in order, as (method, args).
  final List<RecordedCall> calls = [];

  /// Canned data returned by the read methods.
  List<Map<String, dynamic>> medicationsJson = [];
  List<Map<String, dynamic>> vitalsJson = [];
  List<Map<String, dynamic>> appointmentsJson = [];

  @override
  Future<List<Map<String, dynamic>>> getMedications(String userId) async {
    calls.add(RecordedCall('getMedications', {'userId': userId}));
    return List<Map<String, dynamic>>.from(medicationsJson);
  }

  @override
  Future<void> insertMedication(Map<String, dynamic> data) async {
    calls.add(RecordedCall('insertMedication', {'data': data}));
  }

  @override
  Future<void> updateMedication(String medicationId, Map<String, dynamic> data) async {
    calls.add(RecordedCall('updateMedication', {'medicationId': medicationId, 'data': data}));
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    calls.add(RecordedCall('deleteMedication', {'medicationId': medicationId}));
  }

  @override
  Future<List<Map<String, dynamic>>> getVitals(String userId, {int limit = 100, int offset = 0}) async {
    calls.add(RecordedCall('getVitals', {'userId': userId, 'limit': limit, 'offset': offset}));
    return List<Map<String, dynamic>>.from(vitalsJson);
  }

  @override
  Future<void> insertVital(Map<String, dynamic> data) async {
    calls.add(RecordedCall('insertVital', {'data': data}));
  }

  @override
  Future<void> deleteVital(String vitalId) async {
    calls.add(RecordedCall('deleteVital', {'vitalId': vitalId}));
  }

  @override
  Future<List<Map<String, dynamic>>> getAppointments(String userId) async {
    calls.add(RecordedCall('getAppointments', {'userId': userId}));
    return List<Map<String, dynamic>>.from(appointmentsJson);
  }

  @override
  Future<void> insertAppointment(Map<String, dynamic> data) async {
    calls.add(RecordedCall('insertAppointment', {'data': data}));
  }

  @override
  Future<void> updateAppointment(String appointmentId, Map<String, dynamic> data) async {
    calls.add(RecordedCall('updateAppointment', {'appointmentId': appointmentId, 'data': data}));
  }

  @override
  Future<void> deleteAppointment(String appointmentId) async {
    calls.add(RecordedCall('deleteAppointment', {'appointmentId': appointmentId}));
  }

  // The remaining DatabaseService methods are unused by these tests. The
  // `implements DatabaseService` clause requires us to provide them, but
  // they can be no-ops. Using noSuchMethod lets us avoid stubbing ~30
  // methods we don't exercise.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordedCall {
  final String method;
  final Map<String, dynamic> args;
  RecordedCall(this.method, this.args);

  @override
  String toString() => 'RecordedCall($method, $args)';
}

/// Minimal fake User. Uses noSuchMethod so we don't have to enumerate every
/// field on the real Supabase User class (which varies across versions).
class FakeUser implements User {
  @override
  final String id;
  @override
  final String? email;
  FakeUser({this.id = 'user-1', this.email = 'test@example.com'});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FakeUser get fakeUser => FakeUser();

void main() {
  group('MedicationsNotifier', () {
    test('build() loads medications from DatabaseService', () async {
      final fake = FakeDatabaseService()
        ..medicationsJson = [
          {
            'id': 'med-1',
            'user_id': 'user-1',
            'name': 'Ibuprofen',
            'dosage': '200',
            'unit': 'mg',
            'frequency': 'onceDaily',
            'times': ['08:00'],
            'start_date': '2024-01-01',
            'end_date': null,
            'notes': null,
            'reminders_enabled': true,
            'status': 'active',
            'adherence_count': 5,
            'total_doses': 10,
            'created_at': '2024-01-01T00:00:00.000Z',
            'updated_at': '2024-01-01T00:00:00.000Z',
          },
        ];

      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      final medications = await container.read(medicationsProvider.future);
      expect(medications.length, 1);
      expect(medications.first.name, 'Ibuprofen');
      expect(medications.first.frequency, MedicationFrequency.onceDaily);
      expect(fake.calls.any((c) => c.method == 'getMedications'), isTrue);
    });

    test('addMedication() inserts via DB and invalidates the cache', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      // Initialize the notifier so build() runs.
      await container.read(medicationsProvider.future);

      await container.read(medicationsProvider.notifier).addMedication(
            name: 'Aspirin',
            dosage: '100',
            unit: 'mg',
            frequency: MedicationFrequency.onceDaily,
            times: ['08:00'],
            startDate: DateTime(2024, 1, 1),
            notes: 'Take with food',
            remindersEnabled: true,
          );

      // Verify the insert was called with the right payload.
      final insertCall = fake.calls.firstWhere((c) => c.method == 'insertMedication');
      final data = insertCall.args['data'] as Map<String, dynamic>;
      expect(data['name'], 'Aspirin');
      expect(data['dosage'], '100');
      expect(data['unit'], 'mg');
      expect(data['frequency'], 'onceDaily');
      expect(data['times'], ['08:00']);
      expect(data['reminders_enabled'], isTrue);
      expect(data['user_id'], fakeUser.id);

      // The notifier should have triggered a refetch (invalidation), so
      // getMedications should be called at least twice: once in build(),
      // once after the add.
      final getCalls = fake.calls.where((c) => c.method == 'getMedications').toList();
      expect(getCalls.length, greaterThanOrEqualTo(2));
    });

    test('updateMedicationStatus() updates via DB with the new status', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(medicationsProvider.future);

      await container.read(medicationsProvider.notifier).updateMedicationStatus(
            'med-1',
            MedicationStatus.completed,
          );

      final updateCall = fake.calls.firstWhere((c) => c.method == 'updateMedication');
      expect(updateCall.args['medicationId'], 'med-1');
      expect((updateCall.args['data'] as Map)['status'], 'completed');
    });

    test('deleteMedication() deletes via DB', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(medicationsProvider.future);

      await container.read(medicationsProvider.notifier).deleteMedication('med-1');

      final deleteCall = fake.calls.firstWhere((c) => c.method == 'deleteMedication');
      expect(deleteCall.args['medicationId'], 'med-1');
    });

    test('updateMedicationDetails() sends all editable fields', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(medicationsProvider.future);

      await container.read(medicationsProvider.notifier).updateMedicationDetails(
            medicationId: 'med-1',
            dosage: '400',
            unit: 'mg',
            frequency: MedicationFrequency.twiceDaily,
            times: ['08:00', '20:00'],
            endDate: DateTime(2024, 12, 31),
            notes: 'After meals',
            remindersEnabled: false,
          );

      final updateCall = fake.calls.firstWhere((c) => c.method == 'updateMedication');
      final data = updateCall.args['data'] as Map<String, dynamic>;
      expect(data['dosage'], '400');
      expect(data['unit'], 'mg');
      expect(data['frequency'], 'twiceDaily');
      expect(data['times'], ['08:00', '20:00']);
      expect(data['end_date'], '2024-12-31');
      expect(data['notes'], 'After meals');
      expect(data['reminders_enabled'], isFalse);
    });
  });

  group('VitalsNotifier', () {
    test('build() loads vitals from DatabaseService', () async {
      final fake = FakeDatabaseService()
        ..vitalsJson = [
          {
            'id': 'vital-1',
            'user_id': 'user-1',
            'type': 'heartRate',
            'value': 72.0,
            'value_secondary': null,
            'recorded_at': '2024-01-01T08:00:00.000Z',
            'notes': null,
            'source': 'manual',
            'created_at': '2024-01-01T08:00:00.000Z',
          },
        ];

      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      final vitals = await container.read(vitalsProvider.future);
      expect(vitals.length, 1);
      expect(vitals.first.type, VitalType.heartRate);
      expect(vitals.first.value, 72.0);
    });

    test('addVital() inserts via DB with the right type and value', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(vitalsProvider.future);

      await container.read(vitalsProvider.notifier).addVital(
            VitalType.bloodPressure,
            120,
            valueSecondary: 80,
            notes: 'Morning reading',
            recordedAt: DateTime(2024, 6, 15, 8, 0),
          );

      final insertCall = fake.calls.firstWhere((c) => c.method == 'insertVital');
      final data = insertCall.args['data'] as Map<String, dynamic>;
      expect(data['type'], 'bloodPressure');
      expect(data['value'], 120);
      expect(data['value_secondary'], 80);
      expect(data['user_id'], fakeUser.id);
    });

    test('deleteVital() deletes via DB', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(vitalsProvider.future);

      await container.read(vitalsProvider.notifier).deleteVital('vital-1');

      final deleteCall = fake.calls.firstWhere((c) => c.method == 'deleteVital');
      expect(deleteCall.args['vitalId'], 'vital-1');
    });
  });

  group('AppointmentsNotifier', () {
    test('build() loads appointments from DatabaseService', () async {
      final fake = FakeDatabaseService()
        ..appointmentsJson = [
          {
            'id': 'appt-1',
            'user_id': 'user-1',
            'doctor_name': 'Dr. Smith',
            'specialty': 'Cardiologist',
            'date_time': '2024-06-20T10:00:00.000Z',
            'location': 'Clinic A',
            'notes': null,
            'reminder_enabled': true,
            'status': 'upcoming',
            'created_at': '2024-06-01T00:00:00.000Z',
            'updated_at': '2024-06-01T00:00:00.000Z',
          },
        ];

      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      final appts = await container.read(appointmentsProvider.future);
      expect(appts.length, 1);
      expect(appts.first.doctorName, 'Dr. Smith');
      expect(appts.first.specialty, 'Cardiologist');
      expect(appts.first.status, AppointmentStatus.upcoming);
    });

    test('addAppointment() inserts via DB', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(appointmentsProvider.future);

      await container.read(appointmentsProvider.notifier).addAppointment(
            doctorName: 'Dr. House',
            specialty: 'Diagnostics',
            dateTime: DateTime(2024, 7, 1, 14, 30),
            location: 'Princeton-Plainsboro',
            notes: 'Bring MRI scans',
            reminderEnabled: true,
          );

      final insertCall = fake.calls.firstWhere((c) => c.method == 'insertAppointment');
      final data = insertCall.args['data'] as Map<String, dynamic>;
      expect(data['doctor_name'], 'Dr. House');
      expect(data['specialty'], 'Diagnostics');
      expect(data['location'], 'Princeton-Plainsboro');
      expect(data['reminder_enabled'], isTrue);
      expect(data['user_id'], fakeUser.id);
    });

    test('rescheduleAppointment() updates date_time and resets status to upcoming', () async {
      // This was the new method we added in the reschedule feature.
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(appointmentsProvider.future);

      final newDateTime = DateTime(2024, 8, 15, 9, 0);
      await container.read(appointmentsProvider.notifier).rescheduleAppointment(
            appointmentId: 'appt-1',
            newDateTime: newDateTime,
          );

      final updateCall = fake.calls.firstWhere((c) => c.method == 'updateAppointment');
      expect(updateCall.args['appointmentId'], 'appt-1');
      final data = updateCall.args['data'] as Map<String, dynamic>;
      expect(data['date_time'], newDateTime.toIso8601String());
      expect(data['status'], 'upcoming');
    });

    test('updateAppointmentStatus() updates status via DB', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(appointmentsProvider.future);

      await container.read(appointmentsProvider.notifier).updateAppointmentStatus(
            'appt-1',
            AppointmentStatus.cancelled,
          );

      final updateCall = fake.calls.firstWhere((c) => c.method == 'updateAppointment');
      expect((updateCall.args['data'] as Map)['status'], 'cancelled');
    });

    test('deleteAppointment() deletes via DB', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => fakeUser),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      await container.read(appointmentsProvider.future);

      await container.read(appointmentsProvider.notifier).deleteAppointment('appt-1');

      final deleteCall = fake.calls.firstWhere((c) => c.method == 'deleteAppointment');
      expect(deleteCall.args['appointmentId'], 'appt-1');
    });
  });

  group('notifiers with no signed-in user', () {
    test('MedicationsNotifier.build() returns empty list when user is null', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => null),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      final medications = await container.read(medicationsProvider.future);
      expect(medications, isEmpty);
      // getMedications should NOT have been called.
      expect(fake.calls.any((c) => c.method == 'getMedications'), isFalse);
    });

    test('VitalsNotifier.build() returns empty list when user is null', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => null),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      final vitals = await container.read(vitalsProvider.future);
      expect(vitals, isEmpty);
    });

    test('AppointmentsNotifier.build() returns empty list when user is null', () async {
      final fake = FakeDatabaseService();
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWith((ref) => null),
        databaseServiceProvider.overrideWithValue(fake),
      ]);
      addTearDown(container.dispose);

      final appts = await container.read(appointmentsProvider.future);
      expect(appts, isEmpty);
    });
  });
}
