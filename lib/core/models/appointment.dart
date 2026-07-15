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

  factory Appointment.fromJson(Map<String, dynamic> json) => _$AppointmentFromJson(json);
  Map<String, dynamic> toJson() => _$AppointmentToJson(this);

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
