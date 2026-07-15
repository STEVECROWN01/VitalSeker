import 'package:json_annotation/json_annotation.dart';
import 'user_profile.dart';

part 'family_profile.g.dart';

@JsonSerializable()
class FamilyProfile {
  final String id;
  @JsonKey(name: 'owner_id')
  final String ownerId;
  @JsonKey(name: 'full_name')
  final String fullName;
  final String relationship;
  @JsonKey(name: 'date_of_birth')
  final DateTime? dateOfBirth;
  @JsonKey(name: 'blood_type')
  final String? bloodType;
  final List<String> allergies;
  @JsonKey(name: 'chronic_conditions')
  final List<String> chronicConditions;
  final List<String> medications;
  @JsonKey(name: 'emergency_contacts')
  final List<EmergencyContact> emergencyContacts;
  final String? passportId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  FamilyProfile({
    required this.id,
    required this.ownerId,
    required this.fullName,
    required this.relationship,
    this.dateOfBirth,
    this.bloodType,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.medications = const [],
    this.emergencyContacts = const [],
    this.passportId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyProfile.fromJson(Map<String, dynamic> json) => _$FamilyProfileFromJson(json);
  Map<String, dynamic> toJson() => _$FamilyProfileToJson(this);

  FamilyProfile copyWith({
    String? fullName,
    String? relationship,
    DateTime? dateOfBirth,
    String? bloodType,
    List<String>? allergies,
    List<String>? chronicConditions,
    List<String>? medications,
    List<EmergencyContact>? emergencyContacts,
    String? passportId,
  }) {
    return FamilyProfile(
      id: id,
      ownerId: ownerId,
      fullName: fullName ?? this.fullName,
      relationship: relationship ?? this.relationship,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      medications: medications ?? this.medications,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      passportId: passportId ?? this.passportId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
