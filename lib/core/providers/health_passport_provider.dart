import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_passport.dart';
import '../services/offline_cache_service.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

final healthPassportProvider = FutureProvider<HealthPassport?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final db = ref.read(databaseServiceProvider);

  // Try network first
  try {
    final passport = await db.getHealthPassport(user.id);
    if (passport != null) {
      // FIX (audit M-15): fire-and-forget the cache write.
      unawaited(OfflineCacheService().cachePassport(user.id, passport.toJson()));
    } else {
      // FIX (audit M-4): the passport was deleted server-side (or never
      // existed). Clear the stale cache so a previously-cached passport
      // doesn't reappear on the next offline load.
      unawaited(OfflineCacheService().clearPassport(user.id));
    }
    return passport;
  } catch (e) {
    // Network failed — fall back to offline cache
    final cached = OfflineCacheService().getCachedPassport(user.id);
    if (cached != null) {
      return HealthPassport.fromJson(cached);
    }
    rethrow;
  }
});

/// FIX (audit M-6): returns null while loading or on error so consumers can
/// show a loading state instead of treating 0 as a real (bad) score. The
/// previous implementation returned 0 while loading, which the HealthPassport
/// model labels as "Critical" — the dashboard would briefly flash
/// "CRITICAL" for a healthy user on every app launch.
final vitalScoreProvider = Provider<int?>((ref) {
  final passportAsync = ref.watch(healthPassportProvider);
  return passportAsync.maybeWhen(
    data: (passport) => passport?.vitalScore,
    orElse: () => null,
  );
});
