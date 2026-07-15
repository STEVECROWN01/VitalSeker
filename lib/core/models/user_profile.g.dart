// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.parse(json['date_of_birth'] as String),
      bloodType: json['blood_type'] as String?,
      allergies: (json['allergies'] as List<dynamic>?)
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
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      themePreference: json['theme_preference'] as String? ?? 'system',
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      gender: json['gender'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      notificationPrefs: json['notification_prefs'] == null
          ? null
          : NotificationPrefs.fromJson(
              json['notification_prefs'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'full_name': instance.fullName,
      'phone': instance.phone,
      'avatar_url': instance.avatarUrl,
      'date_of_birth': instance.dateOfBirth?.toIso8601String(),
      'blood_type': instance.bloodType,
      'allergies': instance.allergies,
      'chronic_conditions': instance.chronicConditions,
      'emergency_contacts': instance.emergencyContacts,
      'preferred_language': instance.preferredLanguage,
      'theme_preference': instance.themePreference,
      'onboarding_completed': instance.onboardingCompleted,
      'gender': instance.gender,
      'height_cm': instance.heightCm,
      'weight_kg': instance.weightKg,
      'notification_prefs': instance.notificationPrefs,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

EmergencyContact _$EmergencyContactFromJson(Map<String, dynamic> json) =>
    EmergencyContact(
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String?,
    );

Map<String, dynamic> _$EmergencyContactToJson(EmergencyContact instance) =>
    <String, dynamic>{
      'name': instance.name,
      'phone': instance.phone,
      'relationship': instance.relationship,
    };

NotificationPrefs _$NotificationPrefsFromJson(Map<String, dynamic> json) =>
    NotificationPrefs(
      triageReminders: (json['triageReminders'] ?? json['triage_reminders']) as bool? ?? true,
      medicationReminders: (json['medicationReminders'] ?? json['medication_reminders']) as bool? ?? true,
      appointmentReminders: (json['appointmentReminders'] ?? json['appointment_reminders']) as bool? ?? true,
      vitalsLoggingReminders: (json['vitalsLoggingReminders'] ?? json['vitals_logging_reminders']) as bool? ?? true,
      healthTips: (json['healthTips'] ?? json['health_tips']) as bool? ?? true,
      weeklyReport: (json['weeklyReport'] ?? json['weekly_report']) as bool? ?? true,
    );

Map<String, dynamic> _$NotificationPrefsToJson(NotificationPrefs instance) =>
    <String, dynamic>{
      'triageReminders': instance.triageReminders,
      'medicationReminders': instance.medicationReminders,
      'appointmentReminders': instance.appointmentReminders,
      'vitalsLoggingReminders': instance.vitalsLoggingReminders,
      'healthTips': instance.healthTips,
      'weeklyReport': instance.weeklyReport,
    };
