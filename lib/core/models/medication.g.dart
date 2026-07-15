// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medication.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Medication _$MedicationFromJson(Map<String, dynamic> json) => Medication(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      unit: json['unit'] as String? ?? 'mg',
      frequency: $enumDecode(_$MedicationFrequencyEnumMap, json['frequency']),
      times:
          (json['times'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      notes: json['notes'] as String?,
      remindersEnabled: json['reminders_enabled'] as bool? ?? true,
      status: $enumDecodeNullable(_$MedicationStatusEnumMap, json['status']) ??
          MedicationStatus.active,
      adherenceCount: (json['adherence_count'] as num?)?.toInt() ?? 0,
      totalDoses: (json['total_doses'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$MedicationToJson(Medication instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'name': instance.name,
      'dosage': instance.dosage,
      'unit': instance.unit,
      'frequency': _$MedicationFrequencyEnumMap[instance.frequency]!,
      'times': instance.times,
      'start_date': instance.startDate.toIso8601String(),
      'end_date': instance.endDate?.toIso8601String(),
      'notes': instance.notes,
      'reminders_enabled': instance.remindersEnabled,
      'status': _$MedicationStatusEnumMap[instance.status]!,
      'adherence_count': instance.adherenceCount,
      'total_doses': instance.totalDoses,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

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
