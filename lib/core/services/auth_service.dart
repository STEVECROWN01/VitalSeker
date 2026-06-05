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
  final SupabaseClient _client = SupabaseService().client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  /// Get the Google Web Client ID for OAuth
  /// This should be configured in your Google Cloud Console / Firebase project
  /// and set as GOOGLE_WEB_CLIENT_ID in .env or Supabase dashboard
  String? get _googleWebClientId {
    // Check .env first, then fall back to a placeholder
    final envClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (envClientId != null && envClientId.isNotEmpty) return envClientId;

    // If no client ID is configured, return null (Google Sign-In won't work without it)
    return null;
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

      if (clientId == null || clientId.isEmpty) {
        throw Exception(
          'Google Sign-In requires a Web Client ID to be configured. '
          'Please add your Google Web Client ID to the .env file as GOOGLE_WEB_CLIENT_ID, '
          'or use email/password sign-in for now.'
        );
      }

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
          'Google Sign-In requires a Web Client ID to be configured. '
          'Please add your Google Web Client ID to the .env file as GOOGLE_WEB_CLIENT_ID, '
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
      if (e.toString().contains('not available') || e.toString().contains('notAvailable')) {
        throw Exception('Apple Sign-In is only available on Apple devices. Please use email/password instead.');
      }
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Ignore if Google Sign-In not configured
    }
    await _client.auth.signOut();
  }

  // Password Reset
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // Update Password
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
