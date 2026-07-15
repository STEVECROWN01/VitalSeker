// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_insight.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeeklyInsight _$WeeklyInsightFromJson(Map<String, dynamic> json) =>
    WeeklyInsight(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      weekStart: DateTime.parse(json['week_start'] as String),
      weekEnd: DateTime.parse(json['week_end'] as String),
      summary: json['summary'] as String,
      trendAnalysis:
          TrendAnalysis.fromJson(json['trend_analysis'] as Map<String, dynamic>),
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      vitalScoreChange: (json['vital_score_change'] as num?)?.toInt() ?? 0,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$WeeklyInsightToJson(WeeklyInsight instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'week_start': instance.weekStart.toIso8601String(),
      'week_end': instance.weekEnd.toIso8601String(),
      'summary': instance.summary,
      'trend_analysis': instance.trendAnalysis,
      'recommendations': instance.recommendations,
      'vital_score_change': instance.vitalScoreChange,
      'generated_at': instance.generatedAt.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

TrendAnalysis _$TrendAnalysisFromJson(Map<String, dynamic> json) =>
    TrendAnalysis(
      symptomFrequency: ((json['symptomFrequency'] ?? json['symptom_frequency']) as num).toInt(),
      avgSeverity: ((json['avgSeverity'] ?? json['avg_severity']) as num).toDouble(),
      direction: json['direction'] as String?,
      keyFindings: ((json['keyFindings'] ?? json['key_findings']) as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$TrendAnalysisToJson(TrendAnalysis instance) =>
    <String, dynamic>{
      'symptomFrequency': instance.symptomFrequency,
      'avgSeverity': instance.avgSeverity,
      'direction': instance.direction,
      'keyFindings': instance.keyFindings,
    };
