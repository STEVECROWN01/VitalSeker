import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_profile.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

/// FIX (audit M-14): use .autoDispose so family profiles are released when
/// the user navigates away from the family screen.
final familyProfilesProvider = FutureProvider.autoDispose<List<FamilyProfile>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final db = ref.read(databaseServiceProvider);
  return db.getFamilyProfiles(user.id);
});
