import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medication.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import 'user_profile_provider.dart';

final medicationsProvider = AsyncNotifierProvider<MedicationsNotifier, List<Medication>>(MedicationsNotifier.new);

class MedicationsNotifier extends AsyncNotifier<List<Medication>> {
  @override
  Future<List<Medication>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    final db = ref.read(databaseServiceProvider);
    final data = await db.getMedications(user.id);
    return data.map((e) => Medication.fromJson(e)).toList();
  }

  Future<void> addMedication({
    required String name,
    required String dosage,
    String unit = 'mg',
    required MedicationFrequency frequency,
    List<String> times = const [],
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    bool remindersEnabled = true,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final now = DateTime.now();
    final medication = Medication(
      id: '',
      userId: user.id,
      name: name,
      dosage: dosage,
      unit: unit,
      frequency: frequency,
      times: times,
      startDate: startDate ?? now,
      endDate: endDate,
      notes: notes,
      remindersEnabled: remindersEnabled,
      createdAt: now,
      updatedAt: now,
    );
    try {
      final db = ref.read(databaseServiceProvider);
      await db.insertMedication(medication.toJson());
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMedicationStatus(String medicationId, MedicationStatus status) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateMedication(medicationId, {'status': status.name});
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  /// Update editable fields of an existing medication: dosage, unit, frequency,
  /// dose times, notes, end date, and reminders toggle. Name and start date
  /// are not editable post-create (changing them is conceptually a new med).
  Future<void> updateMedicationDetails({
    required String medicationId,
    required String dosage,
    required String unit,
    required MedicationFrequency frequency,
    required List<String> times,
    DateTime? endDate,
    String? notes,
    required bool remindersEnabled,
  }) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateMedication(medicationId, {
        'dosage': dosage,
        'unit': unit,
        // Use jsonValue (snake_case) instead of .name (camelCase) so the DB
        // value matches what Medication.fromJson expects.
        'frequency': frequency.jsonValue,
        'times': times,
        'end_date': endDate?.toIso8601String().split('T')[0],
        'notes': notes,
        'reminders_enabled': remindersEnabled,
      });
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMedication(String medicationId) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteMedication(medicationId);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  List<Medication> get activeMedications =>
      state.valueOrNull?.where((m) => m.status == MedicationStatus.active).toList() ?? [];

  List<Medication> get completedMedications =>
      state.valueOrNull?.where((m) => m.status == MedicationStatus.completed).toList() ?? [];
}

final activeMedicationsProvider = Provider<List<Medication>>((ref) {
  return ref.watch(medicationsProvider).valueOrNull
      ?.where((m) => m.status == MedicationStatus.active)
      .toList() ?? [];
});
