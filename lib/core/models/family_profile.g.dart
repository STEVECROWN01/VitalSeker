// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FamilyProfile _$FamilyProfileFromJson(Map<String, dynamic> json) =>
    FamilyProfile(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      fullName: json['full_name'] as String,
      relationship: json['relationship'] as String,
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.parse(json['date_of_birth'] as String),
      bloodType: json['blood_type'] as String?,
      allergies: (json['allergies'] as List<dynamic>?)?.cast<String>() ?? [],
      chronicConditions:
          (json['chronic_conditions'] as List<dynamic>?)?.cast<String>() ?? [],
      medications: (json['medications'] as List<dynamic>?)?.cast<String>() ?? [],
      emergencyContacts: (json['emergency_contacts'] as List<dynamic>?)
          ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      passportId: json['passport_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$FamilyProfileToJson(FamilyProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'owner_id': instance.ownerId,
      'full_name': instance.fullName,
      'relationship': instance.relationship,
      'date_of_birth': instance.dateOfBirth?.toIso8601String(),
      'blood_type': instance.bloodType,
      'allergies': instance.allergies,
      'chronic_conditions': instance.chronicConditions,
      'medications': instance.medications,
      'emergency_contacts': instance.emergencyContacts,
      'passport_id': instance.passportId,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
