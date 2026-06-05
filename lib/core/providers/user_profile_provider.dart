import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final db = ref.read(databaseServiceProvider);
  return db.getUserProfile(user.id);
});

final isOnboardingCompletedProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (profile) => profile?.onboardingCompleted ?? false,
    orElse: () => false,
  );
});
