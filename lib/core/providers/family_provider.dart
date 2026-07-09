import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_profile.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

final familyProfilesProvider = FutureProvider<List<FamilyProfile>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final db = ref.read(databaseServiceProvider);
  return db.getFamilyProfiles(user.id);
});
