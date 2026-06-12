// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment.dart';

Appointment _$AppointmentFromJson(Map<String, dynamic> json) => Appointment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      doctorName: json['doctor_name'] as String,
      specialty: json['specialty'] as String?,
      dateTime: DateTime.parse(json['date_time'] as String),
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      reminderEnabled: json['reminder_enabled'] as bool? ?? true,
      status: _$enumDecodeAppointmentStatus(json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$AppointmentToJson(Appointment instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'doctor_name': instance.doctorName,
      'specialty': instance.specialty,
      'date_time': instance.dateTime.toIso8601String(),
      'location': instance.location,
      'notes': instance.notes,
      'reminder_enabled': instance.reminderEnabled,
      'status': _$AppointmentStatusEnumMap[instance.status],
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

AppointmentStatus _$enumDecodeAppointmentStatus(String value) {
  switch (value) {
    case 'upcoming': return AppointmentStatus.upcoming;
    case 'completed': return AppointmentStatus.completed;
    case 'cancelled': return AppointmentStatus.cancelled;
    default: return AppointmentStatus.upcoming;
  }
}

const _$AppointmentStatusEnumMap = {
  AppointmentStatus.upcoming: 'upcoming',
  AppointmentStatus.completed: 'completed',
  AppointmentStatus.cancelled: 'cancelled',
};
