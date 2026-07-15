import 'dart:async';
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
    // FIX (audit M-5): always write to cache on successful network response,
    // even when the list is empty. The previous code skipped the cache write
    // when logs was empty — so if the user deleted all their logs, the cache
    // retained the previous (non-empty) list and deleted logs reappeared
    // on the next offline load.
    //
    // FIX (audit M-15): fire-and-forget the cache write.
    unawaited(OfflineCacheService().cacheSymptomLogs(
      user.id,
      logs.map((l) => l.toJson()).toList(),
    ));
    return logs;
  } catch (e) {
    // Network failed — fall back to offline cache
    final cached = OfflineCacheService().getCachedSymptomLogs(user.id);
    return cached.map((json) => SymptomLog.fromJson(json)).toList();
  }
});
