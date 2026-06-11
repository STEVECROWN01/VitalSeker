import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'vital.g.dart';

enum VitalType {
  heartRate,
  bloodPressure,
  spO2,
  temperature,
  weight,
  bloodGlucose,
  respiratoryRate,
}

extension VitalTypeX on VitalType {
  String get displayName {
    switch (this) {
      case VitalType.heartRate: return 'Heart Rate';
      case VitalType.bloodPressure: return 'Blood Pressure';
      case VitalType.spO2: return 'SpO2';
      case VitalType.temperature: return 'Temperature';
      case VitalType.weight: return 'Weight';
      case VitalType.bloodGlucose: return 'Blood Glucose';
      case VitalType.respiratoryRate: return 'Respiratory Rate';
    }
  }

  String get unit {
    switch (this) {
      case VitalType.heartRate: return 'bpm';
      case VitalType.bloodPressure: return 'mmHg';
      case VitalType.spO2: return '%';
      case VitalType.temperature: return '\u00B0C';
      case VitalType.weight: return 'kg';
      case VitalType.bloodGlucose: return 'mg/dL';
      case VitalType.respiratoryRate: return 'breaths/min';
    }
  }

  IconData get icon {
    switch (this) {
      case VitalType.heartRate: return Icons.favorite;
      case VitalType.bloodPressure: return Icons.bloodtype;
      case VitalType.spO2: return Icons.air;
      case VitalType.temperature: return Icons.thermostat;
      case VitalType.weight: return Icons.monitor_weight;
      case VitalType.bloodGlucose: return Icons.water_drop;
      case VitalType.respiratoryRate: return Icons.air;
    }
  }

  Color get color {
    switch (this) {
      case VitalType.heartRate: return const Color(0xFFE53935);
      case VitalType.bloodPressure: return const Color(0xFF6C63FF);
      case VitalType.spO2: return const Color(0xFF2196F3);
      case VitalType.temperature: return const Color(0xFFFF9800);
      case VitalType.weight: return const Color(0xFF4CAF50);
      case VitalType.bloodGlucose: return const Color(0xFF9C27B0);
      case VitalType.respiratoryRate: return const Color(0xFF00BCD4);
    }
  }
}

@JsonSerializable()
class Vital {
  final String id;
  final String userId;
  final VitalType type;
  final double value;
  final double? valueSecondary; // For BP diastolic
  final DateTime recordedAt;
  final String? notes;
  final String source; // 'manual', 'device', 'import'
  final DateTime createdAt;

  Vital({
    required this.id,
    required this.userId,
    required this.type,
    required this.value,
    this.valueSecondary,
    required this.recordedAt,
    this.notes,
    this.source = 'manual',
    required this.createdAt,
  });

  factory Vital.fromJson(Map<String, dynamic> json) => _$VitalFromJson(json);
  Map<String, dynamic> toJson() => _$VitalToJson(this);

  String get displayValue {
    if (type == VitalType.bloodPressure && valueSecondary != null) {
      return '${value.round()}/${valueSecondary!.round()}';
    }
    return '${value.toStringAsFixed(type == VitalType.temperature ? 1 : 0)}';
  }

  String get displayWithUnit => '$displayValue ${type.unit}';
}
