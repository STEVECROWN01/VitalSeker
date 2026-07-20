import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medication.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../services/offline_cache_service.dart';
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

  /// Generate a stable notification ID for a medication + dose index.
  /// Uses the full 31-bit hash space (no modulo) so collisions are
  /// negligible. The previous range [1000, 9999] (only 9000 buckets) had a
  /// ~50% collision probability at ~28 medications × 4 dose times —
  /// scheduling one med would silently overwrite another's notification,
  /// and cancelling one would cancel the other's.
  int _notificationIdFor(String medicationId, int doseIndex) {
    final hash = '$medicationId:$doseIndex'.hashCode;
    // Mask to 31 bits to avoid platform issues with negative IDs.
    return hash & 0x7FFFFFFF;
  }

  /// Schedule per-dose reminders for a medication.
  /// Iterates `medication.times` and calls
  /// [NotificationService.scheduleMedicationReminderForMedication] for each,
  /// using a stable notification ID derived from the medication ID + dose
  /// index. Safe to call multiple times — the same notification ID gets
  /// overwritten by the new schedule.
  Future<void> _scheduleReminders(Medication medication) async {
    if (!medication.remindersEnabled) return;
    if (medication.status != MedicationStatus.active) return;
    if (medication.times.isEmpty) return;
    // FIX: don't schedule reminders if the medication's start date is
    // in the future. The previous code scheduled daily reminders
    // immediately even for future-dated prescriptions — the user would
    // get reminders weeks before they're supposed to start taking the med.
    final now = DateTime.now();
    if (medication.startDate.isAfter(now)) {
      debugPrint('[Medications] skipping reminders for "${medication.name}" — '
          'start date ${medication.startDate} is in the future');
      return;
    }
    // FIX: deduplicate dose times so the user doesn't get multiple
    // notifications at the same time (e.g. times: [08:00, 08:00, 20:00]
    // would schedule two 8am notifications). We track seen times and
    // skip duplicates.
    final seenTimes = <String>{};
    try {
      final notif = NotificationService();
      if (!notif.isInitialized) return;
      for (var i = 0; i < medication.times.length; i++) {
        final time = medication.times[i];
        if (seenTimes.contains(time)) {
          debugPrint('[Medications] skipping duplicate dose time $time for "${medication.name}"');
          continue;
        }
        seenTimes.add(time);
        final parts = time.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;
        await notif.scheduleMedicationReminderForMedication(
          notificationId: _notificationIdFor(medication.id, i),
          medicationName: medication.name,
          dosage: '${medication.dosage} ${medication.unit}',
          hour: hour,
          minute: minute,
        );
      }
      debugPrint('[Medications] scheduled ${medication.times.length} reminders '
          'for "${medication.name}"');
    } catch (e) {
      debugPrint('[Medications] reminder scheduling failed (non-fatal): $e');
    }
  }

  /// Cancel all per-dose reminders for a medication.
  Future<void> _cancelReminders(Medication medication) async {
    try {
      final notif = NotificationService();
      if (!notif.isInitialized) return;
      for (var i = 0; i < medication.times.length; i++) {
        await notif.cancelMedicationReminder(
          _notificationIdFor(medication.id, i),
        );
      }
    } catch (e) {
      debugPrint('[Medications] reminder cancellation failed (non-fatal): $e');
    }
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
      final insertedId = await db.insertMedication(medication.toJson());
      // Schedule reminders for the newly-created medication. CRITICAL FIX:
      // previously the `remindersEnabled: true` flag was saved to DB but
      // NO code called NotificationService.scheduleMedicationReminder — so
      // the user enabled reminders, saw the success snackbar, and never
      // received a single notification.
      if (remindersEnabled && insertedId != null && insertedId.isNotEmpty) {
        await _scheduleReminders(Medication(
          id: insertedId,
          userId: medication.userId,
          name: medication.name,
          dosage: medication.dosage,
          unit: medication.unit,
          frequency: medication.frequency,
          times: medication.times,
          startDate: medication.startDate,
          endDate: medication.endDate,
          notes: medication.notes,
          remindersEnabled: medication.remindersEnabled,
          createdAt: medication.createdAt,
          updatedAt: medication.updatedAt,
        ));
      }
      ref.invalidateSelf();
    } catch (e) {
      // FIX: if the insert fails (likely offline), queue it for later
      // submission instead of losing the data.
      try {
        await OfflineCacheService().queuePendingWrite(
          table: 'medications',
          payload: medication.toJson(),
        );
        debugPrint('[Medications] insert failed — queued for offline sync: $e');
        ref.invalidateSelf();
        return;
      } catch (queueErr) {
        debugPrint('[Medications] failed to queue offline write: $queueErr');
      }
      rethrow;
    }
  }

  Future<void> updateMedicationStatus(String medicationId, MedicationStatus status) async {
    try {
      final db = ref.read(databaseServiceProvider);
      // FIX (audit M-9): when transitioning to 'completed' or 'discontinued',
      // also set end_date to today so the medication history shows when the
      // user stopped taking it. Previously, end_date stayed null, making it
      // ambiguous whether the user stopped last week or last year.
      final payload = <String, dynamic>{'status': status.name};
      if (status == MedicationStatus.completed ||
          status == MedicationStatus.discontinued) {
        payload['end_date'] = DateTime.now().toIso8601String().split('T')[0];
      }
      await db.updateMedication(medicationId, payload);
      // FIX: cancel scheduled reminders when the medication is completed or
      // discontinued — otherwise the user keeps getting reminded to take a
      // med they're no longer taking.
      if (status == MedicationStatus.completed ||
          status == MedicationStatus.discontinued) {
        final med = state.valueOrNull
            ?.where((m) => m.id == medicationId)
            .firstOrNull;
        if (med != null) {
          await _cancelReminders(med);
        }
      }
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
      // Re-schedule reminders with the updated times/toggle.
      final med = state.valueOrNull
          ?.where((m) => m.id == medicationId)
          .firstOrNull;
      if (med != null) {
        await _cancelReminders(med);
        final updatedMed = Medication(
          id: med.id,
          userId: med.userId,
          name: med.name,
          dosage: dosage,
          unit: unit,
          frequency: frequency,
          times: times,
          startDate: med.startDate,
          endDate: endDate,
          notes: notes,
          remindersEnabled: remindersEnabled,
          status: med.status,
          createdAt: med.createdAt,
          updatedAt: DateTime.now(),
        );
        await _scheduleReminders(updatedMed);
      }
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMedication(String medicationId) async {
    try {
      // Cancel reminders BEFORE deleting — once deleted we can't look up
      // the medication's times to derive notification IDs.
      final med = state.valueOrNull
          ?.where((m) => m.id == medicationId)
          .firstOrNull;
      if (med != null) {
        await _cancelReminders(med);
      }
      final db = ref.read(databaseServiceProvider);
      await db.deleteMedication(medicationId);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  /// Mark a dose as taken — increments adherence_count and total_doses.
  ///
  /// FIX: the adherence progress bar on the medications screen always
  /// showed 0% because nothing ever incremented these counters. Now the
  /// card's "Mark as taken" button calls this method.
  Future<void> markDoseTaken(Medication medication) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateMedication(medication.id, {
        'adherence_count': medication.adherenceCount + 1,
        'total_doses': medication.totalDoses + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      ref.invalidateSelf();
    } catch (e) {
      // If offline, we don't queue this (it's not a simple insert — it's
      // an increment). Just rethrow so the UI can show an error.
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
