import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

final subscriptionProvider = FutureProvider<Subscription?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final db = ref.read(databaseServiceProvider);
  return db.getSubscription(user.id);
});

final isProUserProvider = Provider<bool>((ref) {
  // First check the subscriptions table
  final subAsync = ref.watch(subscriptionProvider);
  final isProFromSub = subAsync.maybeWhen(
    data: (sub) => sub?.isPro ?? false,
    orElse: () => false,
  );
  // Also check the user profile's subscription_status as fallback
  // (for dev-mode subscriptions set directly on the profile)
  if (isProFromSub) return true;
  final profileAsync = ref.watch(userProfileProvider);
  final isProFromProfile = profileAsync.maybeWhen(
    data: (profile) => profile?.subscriptionStatus == 'pro',
    orElse: () => false,
  );
  return isProFromProfile;
});
