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
  final subAsync = ref.watch(subscriptionProvider);
  return subAsync.maybeWhen(
    data: (sub) => sub?.isPro ?? false,
    orElse: () => false,
  );
});
