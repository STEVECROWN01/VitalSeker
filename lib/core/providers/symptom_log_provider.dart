import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/symptom_log.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';

final symptomLogsProvider = FutureProvider<List<SymptomLog>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final db = ref.read(databaseServiceProvider);
  return db.getSymptomLogs(user.id);
});
