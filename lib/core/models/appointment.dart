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
  final String userId;
  final String doctorName;
  final String? specialty;
  final DateTime dateTime;
  final String? location;
  final String? notes;
  final bool reminderEnabled;
  final AppointmentStatus status;
  final DateTime createdAt;
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
}
