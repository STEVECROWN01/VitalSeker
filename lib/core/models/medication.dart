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
}

enum MedicationStatus {
  active,
  completed,
  discontinued,
}

@JsonSerializable()
class Medication {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final String unit;
  final MedicationFrequency frequency;
  final List<String> times; // e.g. ['08:00', '20:00']
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final bool remindersEnabled;
  final MedicationStatus status;
  final int adherenceCount;
  final int totalDoses;
  final DateTime createdAt;
  final DateTime updatedAt;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    this.unit = 'mg',
    required this.frequency,
    this.times = const [],
    required this.startDate,
    this.endDate,
    this.notes,
    this.remindersEnabled = true,
    this.status = MedicationStatus.active,
    this.adherenceCount = 0,
    this.totalDoses = 0,
    required this.createdAt,
    required this.updatedAt,
  });

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
}
