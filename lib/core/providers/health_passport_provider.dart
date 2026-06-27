import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_passport.dart';
import '../services/database_service.dart';
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
    // Cache for offline use
    if (passport != null) {
      await OfflineCacheService().cachePassport(user.id, passport.toJson());
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

final vitalScoreProvider = Provider<int>((ref) {
  final passportAsync = ref.watch(healthPassportProvider);
  return passportAsync.maybeWhen(
    data: (passport) => passport?.vitalScore ?? 0,
    orElse: () => 0,
  );
});
