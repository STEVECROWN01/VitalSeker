// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication.dart';

Medication _$MedicationFromJson(Map<String, dynamic> json) => Medication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      unit: json['unit'] as String? ?? 'mg',
      frequency: _$enumDecodeMedicationFrequency(json['frequency']),
      times: (json['times'] as List<dynamic>).map((e) => e as String).toList(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      notes: json['notes'] as String?,
      remindersEnabled: json['reminders_enabled'] as bool? ?? true,
      status: _$enumDecodeMedicationStatus(json['status']),
      adherenceCount: json['adherence_count'] as int? ?? 0,
      totalDoses: json['total_doses'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$MedicationToJson(Medication instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'name': instance.name,
      'dosage': instance.dosage,
      'unit': instance.unit,
      'frequency': _$MedicationFrequencyEnumMap[instance.frequency],
      'times': instance.times,
      'start_date': instance.startDate.toIso8601String(),
      'end_date': instance.endDate?.toIso8601String(),
      'notes': instance.notes,
      'reminders_enabled': instance.remindersEnabled,
      'status': _$MedicationStatusEnumMap[instance.status],
      'adherence_count': instance.adherenceCount,
      'total_doses': instance.totalDoses,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

MedicationFrequency _$enumDecodeMedicationFrequency(String value) {
  switch (value) {
    case 'once_daily': return MedicationFrequency.onceDaily;
    case 'twice_daily': return MedicationFrequency.twiceDaily;
    case 'three_times_daily': return MedicationFrequency.threeTimesDaily;
    case 'four_times_daily': return MedicationFrequency.fourTimesDaily;
    case 'every_other_day': return MedicationFrequency.everyOtherDay;
    case 'weekly': return MedicationFrequency.weekly;
    case 'as_needed': return MedicationFrequency.asNeeded;
    default: return MedicationFrequency.custom;
  }
}

MedicationStatus _$enumDecodeMedicationStatus(String value) {
  switch (value) {
    case 'active': return MedicationStatus.active;
    case 'completed': return MedicationStatus.completed;
    default: return MedicationStatus.discontinued;
  }
}

const _$MedicationFrequencyEnumMap = {
  MedicationFrequency.onceDaily: 'once_daily',
  MedicationFrequency.twiceDaily: 'twice_daily',
  MedicationFrequency.threeTimesDaily: 'three_times_daily',
  MedicationFrequency.fourTimesDaily: 'four_times_daily',
  MedicationFrequency.everyOtherDay: 'every_other_day',
  MedicationFrequency.weekly: 'weekly',
  MedicationFrequency.asNeeded: 'as_needed',
  MedicationFrequency.custom: 'custom',
};

const _$MedicationStatusEnumMap = {
  MedicationStatus.active: 'active',
  MedicationStatus.completed: 'completed',
  MedicationStatus.discontinued: 'discontinued',
};
