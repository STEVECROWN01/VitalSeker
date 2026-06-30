import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream of Supabase auth state changes.
///
/// Defensively returns an empty stream if Supabase isn't initialized yet.
/// In the new startup flow (main.dart), Supabase.initialize() runs in the
/// background AFTER runApp(). Until it completes, SupabaseService.client
/// would throw StateError, which would freeze the splash screen forever
/// (StreamProvider swallows the exception and stays in loading state).
/// Returning an empty stream lets the splash screen treat "no auth state"
/// as "not authenticated" and route to onboarding/login — the correct UX
/// for a fresh install.
final authStateProvider = StreamProvider<AuthState>((ref) {
  if (!SupabaseService().isInitialized) {
    return const Stream<AuthState>.empty();
  }
  return SupabaseService().client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
