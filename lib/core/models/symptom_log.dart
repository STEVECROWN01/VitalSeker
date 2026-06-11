import 'package:json_annotation/json_annotation.dart';

part 'symptom_log.g.dart';

@JsonSerializable()
class SymptomLog {
  final String id;
  final String userId;
  final List<String> symptoms;
  final int severity;
  final String? duration;
  final List<String> bodyRegions;
  final TriageResult? triageResult;
  final String? aiRecommendation;
  final String? notes;
  final DateTime loggedAt;
  final DateTime createdAt;

  SymptomLog({
    required this.id,
    required this.userId,
    required this.symptoms,
    required this.severity,
    this.duration,
    this.bodyRegions = const [],
    this.triageResult,
    this.aiRecommendation,
    this.notes,
    required this.loggedAt,
    required this.createdAt,
  });

  factory SymptomLog.fromJson(Map<String, dynamic> json) => _$SymptomLogFromJson(json);
  Map<String, dynamic> toJson() => _$SymptomLogToJson(this);
}

@JsonSerializable()
class TriageResult {
  final String urgencyLevel;
  final int urgencyScore;
  final List<PossibleCondition> possibleConditions;
  final List<String> recommendations;
  final List<String> redFlags;
  final String seekCare;
  final List<String> followUpQuestions;
  final String disclaimer;

  TriageResult({
    required this.urgencyLevel,
    required this.urgencyScore,
    this.possibleConditions = const [],
    this.recommendations = const [],
    this.redFlags = const [],
    required this.seekCare,
    this.followUpQuestions = const [],
    required this.disclaimer,
  });

  factory TriageResult.fromJson(Map<String, dynamic> json) => _$TriageResultFromJson(json);
  Map<String, dynamic> toJson() => _$TriageResultToJson(this);
}

@JsonSerializable()
class PossibleCondition {
  final String name;
  final String probability;
  final String description;

  PossibleCondition({
    required this.name,
    required this.probability,
    required this.description,
  });

  factory PossibleCondition.fromJson(Map<String, dynamic> json) => _$PossibleConditionFromJson(json);
  Map<String, dynamic> toJson() => _$PossibleConditionToJson(this);
}
