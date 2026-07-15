import 'package:json_annotation/json_annotation.dart';
import 'user_profile.dart';

part 'health_passport.g.dart';

@JsonSerializable()
class HealthPassport {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'qr_token')
  final String? qrToken;
  @JsonKey(name: 'vital_score')
  final int vitalScore;
  @JsonKey(name: 'last_assessment_date')
  final DateTime? lastAssessmentDate;
  @JsonKey(name: 'blood_type')
  final String? bloodType;
  final List<String> allergies;
  final List<String> medications;
  @JsonKey(name: 'chronic_conditions')
  final List<String> chronicConditions;
  @JsonKey(name: 'emergency_contacts')
  final List<EmergencyContact> emergencyContacts;
  @JsonKey(name: 'insurance_provider')
  final String? insuranceProvider;
  @JsonKey(name: 'insurance_policy_number')
  final String? insurancePolicyNumber;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  HealthPassport({
    required this.id,
    required this.userId,
    this.qrToken,
    this.vitalScore = 0,
    this.lastAssessmentDate,
    this.bloodType,
    this.allergies = const [],
    this.medications = const [],
    this.chronicConditions = const [],
    this.emergencyContacts = const [],
    this.insuranceProvider,
    this.insurancePolicyNumber,
    this.isActive = true,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HealthPassport.fromJson(Map<String, dynamic> json) => _$HealthPassportFromJson(json);
  Map<String, dynamic> toJson() => _$HealthPassportToJson(this);

  String get vitalScoreLabel {
    if (vitalScore >= 80) return 'Excellent';
    if (vitalScore >= 60) return 'Good';
    if (vitalScore >= 40) return 'Fair';
    if (vitalScore >= 20) return 'Poor';
    return 'Critical';
  }

  String get vitalScoreEmoji {
    if (vitalScore >= 80) return '💚';
    if (vitalScore >= 60) return '💛';
    if (vitalScore >= 40) return '🧡';
    if (vitalScore >= 20) return '❤️';
    return '💔';
  }

  /// FIX (audit M-16): add copyWith for immutable updates.
  HealthPassport copyWith({
    String? id,
    String? userId,
    String? qrToken,
    int? vitalScore,
    DateTime? lastAssessmentDate,
    String? bloodType,
    List<String>? allergies,
    List<String>? medications,
    List<String>? chronicConditions,
    List<EmergencyContact>? emergencyContacts,
    String? insuranceProvider,
    String? insurancePolicyNumber,
    bool? isActive,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthPassport(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      qrToken: qrToken ?? this.qrToken,
      vitalScore: vitalScore ?? this.vitalScore,
      lastAssessmentDate: lastAssessmentDate ?? this.lastAssessmentDate,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      medications: medications ?? this.medications,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      insuranceProvider: insuranceProvider ?? this.insuranceProvider,
      insurancePolicyNumber: insurancePolicyNumber ?? this.insurancePolicyNumber,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
