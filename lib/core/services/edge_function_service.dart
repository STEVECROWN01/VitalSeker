import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class EdgeFunctionService {
  final SupabaseClient _client = SupabaseService().client;

  /// AI Triage - Analyze symptoms using Claude AI
  Future<Map<String, dynamic>> runTriage({
    required List<String> symptoms,
    required int severity,
    String? duration,
    List<String>? bodyRegions,
    String? notes,
  }) async {
    final response = await _client.functions.invoke(
      'vitalseker-triage',
      body: {
        'symptoms': symptoms,
        'severity': severity,
        'duration': duration,
        'body_regions': bodyRegions,
        'notes': notes,
      },
    );

    if (response.status != 200) {
      throw Exception('Triage failed: ${response.data}');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Generate QR Token for Health Passport
  Future<Map<String, dynamic>> generateQr() async {
    final response = await _client.functions.invoke('generate-qr');
    if (response.status != 200) {
      throw Exception('QR generation failed: ${response.data}');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Export Health Data as PDF
  Future<Map<String, dynamic>> exportPdf({
    String? passportId,
    bool includeHistory = true,
  }) async {
    final response = await _client.functions.invoke(
      'export-pdf',
      body: {
        'passport_id': passportId,
        'include_history': includeHistory,
      },
    );
    if (response.status != 200) {
      throw Exception('PDF export failed: ${response.data}');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Trigger Weekly Insights (admin/CRON)
  Future<Map<String, dynamic>> generateWeeklyInsights() async {
    final response = await _client.functions.invoke('weekly-insights');
    if (response.status != 200) {
      throw Exception('Weekly insights failed: ${response.data}');
    }
    return response.data as Map<String, dynamic>;
  }

  /// SOS Alert - Send emergency SMS
  Future<Map<String, dynamic>> sendSosAlert({
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) async {
    final response = await _client.functions.invoke(
      'sos-alert',
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'location_address': locationAddress,
      },
    );
    if (response.status != 200) {
      throw Exception('SOS alert failed: ${response.data}');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Delete Account - Permanently delete the signed-in user and all their data.
  ///
  /// Calls the `delete-account` edge function which uses the service-role
  /// key to call auth.admin.deleteUser(). The cascading FK on `users.id`
  /// wipes all the user's rows in public.* tables automatically.
  ///
  /// `confirmEmail` must match the signed-in user's email — adds a friction
  /// layer against accidental deletion.
  Future<void> deleteAccount({required String confirmEmail}) async {
    final response = await _client.functions.invoke(
      'delete-account',
      body: {'confirm_email': confirmEmail},
    );
    if (response.status != 200) {
      final data = response.data;
      final message = data is Map ? data['error'] : 'Account deletion failed';
      throw Exception(message ?? 'Account deletion failed');
    }
  }
}
