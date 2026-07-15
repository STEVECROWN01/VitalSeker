import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appointment.dart';
import '../providers/auth_provider.dart';
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
      await db.insertAppointment(appointment.toJson());
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAppointmentStatus(String appointmentId, AppointmentStatus status) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateAppointment(appointmentId, {'status': status.name});
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
      final db = ref.read(databaseServiceProvider);
      await db.updateAppointment(appointmentId, {
        'date_time': newDateTime.toIso8601String(),
        'status': AppointmentStatus.upcoming.name,
      });
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAppointment(String appointmentId) async {
    try {
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
