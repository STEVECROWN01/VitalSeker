// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vital.dart';

// **************************************************************************
// JsonSerializable Generator
// **************************************************************************

Vital _$VitalFromJson(Map<String, dynamic> json) => Vital(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: $enumDecode(_$VitalTypeEnumMap, json['type']),
      value: (json['value'] as num).toDouble(),
      valueSecondary: (json['value_secondary'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      notes: json['notes'] as String?,
      source: json['source'] as String? ?? 'manual',
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$VitalToJson(Vital instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'type': _$VitalTypeEnumMap[instance.type],
      'value': instance.value,
      'value_secondary': instance.valueSecondary,
      'recorded_at': instance.recordedAt.toIso8601String(),
      'notes': instance.notes,
      'source': instance.source,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$VitalTypeEnumMap = {
  VitalType.heartRate: 'heart_rate',
  VitalType.bloodPressure: 'blood_pressure',
  VitalType.spO2: 'spo2',
  VitalType.temperature: 'temperature',
  VitalType.weight: 'weight',
  VitalType.bloodGlucose: 'blood_glucose',
  VitalType.respiratoryRate: 'respiratory_rate',
};

T $enumDecode<T>(Map<T, String> enumMap, String value) {
  return enumMap.entries.firstWhere((e) => e.value == value, orElse: () => enumMap.entries.first).key;
}
