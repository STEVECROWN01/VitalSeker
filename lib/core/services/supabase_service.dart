import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _client;

  SupabaseClient get client => _client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? SupabaseConfig.url,
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? SupabaseConfig.anonKey,
      debug: false,
    );
    _client = Supabase.instance.client;
  }

  GoTrueClient get auth => _client.auth;

  // Shorthand methods
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
