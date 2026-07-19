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
      case VitalType.bloodPressure: return const Color(0xFF0B7A5B);
      case VitalType.spO2: return const Color(0xFF2196F3);
      case VitalType.temperature: return const Color(0xFFFF9800);
      case VitalType.weight: return const Color(0xFF4CAF50);
      case VitalType.bloodGlucose: return const Color(0xFF9C27B0);
      case VitalType.respiratoryRate: return const Color(0xFF00BCD4);
    }
  }

  /// Physiologically plausible range for the primary value of this vital
  /// type. Values outside this range are rejected by [Vital.validate].
  ///
  /// FIX (audit H-45): the Vital model previously accepted any double
  /// value with no bounds checking. A user (or buggy device import) could
  /// log heartRate = 999, temperature = 500, spO2 = 150% — these bogus
  /// values would flow into trend analysis, vital-score computation, and
  /// dashboard charts, potentially suppressing real alerts.
  (double, double) get validRange {
    switch (this) {
      case VitalType.heartRate:         return (20, 250);    // bpm
      case VitalType.bloodPressure:     return (50, 300);    // systolic mmHg
      case VitalType.spO2:              return (50, 100);    // %
      case VitalType.temperature:       return (30, 45);     // °C
      case VitalType.weight:            return (2, 500);     // kg
      case VitalType.bloodGlucose:      return (20, 1000);   // mg/dL
      case VitalType.respiratoryRate:   return (5, 60);      // breaths/min
    }
  }

  /// Physiologically plausible range for the secondary value (diastolic BP).
  /// Only meaningful for [VitalType.bloodPressure].
  (double, double)? get validRangeSecondary {
    switch (this) {
      case VitalType.bloodPressure:     return (30, 200);    // diastolic mmHg
      default:                          return null;
    }
  }

  /// Whether this vital type requires a secondary value (e.g. blood
  /// pressure requires both systolic and diastolic).
  bool get requiresSecondary => this == VitalType.bloodPressure;
}

@JsonSerializable()
class Vital {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final VitalType type;
  final double value;
  @JsonKey(name: 'value_secondary')
  final double? valueSecondary; // For BP diastolic
  @JsonKey(name: 'recorded_at')
  final DateTime recordedAt;
  final String? notes;
  final String source; // 'manual', 'device', 'import'
  @JsonKey(name: 'created_at')
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

  factory Vital.fromJson(Map<String, dynamic> json) {
    // FIX (timezone bug): see comment in Appointment.fromJson. Convert
    // UTC timestamps to local so display getters work correctly.
    final v = _$VitalFromJson(json);
    return Vital(
      id: v.id,
      userId: v.userId,
      type: v.type,
      value: v.value,
      valueSecondary: v.valueSecondary,
      recordedAt: v.recordedAt.toLocal(),
      notes: v.notes,
      source: v.source,
      createdAt: v.createdAt.toLocal(),
    );
  }
  Map<String, dynamic> toJson() {
    // FIX (timezone bug): see comment in Appointment.toJson. Convert local
    // DateTime to UTC before serializing so the server stores the correct
    // absolute moment.
    return {
      'id': id,
      'user_id': userId,
      // Use the generated enum map to keep the serialization consistent
      // with the auto-generated _$VitalToJson (which we're overriding).
      'type': _$VitalTypeEnumMap[type],
      'value': value,
      'value_secondary': valueSecondary,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'notes': notes,
      'source': source,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  String get displayValue {
    if (type == VitalType.bloodPressure && valueSecondary != null) {
      return '${value.round()}/${valueSecondary!.round()}';
    }
    return '${value.toStringAsFixed(type == VitalType.temperature ? 1 : 0)}';
  }

  String get displayWithUnit => '$displayValue ${type.unit}';

  /// FIX (audit M-16): add copyWith for immutable updates.
  Vital copyWith({
    String? id,
    String? userId,
    VitalType? type,
    double? value,
    double? valueSecondary,
    DateTime? recordedAt,
    String? notes,
    String? source,
    DateTime? createdAt,
  }) {
    return Vital(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      value: value ?? this.value,
      valueSecondary: valueSecondary ?? this.valueSecondary,
      recordedAt: recordedAt ?? this.recordedAt,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Validates this vital's values against physiologically plausible ranges.
  ///
  /// Returns `null` if valid, or an error message string if invalid.
  ///
  /// FIX (audit H-45, H-46): the Vital model previously had no validation.
  /// A user could log heartRate = 999, spO2 = 150%, or blood pressure with
  /// no diastolic value. These bogus values would flow into trend analysis
  /// and vital-score computation, potentially suppressing real alerts.
  String? validate() {
    final (min, max) = type.validRange;
    if (value < min || value > max) {
      return '${type.displayName} must be between $min and $max ${type.unit}.';
    }

    if (type.requiresSecondary) {
      if (valueSecondary == null) {
        return '${type.displayName} requires both systolic and diastolic values.';
      }
      final (sMin, sMax) = type.validRangeSecondary!;
      if (valueSecondary! < sMin || valueSecondary! > sMax) {
        return '${type.displayName} diastolic must be between $sMin and $sMax ${type.unit}.';
      }
      // Systolic should be greater than diastolic
      if (value <= valueSecondary!) {
        return 'Systolic blood pressure must be greater than diastolic.';
      }
    }

    return null; // valid
  }
}
