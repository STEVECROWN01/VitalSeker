import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/symptom_log.dart';
import '../services/offline_cache_service.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

final symptomLogsProvider = FutureProvider<List<SymptomLog>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final db = ref.read(databaseServiceProvider);

  // Try network first
  try {
    final logs = await db.getSymptomLogs(user.id);
    // Cache for offline use
    if (logs.isNotEmpty) {
      await OfflineCacheService().cacheSymptomLogs(
        user.id,
        logs.map((l) => l.toJson()).toList(),
      );
    }
    return logs;
  } catch (e) {
    // Network failed — fall back to offline cache
    final cached = OfflineCacheService().getCachedSymptomLogs(user.id);
    if (cached.isNotEmpty) {
      return cached.map((json) => SymptomLog.fromJson(json)).toList();
    }
    return [];
  }
});
