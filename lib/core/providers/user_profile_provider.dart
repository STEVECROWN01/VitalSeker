import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/offline_cache_service.dart';
import 'auth_provider.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final db = ref.read(databaseServiceProvider);

  // Try network first
  try {
    final profile = await db.getUserProfile(user.id);
    // FIX (audit M-15): fire-and-forget the cache write instead of awaiting
    // it. The cache write doesn't affect the return value, and awaiting it
    // adds unnecessary latency to the profile load (Hive writes are usually
    // fast, but on a slow disk they can add tens of milliseconds).
    if (profile != null) {
      unawaited(OfflineCacheService().cacheProfile(user.id, profile.toJson()));
    }
    return profile;
  } catch (e) {
    // Network failed — fall back to offline cache
    final cached = OfflineCacheService().getCachedProfile(user.id);
    if (cached != null) {
      return UserProfile.fromJson(cached);
    }
    return null;
  }
});

final isOnboardingCompletedProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile?.onboardingCompleted ?? false,
    orElse: () => false,
  );
});
