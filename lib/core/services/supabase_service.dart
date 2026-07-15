import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// SupabaseService — singleton wrapper around the Supabase client.
///
/// FIX (audit M-25): removed the dead `initialize()` method. main.dart calls
/// `Supabase.initialize()` directly and then `markInitialized()`. The
/// `initialize()` method was never called from anywhere — its dotenv-override
/// logic was therefore never exercised.
///
/// FIX (audit M-26): `markInitialized()` now has a try/catch with a clear
/// error message in case `Supabase.initialize()` hasn't been called yet.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _client;
  bool _initialized = false;

  SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'SupabaseService not initialized. Call Supabase.initialize() and '
        'SupabaseService().markInitialized() before accessing the client. '
        'This usually happens during cold start — the splash screen should '
        'wait for Supabase to be ready.',
      );
    }
    return _client;
  }

  bool get isInitialized => _initialized;

  /// Mark the service as initialized after `Supabase.initialize()` was
  /// called directly in main.dart. This is the only initialization path —
  /// the previous `initialize()` method is removed because it was never
  /// called and its dotenv-override logic was dead code.
  ///
  /// FIX (audit M-26): wrap in try/catch with a clear error message.
  void markInitialized() {
    try {
      _client = Supabase.instance.client;
      _initialized = true;
      debugPrint('[SupabaseService] Marked as initialized');
    } catch (e) {
      debugPrint('[SupabaseService] markInitialized() failed — '
          'Supabase.initialize() has not been called yet: $e');
      // Don't set _initialized = true — the client is not usable.
    }
  }

  GoTrueClient get auth => _client.auth;

  PostgrestQueryBuilder fromTable(String table) => _client.from(table);

  Future<Map<String, dynamic>> invokeEdgeFunction(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.functions.invoke(
      functionName,
      body: body,
    );
    if (response.status != 200) {
      throw Exception('Edge function $functionName failed: ${response.data}');
    }
    return response.data as Map<String, dynamic>;
  }
}
