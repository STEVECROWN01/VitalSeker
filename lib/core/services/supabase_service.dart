import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _client;
  bool _initialized = false;

  SupabaseClient get client {
    if (!_initialized) {
      throw StateError('SupabaseService not initialized. Call initialize() first.');
    }
    return _client;
  }

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    // Always use the hardcoded SupabaseConfig values as the primary source
    // The .env file can override these if present
    final url = dotenv.env['SUPABASE_URL']?.isNotEmpty == true
        ? dotenv.env['SUPABASE_URL']!
        : SupabaseConfig.url;
    final publishableKey = dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty == true
        ? dotenv.env['SUPABASE_ANON_KEY']!
        : SupabaseConfig.publishableKey;

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      debug: false,
    );
    _client = Supabase.instance.client;
    _initialized = true;
  }

  /// Mark the service as initialized after Supabase.initialize() was called
  /// directly (bypassing initialize()). Used by the diagnostic main() which
  /// calls Supabase.initialize() with hardcoded config to skip dotenv.
  void markInitialized() {
    _client = Supabase.instance.client;
    _initialized = true;
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
