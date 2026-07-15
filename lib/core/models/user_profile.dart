import 'package:json_annotation/json_annotation.dart';

part 'user_profile.g.dart';

@JsonSerializable()
class UserProfile {
  final String id;
  final String email;
  @JsonKey(name: 'full_name')
  final String? fullName;
  final String? phone;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'date_of_birth')
  final DateTime? dateOfBirth;
  @JsonKey(name: 'blood_type')
  final String? bloodType;
  final List<String> allergies;
  @JsonKey(name: 'chronic_conditions')
  final List<String> chronicConditions;
  @JsonKey(name: 'emergency_contacts')
  final List<EmergencyContact> emergencyContacts;
  @JsonKey(name: 'preferred_language')
  final String preferredLanguage;
  @JsonKey(name: 'theme_preference')
  final String themePreference;
  @JsonKey(name: 'onboarding_completed')
  final bool onboardingCompleted;
  final String? gender;
  @JsonKey(name: 'height_cm')
  final double? heightCm;
  @JsonKey(name: 'weight_kg')
  final double? weightKg;
  @JsonKey(name: 'notification_prefs')
  final NotificationPrefs? notificationPrefs;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.dateOfBirth,
    this.bloodType,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.emergencyContacts = const [],
    this.preferredLanguage = 'en',
    this.themePreference = 'system',
    this.onboardingCompleted = false,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.notificationPrefs,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    DateTime? dateOfBirth,
    String? bloodType,
    List<String>? allergies,
    List<String>? chronicConditions,
    List<EmergencyContact>? emergencyContacts,
    String? preferredLanguage,
    String? themePreference,
    bool? onboardingCompleted,
    String? gender,
    double? heightCm,
    double? weightKg,
    NotificationPrefs? notificationPrefs,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      themePreference: themePreference ?? this.themePreference,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

@JsonSerializable()
class EmergencyContact {
  final String name;
  final String phone;
  final String? relationship;

  EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => _$EmergencyContactFromJson(json);
  Map<String, dynamic> toJson() => _$EmergencyContactToJson(this);
}

@JsonSerializable()
class NotificationPrefs {
  final bool triageReminders;
  final bool medicationReminders;
  final bool appointmentReminders;
  final bool vitalsLoggingReminders;
  final bool healthTips;
  final bool weeklyReport;

  const NotificationPrefs({
    this.triageReminders = true,
    this.medicationReminders = true,
    this.appointmentReminders = true,
    this.vitalsLoggingReminders = true,
    this.healthTips = true,
    this.weeklyReport = true,
  });

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      _$NotificationPrefsFromJson(json);
  Map<String, dynamic> toJson() => _$NotificationPrefsToJson(this);

  NotificationPrefs copyWith({
    bool? triageReminders,
    bool? medicationReminders,
    bool? appointmentReminders,
    bool? vitalsLoggingReminders,
    bool? healthTips,
    bool? weeklyReport,
  }) {
    return NotificationPrefs(
      triageReminders: triageReminders ?? this.triageReminders,
      medicationReminders: medicationReminders ?? this.medicationReminders,
      appointmentReminders: appointmentReminders ?? this.appointmentReminders,
      vitalsLoggingReminders: vitalsLoggingReminders ?? this.vitalsLoggingReminders,
      healthTips: healthTips ?? this.healthTips,
      weeklyReport: weeklyReport ?? this.weeklyReport,
    );
  }
}
