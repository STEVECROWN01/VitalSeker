import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vital.dart';
import '../providers/auth_provider.dart';
import '../services/offline_cache_service.dart';
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
      source: 'manual',
      createdAt: now,
    );

    // FIX (audit H-45, H-46): validate the vital before inserting. Reject
    // out-of-range values and require valueSecondary for blood pressure.
    // The validate() method returns an error message string or null.
    final validationError = vital.validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    try {
      final db = ref.read(databaseServiceProvider);
      await db.insertVital(vital.toJson());
      ref.invalidateSelf();
    } catch (e) {
      // FIX: if the insert fails (likely offline), queue it for later
      // submission instead of losing the data. The user sees a
      // "saved offline — will sync when online" message.
      try {
        await OfflineCacheService().queuePendingWrite(
          table: 'vitals',
          payload: vital.toJson(),
        );
        debugPrint('[Vitals] insert failed — queued for offline sync: $e');
        ref.invalidateSelf();
        // Don't rethrow — the data is safely queued.
        return;
      } catch (queueErr) {
        debugPrint('[Vitals] failed to queue offline write: $queueErr');
      }
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

/// FIX (audit M-14): use .autoDispose so the filtered list is released when
/// the vitals history screen is popped. The family provider creates one
/// instance per VitalType — without autoDispose, all 7 types stay in memory
/// for the app's lifetime.
final vitalsByTypeProvider = Provider.autoDispose.family<List<Vital>, VitalType>((ref, type) {
  final vitals = ref.watch(vitalsProvider).valueOrNull ?? [];
  return vitals.where((v) => v.type == type).toList();
});

final latestVitalProvider = Provider.autoDispose.family<Vital?, VitalType>((ref, type) {
  final vitals = ref.watch(vitalsByTypeProvider(type));
  if (vitals.isEmpty) return null;
  final sorted = List<Vital>.from(vitals)..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  return sorted.first;
});
