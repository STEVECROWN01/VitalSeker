import 'package:json_annotation/json_annotation.dart';

part 'appointment.g.dart';

enum AppointmentStatus {
  upcoming,
  completed,
  cancelled,
}

extension AppointmentStatusX on AppointmentStatus {
  String get displayName {
    switch (this) {
      case AppointmentStatus.upcoming: return 'Upcoming';
      case AppointmentStatus.completed: return 'Completed';
      case AppointmentStatus.cancelled: return 'Cancelled';
    }
  }
}

@JsonSerializable()
class Appointment {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'doctor_name')
  final String doctorName;
  final String? specialty;
  @JsonKey(name: 'date_time')
  final DateTime dateTime;
  final String? location;
  final String? notes;
  @JsonKey(name: 'reminder_enabled')
  final bool reminderEnabled;
  final AppointmentStatus status;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Appointment({
    required this.id,
    required this.userId,
    required this.doctorName,
    this.specialty,
    required this.dateTime,
    this.location,
    this.notes,
    this.reminderEnabled = true,
    this.status = AppointmentStatus.upcoming,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    // FIX (timezone bug): Supabase `timestamptz` stores values in UTC. The
    // auto-generated fromJson calls `DateTime.parse(json['date_time'])` —
    // if the server returns "...Z" (UTC), DateTime.parse correctly marks
    // the result as UTC (isUtc=true). But the display getters below
    // (displayTime, displayDate) call `.hour`/`.day`/`.month` which return
    // UTC values, not local — so a 10:00 UTC appointment displays as "10:00"
    // even if the user is in UTC+1 and picked 11:00 local.
    //
    // We delegate to the generated _$AppointmentFromJson and then convert
    // all DateTime fields to local time so the display getters work
    // correctly.
    final appt = _$AppointmentFromJson(json);
    return Appointment(
      id: appt.id,
      userId: appt.userId,
      doctorName: appt.doctorName,
      specialty: appt.specialty,
      dateTime: appt.dateTime.toLocal(),
      location: appt.location,
      notes: appt.notes,
      reminderEnabled: appt.reminderEnabled,
      status: appt.status,
      createdAt: appt.createdAt.toLocal(),
      updatedAt: appt.updatedAt.toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    // FIX (timezone bug): convert local DateTime to UTC before serializing
    // so the server stores the correct absolute moment. The auto-generated
    // _$AppointmentToJson calls `toIso8601String()` on the local DateTime,
    // which produces "...HH:mm:ss.SSS" with NO offset — Supabase interprets
    // offset-less strings as UTC, so a 10:00 local appointment gets stored
    // as 10:00 UTC (wrong by the user's UTC offset).
    //
    // By calling `.toUtc().toIso8601String()` we produce "...HH:mm:ss.SSSZ"
    // which the server correctly interprets as the absolute moment.
    return {
      'id': id,
      'user_id': userId,
      'doctor_name': doctorName,
      'specialty': specialty,
      'date_time': dateTime.toUtc().toIso8601String(),
      'location': location,
      'notes': notes,
      'reminder_enabled': reminderEnabled,
      'status': status.name,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  String get displayDate {
    final now = DateTime.now();
    final diff = dateTime.difference(now);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Tomorrow';
    if (diff.inDays > 0 && diff.inDays < 7) return 'In ${diff.inDays} days';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String get displayTime {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool get isUpcoming => status == AppointmentStatus.upcoming && dateTime.isAfter(DateTime.now());

  /// FIX (audit M-16): add copyWith for immutable updates.
  Appointment copyWith({
    String? id,
    String? userId,
    String? doctorName,
    String? specialty,
    DateTime? dateTime,
    String? location,
    String? notes,
    bool? reminderEnabled,
    AppointmentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
