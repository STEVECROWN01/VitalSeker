import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/revenuecat_service.dart';
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

  // Wire RevenueCat initialization to auth state changes.
  //
  // CRITICAL FIX (audit C-16 / H-48): RevenueCatService.initialize() was
  // never called anywhere in the app, so every IAP check was dead code and
  // the entire Pro payment flow fell back to direct DB writes (which were
  // client-writable, allowing free self-grant of Pro).
  //
  // Now: on every auth event, we either initialize RevenueCat for the new
  // user (sign-in / token refresh) or sign out RevenueCat (sign-out). The
  // RevenueCat service is idempotent — calling initialize() with the same
  // userId is a no-op, and signOut() resets its internal state so the next
  // sign-in with a different user re-initializes cleanly.
  final stream = SupabaseService().client.auth.onAuthStateChange;
  return stream.map((authState) {
    final event = authState.event;
    final user = authState.session?.user;

    if (event == AuthChangeEvent.signedOut) {
      // Fire-and-forget — don't block the stream. Errors are non-fatal: the
      // user is signing out anyway and we already reset the cached state
      // inside RevenueCatService.signOut().
      RevenueCatService().signOut().catchError((e) {
        debugPrint('[Auth] RevenueCat signOut failed: $e');
      });
    } else if (user != null) {
      // signedIn, tokenRefreshed, passwordRecovery, mfaChallengeVerified,
      // userUpdated — all imply an authenticated session. (Re)initialize
      // RevenueCat for this user. Idempotent for the same user; switches
      // appUserID cleanly for a different user.
      RevenueCatService().initialize(user.id).catchError((e) {
        debugPrint('[Auth] RevenueCat initialize failed: $e');
      });
    }

    return authState;
  });
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
