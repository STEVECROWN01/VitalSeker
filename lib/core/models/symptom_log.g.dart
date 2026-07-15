// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'symptom_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SymptomLog _$SymptomLogFromJson(Map<String, dynamic> json) => SymptomLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      symptoms:
          (json['symptoms'] as List<dynamic>).map((e) => e as String).toList(),
      severity: (json['severity'] as num).toInt(),
      duration: json['duration'] as String?,
      bodyRegions: (json['body_regions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      triageResult: json['triage_result'] == null
          ? null
          : TriageResult.fromJson(json['triage_result'] as Map<String, dynamic>),
      aiRecommendation: json['ai_recommendation'] as String?,
      notes: json['notes'] as String?,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SymptomLogToJson(SymptomLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'symptoms': instance.symptoms,
      'severity': instance.severity,
      'duration': instance.duration,
      'body_regions': instance.bodyRegions,
      'triage_result': instance.triageResult,
      'ai_recommendation': instance.aiRecommendation,
      'notes': instance.notes,
      'logged_at': instance.loggedAt.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

TriageResult _$TriageResultFromJson(Map<String, dynamic> json) => TriageResult(
      urgencyLevel: (json['urgencyLevel'] ?? json['urgency_level']) as String,
      urgencyScore: ((json['urgencyScore'] ?? json['urgency_score']) as num).toInt(),
      possibleConditions: ((json['possibleConditions'] ?? json['possible_conditions']) as List<dynamic>?)
              ?.map(
                  (e) => PossibleCondition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      redFlags: ((json['redFlags'] ?? json['red_flags']) as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      seekCare: (json['seekCare'] ?? json['seek_care']) as String,
      followUpQuestions: ((json['followUpQuestions'] ?? json['follow_up_questions']) as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      disclaimer: json['disclaimer'] as String,
    );

Map<String, dynamic> _$TriageResultToJson(TriageResult instance) =>
    <String, dynamic>{
      'urgencyLevel': instance.urgencyLevel,
      'urgencyScore': instance.urgencyScore,
      'possibleConditions': instance.possibleConditions,
      'recommendations': instance.recommendations,
      'redFlags': instance.redFlags,
      'seekCare': instance.seekCare,
      'followUpQuestions': instance.followUpQuestions,
      'disclaimer': instance.disclaimer,
    };

PossibleCondition _$PossibleConditionFromJson(Map<String, dynamic> json) =>
    PossibleCondition(
      name: json['name'] as String,
      probability: json['probability'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$PossibleConditionToJson(PossibleCondition instance) =>
    <String, dynamic>{
      'name': instance.name,
      'probability': instance.probability,
      'description': instance.description,
    };
