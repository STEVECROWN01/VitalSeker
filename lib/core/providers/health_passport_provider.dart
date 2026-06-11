import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_passport.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

final healthPassportProvider = FutureProvider<HealthPassport?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final db = ref.read(databaseServiceProvider);
  return db.getHealthPassport(user.id);
});

final vitalScoreProvider = Provider<int>((ref) {
  final passportAsync = ref.watch(healthPassportProvider);
  return passportAsync.maybeWhen(
    data: (passport) => passport?.vitalScore ?? 0,
    orElse: () => 0,
  );
});
