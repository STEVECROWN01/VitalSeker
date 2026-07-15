import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weekly_insight.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

/// FIX (audit M-14): use .autoDispose so the insights list is released from
/// memory when the user navigates away from the insights screen. The
/// previous provider retained up to 12 WeeklyInsight objects for the app's
/// entire lifetime. On low-end Android devices (the target market), this
/// contributes to OOM crashes when combined with other non-autoDisposed
/// providers.
final weeklyInsightsProvider = FutureProvider.autoDispose<List<WeeklyInsight>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final db = ref.read(databaseServiceProvider);
  return db.getWeeklyInsights(user.id);
});
