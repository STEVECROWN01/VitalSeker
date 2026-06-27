import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vital.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import 'user_profile_provider.dart';

final vitalsProvider = AsyncNotifierProvider<VitalsNotifier, List<Vital>>(VitalsNotifier.new);

class VitalsNotifier extends AsyncNotifier<List<Vital>> {
  @override
  Future<List<Vital>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    final db = ref.read(databaseServiceProvider);
    final data = await db.getVitals(user.id);
    return data.map((e) => Vital.fromJson(e)).toList();
  }

  Future<void> addVital(VitalType type, double value, {double? valueSecondary, String? notes, DateTime? recordedAt}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final now = DateTime.now();
    final vital = Vital(
      id: '',
      userId: user.id,
      type: type,
      value: value,
      valueSecondary: valueSecondary,
      recordedAt: recordedAt ?? now,
      notes: notes,
      createdAt: now,
    );
    try {
      final db = ref.read(databaseServiceProvider);
      await db.insertVital(vital.toJson());
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteVital(String vitalId) async {
    try {
      final db = ref.read(databaseServiceProvider);
      await db.deleteVital(vitalId);
      ref.invalidateSelf();
    } catch (e) {
      rethrow;
    }
  }

  List<Vital> getVitalsByType(VitalType type) {
    return state.valueOrNull?.where((v) => v.type == type).toList() ?? [];
  }

  Vital? getLatestVital(VitalType type) {
    final vitals = getVitalsByType(type);
    if (vitals.isEmpty) return null;
    vitals.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return vitals.first;
  }
}

final vitalsByTypeProvider = Provider.family<List<Vital>, VitalType>((ref, type) {
  final vitals = ref.watch(vitalsProvider).valueOrNull ?? [];
  return vitals.where((v) => v.type == type).toList();
});

final latestVitalProvider = Provider.family<Vital?, VitalType>((ref, type) {
  final vitals = ref.watch(vitalsByTypeProvider(type));
  if (vitals.isEmpty) return null;
  final sorted = List<Vital>.from(vitals)..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  return sorted.first;
});
