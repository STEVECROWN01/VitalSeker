import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:math';
import 'supabase_service.dart';

class AuthService {
  // FIX (audit H-52): make _client a lazy getter instead of a field
  // initializer. The previous code `final SupabaseClient _client =
  // SupabaseService().client;` threw StateError if AuthService was
  // instantiated before Supabase.initialize() completed. Since
  // authServiceProvider is a lazy Provider, any widget that reads it
  // during the first frame (before _initializeServices finishes) would
  // throw and put the provider into a permanent error state.
  //
  // With a getter, the SupabaseService().client call is deferred to
  // method-call time, when Supabase is guaranteed to be ready.
  SupabaseClient get _client => SupabaseService().client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  /// Hardcoded fallback Client ID — ensures Google Sign-In always works
  /// even if .env is missing or not loaded properly
  static const String _fallbackGoogleWebClientId =
      '659448117328-evkg728qtc9n2t8bpqitb7d648jn49u5.apps.googleusercontent.com';

  /// Get the Google Web Client ID for OAuth
  /// Priority: .env → hardcoded fallback
  String get _googleWebClientId {
    final envClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (envClientId != null && envClientId.isNotEmpty) return envClientId;
    return _fallbackGoogleWebClientId;
  }

  /// Get a user-friendly error message from an exception
  static String getFriendlyError(dynamic error) {
    final errorString = error.toString();

    // Supabase Auth errors
    if (errorString.contains('Invalid API key')) {
      return 'Authentication service is temporarily unavailable. Please try again later.';
    }
    if (errorString.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }
    if (errorString.contains('Email not confirmed')) {
      return 'Please verify your email address before signing in. Check your inbox for a confirmation link.';
    }
    if (errorString.contains('User already registered')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (errorString.contains('Password should be')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    if (errorString.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (errorString.contains('NetworkException') || errorString.contains('SocketException') || errorString.contains('ClientException')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    // Google Sign-In errors
    if (errorString.contains('sign_in_failed') || errorString.contains('PlatformException')) {
      return 'Google Sign-In failed. Please make sure Google Play Services is updated and try again.';
    }
    if (errorString.contains('Google sign in cancelled')) {
      return 'Google Sign-In was cancelled.';
    }
    if (errorString.contains('Google Sign-In requires a Web Client ID')) {
      return 'Google Sign-In is not fully configured yet. Please use email/password sign-in for now, or contact support.';
    }
    if (errorString.contains('network_error') || errorString.contains('NetworkError')) {
      return 'Network error during Google Sign-In. Please check your internet connection.';
    }

    // Apple Sign-In errors
    if (errorString.contains('AuthorizationErrorCode')) {
      return 'Apple Sign-In failed. Please try again or use email/password.';
    }
    if (errorString.contains('notAvailable')) {
      return 'Apple Sign-In is only available on iOS and macOS devices.';
    }
    if (errorString.contains('not yet fully configured on the server')) {
      return 'Apple Sign-In is not yet fully configured on the server. Please use email/password or Google Sign-In for now.';
    }

    // Generic fallback
    if (errorString.contains('statusCode: 401')) {
      return 'Authentication failed. Please check your credentials and try again.';
    }
    if (errorString.contains('statusCode: 429')) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (errorString.contains('statusCode: 500') || errorString.contains('statusCode: 502') || errorString.contains('statusCode: 503')) {
      return 'Server is temporarily unavailable. Please try again later.';
    }

    // Default: return a generic message instead of raw exception
    debugPrint('[AuthService] Raw error: $errorString');
    return 'Something went wrong. Please try again.';
  }

  // Email/Password Sign Up
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    return response;
  }

  // Email/Password Sign In
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  // Google Sign In
  Future<AuthResponse> signInWithGoogle() async {
    try {
      final clientId = _googleWebClientId;

      final googleSignIn = GoogleSignIn(
        serverClientId: clientId,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google sign in cancelled');

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(
          'Google Sign-In failed to retrieve ID token. '
          'Please make sure your Google Cloud Console has the correct OAuth Web Client configured, '
          'or use email/password sign-in for now.'
        );
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return response;
    } on PlatformException catch (e) {
      debugPrint('[AuthService] Google Sign-In PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'sign_in_failed') {
        throw Exception(
          'Google Sign-In failed. Make sure Google Play Services is updated. '
          'You can also use email/password sign-in.'
        );
      }
      throw Exception(
        'Google Sign-In is not yet configured for this app. '
        'Please use email/password sign-in instead.'
      );
    }
  }

  // Apple Sign In
  Future<AuthResponse> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('No ID Token found from Apple');

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      return response;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('not available') || errorStr.contains('notAvailable')) {
        throw Exception('Apple Sign-In is only available on Apple devices. Please use email/password instead.');
      }
      if (errorStr.contains('Unsupported provider') || errorStr.contains('missing OAuth client ID')) {
        throw Exception(
          'Apple Sign-In is not yet fully configured on the server. '
          'Please use email/password or Google Sign-In for now.'
        );
      }
      rethrow;
    }
  }

  // Sign Out
  //
  // FIX: use GoogleSignIn().disconnect() (not signOut()) to revoke the
  // OAuth grant server-side. Without disconnect, user A's Google account
  // stays "connected" to the app — user B can sign in with the same
  // Google account with one tap (no re-auth). disconnect() is async and
  // may take a few seconds; we wrap in try/catch so a failure doesn't
  // block the Supabase signOut that follows.
  Future<void> signOut() async {
    try {
      await GoogleSignIn().disconnect();
    } catch (_) {
      // Ignore if Google Sign-In not configured or already disconnected.
      // Fall back to signOut() for safety.
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await _client.auth.signOut();
  }

  // Password Reset
  //
  // FIX (audit BUG #4): pass `redirectTo: 'vitalseker://reset-password'` so
  // the password-reset email link opens the app directly (via the deep-link
  // intent filter declared in AndroidManifest.xml) instead of opening a
  // browser tab to Supabase's default Site URL. The corresponding Dart-side
  // deep-link handler routes the user to the new ResetPasswordScreen.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'vitalseker://reset-password',
    );
  }

  // Update Password — called from the ResetPasswordScreen after the user
  // clicks the email link and the deep-link handler routes them to the
  // new-password form.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
}
