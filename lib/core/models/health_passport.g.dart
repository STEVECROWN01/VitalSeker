// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_passport.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthPassport _$HealthPassportFromJson(Map<String, dynamic> json) =>
    HealthPassport(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      qrToken: json['qr_token'] as String?,
      vitalScore: (json['vital_score'] as num?)?.toInt() ?? 0,
      lastAssessmentDate: json['last_assessment_date'] == null
          ? null
          : DateTime.parse(json['last_assessment_date'] as String),
      bloodType: json['blood_type'] as String?,
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      medications: (json['medications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      chronicConditions: (json['chronic_conditions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      emergencyContacts: (json['emergency_contacts'] as List<dynamic>?)
              ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      insuranceProvider: json['insurance_provider'] as String?,
      insurancePolicyNumber: json['insurance_policy_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$HealthPassportToJson(HealthPassport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'qr_token': instance.qrToken,
      'vital_score': instance.vitalScore,
      'last_assessment_date': instance.lastAssessmentDate?.toIso8601String(),
      'blood_type': instance.bloodType,
      'allergies': instance.allergies,
      'medications': instance.medications,
      'chronic_conditions': instance.chronicConditions,
      'emergency_contacts': instance.emergencyContacts,
      'insurance_provider': instance.insuranceProvider,
      'insurance_policy_number': instance.insurancePolicyNumber,
      'is_active': instance.isActive,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
