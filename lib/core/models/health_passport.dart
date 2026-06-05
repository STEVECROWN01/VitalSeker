import 'package:json_annotation/json_annotation.dart';
import 'user_profile.dart';

part 'health_passport.g.dart';

@JsonSerializable()
class HealthPassport {
  final String id;
  final String userId;
  final String? qrToken;
  final int vitalScore;
  final DateTime? lastAssessmentDate;
  final String? bloodType;
  final List<String> allergies;
  final List<String> medications;
  final List<String> chronicConditions;
  final List<EmergencyContact> emergencyContacts;
  final String? insuranceProvider;
  final String? insurancePolicyNumber;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime createdAt;
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
}
