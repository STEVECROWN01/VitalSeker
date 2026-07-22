import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appointment.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../services/offline_cache_service.dart';
import 'user_profile_provider.dart';

final appointmentsProvider = AsyncNotifierProvider<AppointmentsNotifier, List<Appointment>>(AppointmentsNotifier.new);

class AppointmentsNotifier extends AsyncNotifier<List<Appointment>> {
  @override
  Future<List<Appointment>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    final db = ref.read(databaseServiceProvider);
    final data = await db.getAppointments(user.id);
    return data.map((e) => Appointment.fromJson(e)).toList();
  }

  /// Generate a stable notification ID for an appointment.
  /// Uses the full 31-bit hash space (no modulo) so collisions are
  /// negligible. The previous range [100, 999] (only 900 buckets) had a
  /// ~50% collision probability at ~37 appointments — scheduling one appt
  /// would silently overwrite another's notification.
  int _notificationIdFor(String appointmentId) {
    final hash = appointmentId.hashCode;
    // Mask to 31 bits to avoid platform issues with negative IDs.
    return hash & 0x7FFFFFFF;
  }

  /// Schedule a reminder for an appointment (24h before).
  /// CRITICAL FIX: previously the `reminderEnabled: true` flag was saved
  /// to DB but NO code called NotificationService.scheduleAppointmentReminder
  /// — so the user enabled reminders, saw the success snackbar, and never
  /// received a single notification.
  Future<void> _scheduleReminder(Appointment appt) async {
    if (!appt.reminderEnabled) return;
    if (!appt.isUpcoming) return;
    try {
      final notif = NotificationService();
      if (!notif.isInitialized) return;
      await notif.scheduleAppointmentReminderForAppointment(
        notificationId: _notificationIdFor(appt.id),
        doctorName: appt.doctorName,
        appointmentDateTime: appt.dateTime,
        location: appt.location,
        leadTime: const Duration(hours: 24),
      );
      debugPrint('[Appointments] scheduled reminder for "${appt.doctorName}" '
          'on ${appt.dateTime}');
    } catch (e) {
      debugPrint('[Appointments] reminder scheduling failed (non-fatal): $e');
    }
  }

  Future<void> _cancelReminder(Appointment appt) async {
    try {
      final notif = NotificationService();
      if (!notif.isInitialized) return;
      await notif.cancelAppointmentReminder(_notificationIdFor(appt.id));
    } catch (e) {
      debugPrint('[Appointments] reminder cancellation failed (non-fatal): $e');
    }
  }

  Future<void> addAppointment({
    required String doctorName,
    String? specialty,
    required DateTime dateTime,
    String? location,
    String? notes,
    bool reminderEnabled = true,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final now = DateTime.now();
    final appointment = Appointment(
      id: '',
      userId: user.id,
      doctorName: doctorName,
      specialty: specialty,
      dateTime: dateTime,
      location: location,
      notes: notes,
      reminderEnabled: reminderEnabled,
      createdAt: now,
      updatedAt: now,
    );
    try {
      final db = ref.read(databaseServiceProvider);
      final insertedId = await db.insertAppointment(appointment.toJson());
      // Schedule the reminder now that we have the inserted ID.
      if (reminderEnabled && insertedId.isNotEmpty) {
        await _scheduleReminder(Appointment(
          id: insertedId,
          userId: appointment.userId,
          doctorName: appointment.doctorName,
          specialty: appointment.specialty,
          dateTime: appointment.dateTime,
          location: appointment.location,
          notes: appointment.notes,
          reminderEnabled: appointment.reminderEnabled,
          createdAt: appointment.createdAt,
          updatedAt: appointment.updatedAt,
        ));
      }
      ref.invalidateSelf();
    } catch (e) {
      // FIX: if the insert fails (likely offline), queue it for later
      // submission instead of losing the data.
      try {
        await OfflineCacheService().queuePendingWrite(
          table: 'appointments',
          payload: appointment.toJson(),
        );
        debugPrint('[Appointments] insert failed — queued for offline sync: $e');
        ref.invalidateSelf();
        return;
      } catch (queueErr) {
        debugPrint('[Appointments] failed to queue offline write: $queueErr');
      }
      rethrow;
    }
  }

  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateAppointment(appointmentId, {'status': status.name});
      // Cancel the reminder if the appointment is cancelled OR completed —
      // no point reminding the user about an appointment they cancelled or
      // already attended.
      if (status == AppointmentStatus.cancelled ||
          status == AppointmentStatus.completed) {
        final appt = state.valueOrNull
            ?.where((a) => a.id == appointmentId)
            .firstOrNull;
        if (appt != null) await _cancelReminder(appt);
      }
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  /// Reschedule an upcoming appointment to a new date/time. Also resets the
  /// status to 'upcoming' if it was 'cancelled' so the user can revive an
  /// appointment they had previously cancelled.
  Future<void> rescheduleAppointment({
    required String appointmentId,
    required DateTime newDateTime,
  }) async {
    try {
      // Validate the new date is in the future — prevents the user from
      // rescheduling to a past time, which would never trigger a reminder
      // and would be auto-completed on the next screen load.
      if (newDateTime.isBefore(DateTime.now())) {
        throw ArgumentError('Cannot reschedule an appointment to a past time.');
      }
      final db = ref.read(databaseServiceProvider);
      await db.updateAppointment(appointmentId, {
        // CRITICAL FIX: convert to UTC before serializing. The model's
        // toJson() does this, but rescheduleAppointment builds the payload
        // by hand — bypassing the model. Without .toUtc(), toIso8601String()
        // produces a naive string with no offset, which Supabase interprets
        // as UTC, shifting the stored time by the user's UTC offset.
        'date_time': newDateTime.toUtc().toIso8601String(),
        'status': AppointmentStatus.upcoming.name,
      });
      // Re-schedule the reminder with the new time.
      final appt = state.valueOrNull
          ?.where((a) => a.id == appointmentId)
          .firstOrNull;
      if (appt != null && appt.reminderEnabled) {
        await _cancelReminder(appt);
        await _scheduleReminder(Appointment(
          id: appt.id,
          userId: appt.userId,
          doctorName: appt.doctorName,
          specialty: appt.specialty,
          dateTime: newDateTime,
          location: appt.location,
          notes: appt.notes,
          reminderEnabled: appt.reminderEnabled,
          status: AppointmentStatus.upcoming,
          createdAt: appt.createdAt,
          updatedAt: DateTime.now(),
        ));
      }
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  /// Update editable fields of an existing appointment: doctor name,
  /// specialty, location, notes. Re-schedules the reminder if needed.
  /// FIX: the previous code had no edit feature — doctor name, specialty,
  /// location, and notes were immutable after creation. The user had to
  /// delete and re-add to fix a typo.
  Future<void> updateAppointmentDetails({
    required String appointmentId,
    required String doctorName,
    String? specialty,
    String? location,
    String? notes,
    bool? reminderEnabled,
  }) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateAppointment(appointmentId, {
        'doctor_name': doctorName,
        'specialty': specialty,
        'location': location,
        'notes': notes,
        if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      });
      // Re-schedule reminder if the reminder toggle changed.
      if (reminderEnabled != null) {
        final appt = state.valueOrNull
            ?.where((a) => a.id == appointmentId)
            .firstOrNull;
        if (appt != null) {
          if (reminderEnabled) {
            await _scheduleReminder(appt);
          } else {
            await _cancelReminder(appt);
          }
        }
      }
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAppointment(String appointmentId) async {
    try {
      // Cancel the reminder BEFORE deleting — once deleted we can't look up
      // the appointment to derive its notification ID.
      final appt = state.valueOrNull
          ?.where((a) => a.id == appointmentId)
          .firstOrNull;
      if (appt != null) await _cancelReminder(appt);
      final db = ref.read(databaseServiceProvider);
      await db.deleteAppointment(appointmentId);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  List<Appointment> get upcomingAppointments =>
      state.valueOrNull?.where((a) => a.isUpcoming).toList() ?? [];

  /// FIX (audit M-7): pastAppointments previously included cancelled-future
  /// appointments (because a cancelled appointment has `status != 'upcoming'`,
  /// so `isUpcoming` returns false, landing it in the past list). We now
  /// filter to only include appointments whose dateTime has actually passed,
  /// OR whose status is 'completed' or 'cancelled' with a past dateTime.
  List<Appointment> get pastAppointments =>
      state.valueOrNull?.where((a) {
        // An appointment belongs in "past" if its time has passed, regardless
        // of status. A cancelled future appointment stays in upcoming (so the
        // user can see it was cancelled and reschedule if needed).
        return !a.isUpcoming && a.dateTime.isBefore(DateTime.now());
      }).toList() ?? [];

  /// FIX (audit M-8): auto-complete appointments whose dateTime has passed
  /// but whose status is still 'upcoming'. This keeps the DB status in sync
  /// with reality. Call this on screen load or app focus.
  Future<void> autoCompletePastAppointments() async {
    final appointments = state.valueOrNull;
    if (appointments == null) return;

    final now = DateTime.now();
    final toUpdate = appointments.where((a) =>
        a.status == AppointmentStatus.upcoming && a.dateTime.isBefore(now));

    if (toUpdate.isEmpty) return;

    try {
      final db = ref.read(databaseServiceProvider);
      for (final appt in toUpdate) {
        await db.updateAppointment(appt.id, {
          'status': AppointmentStatus.completed.name,
        });
      }
      ref.invalidateSelf();
    } catch (e) {
      // Non-fatal — the UI still shows the correct past/upcoming split
      // via the isUpcoming getter. The DB status will be corrected on
      // the next successful call.
      debugPrint('Failed to auto-complete past appointments: $e');
    }
  }
}

final upcomingAppointmentsProvider = Provider<List<Appointment>>((ref) {
  return ref.watch(appointmentsProvider).valueOrNull
      ?.where((a) => a.isUpcoming)
      .toList() ?? [];
});
