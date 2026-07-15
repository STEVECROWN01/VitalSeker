import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'medication.g.dart';

enum MedicationFrequency {
  onceDaily,
  twiceDaily,
  threeTimesDaily,
  fourTimesDaily,
  everyOtherDay,
  weekly,
  asNeeded,
  custom,
}

extension MedicationFrequencyX on MedicationFrequency {
  String get displayName {
    switch (this) {
      case MedicationFrequency.onceDaily: return 'Once daily';
      case MedicationFrequency.twiceDaily: return 'Twice daily';
      case MedicationFrequency.threeTimesDaily: return '3 times daily';
      case MedicationFrequency.fourTimesDaily: return '4 times daily';
      case MedicationFrequency.everyOtherDay: return 'Every other day';
      case MedicationFrequency.weekly: return 'Weekly';
      case MedicationFrequency.asNeeded: return 'As needed';
      case MedicationFrequency.custom: return 'Custom';
    }
  }

  /// The snake_case string used in the DB and JSON serialization.
  /// Use this instead of `.name` (which returns camelCase) when writing
  /// to the database, so the value matches what `Medication.fromJson`
  /// expects.
  String get jsonValue {
    switch (this) {
      case MedicationFrequency.onceDaily: return 'once_daily';
      case MedicationFrequency.twiceDaily: return 'twice_daily';
      case MedicationFrequency.threeTimesDaily: return 'three_times_daily';
      case MedicationFrequency.fourTimesDaily: return 'four_times_daily';
      case MedicationFrequency.everyOtherDay: return 'every_other_day';
      case MedicationFrequency.weekly: return 'weekly';
      case MedicationFrequency.asNeeded: return 'as_needed';
      case MedicationFrequency.custom: return 'custom';
    }
  }
}

enum MedicationStatus {
  active,
  completed,
  discontinued,
}

/// FIX (audit M-11): validate that time strings are in zero-padded HH:mm
/// format. The `nextDoseTime` getter uses string comparison, which only
/// works correctly when both strings are zero-padded. Without validation,
/// a user entering "8:00" instead of "08:00" would get wrong results:
/// "8:00".compareTo("09:00") returns negative (because "8" < "0" is false,
/// actually "8" > "0" so it returns positive) — the comparison is broken.
final _timeFormatRegexp = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

/// FIX (audit M-11): validate and NORMALIZE time strings. Instead of
/// throwing (which would crash the app if existing DB data has non-standard
/// formats like "8:00"), we normalize to "08:00" and log a warning.
List<String> _validateAndNormalizeTimes(List<String> times) {
  final result = <String>[];
  for (final t in times) {
    if (_timeFormatRegexp.hasMatch(t)) {
      result.add(t);
    } else {
      // Try to normalize: parse "H:mm" → "0H:mm"
      final parts = t.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? -1;
        final minute = int.tryParse(parts[1]) ?? -1;
        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          final normalized =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          debugPrint('[Medication] Normalized time "$t" → "$normalized"');
          result.add(normalized);
          continue;
        }
      }
      // Can't normalize — use "00:00" as fallback and log.
      debugPrint('[Medication] WARNING: Invalid time format "$t", using "00:00"');
      result.add('00:00');
    }
  }
  return result;
}

@JsonSerializable()
class Medication {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String name;
  final String dosage;
  final String unit;
  final MedicationFrequency frequency;
  final List<String> times; // e.g. ['08:00', '20:00']
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @JsonKey(name: 'end_date')
  final DateTime? endDate;
  final String? notes;
  @JsonKey(name: 'reminders_enabled')
  final bool remindersEnabled;
  final MedicationStatus status;
  @JsonKey(name: 'adherence_count')
  final int adherenceCount;
  @JsonKey(name: 'total_doses')
  final int totalDoses;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    this.unit = 'mg',
    required this.frequency,
    List<String> times = const [],
    required this.startDate,
    this.endDate,
    this.notes,
    this.remindersEnabled = true,
    this.status = MedicationStatus.active,
    this.adherenceCount = 0,
    this.totalDoses = 0,
    required this.createdAt,
    required this.updatedAt,
  }) : times = _validateAndNormalizeTimes(times);

  factory Medication.fromJson(Map<String, dynamic> json) => _$MedicationFromJson(json);
  Map<String, dynamic> toJson() => _$MedicationToJson(this);

  double get adherencePercentage => totalDoses == 0 ? 0 : (adherenceCount / totalDoses * 100);

  String get nextDoseTime {
    if (times.isEmpty) return 'No schedule';
    final now = DateTime.now();
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    for (final time in times) {
      if (time.compareTo(currentTime) > 0) return time;
    }
    return times.first; // Next dose is tomorrow
  }

  String get displayDosage => '$dosage $unit';

  String get displayFrequency => frequency.displayName;

  /// FIX (audit M-16): add copyWith for immutable updates.
  Medication copyWith({
    String? id,
    String? userId,
    String? name,
    String? dosage,
    String? unit,
    MedicationFrequency? frequency,
    List<String>? times,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    bool? remindersEnabled,
    MedicationStatus? status,
    int? adherenceCount,
    int? totalDoses,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
      frequency: frequency ?? this.frequency,
      times: times ?? this.times,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      status: status ?? this.status,
      adherenceCount: adherenceCount ?? this.adherenceCount,
      totalDoses: totalDoses ?? this.totalDoses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
