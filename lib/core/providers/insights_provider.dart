import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weekly_insight.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

final weeklyInsightsProvider = FutureProvider<List<WeeklyInsight>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final db = ref.read(databaseServiceProvider);
  return db.getWeeklyInsights(user.id);
});
