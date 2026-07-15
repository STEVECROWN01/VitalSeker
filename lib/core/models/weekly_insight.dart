import 'package:json_annotation/json_annotation.dart';

part 'weekly_insight.g.dart';

@JsonSerializable()
class WeeklyInsight {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'week_start')
  final DateTime weekStart;
  @JsonKey(name: 'week_end')
  final DateTime weekEnd;
  final String summary;
  @JsonKey(name: 'trend_analysis')
  final TrendAnalysis trendAnalysis;
  final List<String> recommendations;
  final int vitalScoreChange;
  final DateTime generatedAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  WeeklyInsight({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    required this.summary,
    required this.trendAnalysis,
    this.recommendations = const [],
    this.vitalScoreChange = 0,
    required this.generatedAt,
    required this.createdAt,
  });

  factory WeeklyInsight.fromJson(Map<String, dynamic> json) => _$WeeklyInsightFromJson(json);
  Map<String, dynamic> toJson() => _$WeeklyInsightToJson(this);
}

@JsonSerializable()
class TrendAnalysis {
  final int symptomFrequency;
  final double avgSeverity;
  final String? direction;
  final List<String>? keyFindings;

  TrendAnalysis({
    required this.symptomFrequency,
    required this.avgSeverity,
    this.direction,
    this.keyFindings,
  });

  factory TrendAnalysis.fromJson(Map<String, dynamic> json) => _$TrendAnalysisFromJson(json);
  Map<String, dynamic> toJson() => _$TrendAnalysisToJson(this);
}
