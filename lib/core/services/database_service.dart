import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/user_profile.dart';
import '../models/health_passport.dart';
import '../models/symptom_log.dart';
import '../models/family_profile.dart';
import '../models/subscription.dart';
import '../models/weekly_insight.dart';
import '../models/sos_event.dart';

class DatabaseService {
  SupabaseClient? _cachedClient;

  SupabaseClient get _client {
    _cachedClient ??= SupabaseService().client;
    return _cachedClient!;
  }

  // ==================== USERS ====================
  Future<UserProfile?> getUserProfile(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  Future<UserProfile> updateUserProfile(String userId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    final response = await _client
        .from('users')
        .update(data)
        .eq('id', userId)
        .select()
        .single();
    return UserProfile.fromJson(response);
  }

  Future<void> completeOnboarding(String userId) async {
    await _client
        .from('users')
        .update({
          'onboarding_completed': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  // ==================== HEALTH PASSPORTS ====================
  Future<HealthPassport?> getHealthPassport(String userId) async {
    final response = await _client
        .from('health_passports')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) return null;
    return HealthPassport.fromJson(response);
  }

  Future<HealthPassport> createHealthPassport(Map<String, dynamic> data) async {
    final response = await _client
        .from('health_passports')
        .insert(data)
        .select()
        .single();
    return HealthPassport.fromJson(response);
  }

  Future<HealthPassport> updateHealthPassport(String passportId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    final response = await _client
        .from('health_passports')
        .update(data)
        .eq('id', passportId)
        .select()
        .single();
    return HealthPassport.fromJson(response);
  }

  // ==================== SYMPTOM LOGS ====================
  Future<List<SymptomLog>> getSymptomLogs(String userId, {int limit = 50, int offset = 0}) async {
    final response = await _client
        .from('symptom_logs')
        .select()
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .range(offset, offset + limit - 1);
    return response.map((json) => SymptomLog.fromJson(json)).toList();
  }

  Future<SymptomLog> createSymptomLog(Map<String, dynamic> data) async {
    final response = await _client
        .from('symptom_logs')
        .insert(data)
        .select()
        .single();
    return SymptomLog.fromJson(response);
  }

  Future<SymptomLog> updateSymptomLog(String logId, Map<String, dynamic> data) async {
    final response = await _client
        .from('symptom_logs')
        .update(data)
        .eq('id', logId)
        .select()
        .single();
    return SymptomLog.fromJson(response);
  }

  Future<void> deleteSymptomLog(String logId) async {
    await _client.from('symptom_logs').delete().eq('id', logId);
  }

  // ==================== FAMILY PROFILES ====================
  Future<List<FamilyProfile>> getFamilyProfiles(String ownerId) async {
    final response = await _client
        .from('family_profiles')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: true);
    return response.map((json) => FamilyProfile.fromJson(json)).toList();
  }

  Future<FamilyProfile> createFamilyProfile(Map<String, dynamic> data) async {
    final response = await _client
        .from('family_profiles')
        .insert(data)
        .select()
        .single();
    return FamilyProfile.fromJson(response);
  }

  Future<FamilyProfile> updateFamilyProfile(String profileId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    final response = await _client
        .from('family_profiles')
        .update(data)
        .eq('id', profileId)
        .select()
        .single();
    return FamilyProfile.fromJson(response);
  }

  Future<void> deleteFamilyProfile(String profileId) async {
    await _client.from('family_profiles').delete().eq('id', profileId);
  }

  // ==================== SUBSCRIPTIONS ====================
  Future<Subscription?> getSubscription(String userId) async {
    final response = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (response == null) return null;
    return Subscription.fromJson(response);
  }

  Future<Subscription> createSubscription(Map<String, dynamic> data) async {
    final response = await _client
        .from('subscriptions')
        .insert(data)
        .select()
        .single();
    return Subscription.fromJson(response);
  }

  Future<Subscription> updateSubscription(String subId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    final response = await _client
        .from('subscriptions')
        .update(data)
        .eq('id', subId)
        .select()
        .single();
    return Subscription.fromJson(response);
  }

  // ==================== WEEKLY INSIGHTS ====================
  Future<List<WeeklyInsight>> getWeeklyInsights(String userId, {int limit = 12}) async {
    final response = await _client
        .from('weekly_insights')
        .select()
        .eq('user_id', userId)
        .order('week_start', ascending: false)
        .limit(limit);
    return response.map((json) => WeeklyInsight.fromJson(json)).toList();
  }

  // ==================== SOS EVENTS ====================
  Future<List<SosEvent>> getSosEvents(String userId) async {
    final response = await _client
        .from('sos_events')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response.map((json) => SosEvent.fromJson(json)).toList();
  }

  Future<SosEvent> createSosEvent(Map<String, dynamic> data) async {
    final response = await _client
        .from('sos_events')
        .insert(data)
        .select()
        .single();
    return SosEvent.fromJson(response);
  }

  Future<SosEvent> resolveSosEvent(String eventId) async {
    final response = await _client
        .from('sos_events')
        .update({
          'resolved': true,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', eventId)
        .select()
        .single();
    return SosEvent.fromJson(response);
  }

  // ==================== VITALS ====================
  Future<List<Map<String, dynamic>>> getVitals(String userId, {int limit = 1000, int offset = 0}) async {
    final response = await _client
        .from('vitals')
        .select()
        .eq('user_id', userId)
        .order('recorded_at', ascending: false)
        .range(offset, offset + limit - 1);
    return response.toList();
  }

  Future<void> insertVital(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    await _client.from('vitals').insert(data);
  }

  Future<void> deleteVital(String vitalId) async {
    await _client.from('vitals').delete().eq('id', vitalId);
  }

  // ==================== MEDICATIONS ====================
  Future<List<Map<String, dynamic>>> getMedications(String userId) async {
    final response = await _client
        .from('medications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response.toList();
  }

  Future<void> insertMedication(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('medications').insert(data);
  }

  Future<void> updateMedication(String medicationId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('medications').update(data).eq('id', medicationId);
  }

  Future<void> deleteMedication(String medicationId) async {
    await _client.from('medications').delete().eq('id', medicationId);
  }

  // ==================== APPOINTMENTS ====================
  Future<List<Map<String, dynamic>>> getAppointments(String userId) async {
    final response = await _client
        .from('appointments')
        .select()
        .eq('user_id', userId)
        .order('date_time', ascending: true);
    return response.toList();
  }

  Future<void> insertAppointment(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('appointments').insert(data);
  }

  Future<void> updateAppointment(String appointmentId, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toIso8601String();
    await _client.from('appointments').update(data).eq('id', appointmentId);
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _client.from('appointments').delete().eq('id', appointmentId);
  }

  // ==================== MEDICAL RECORDS ====================
  Future<List<Map<String, dynamic>>> getMedicalRecords(String userId) async {
    final response = await _client
        .from('medical_records')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false);
    return response.toList();
  }

  Future<void> insertMedicalRecord(Map<String, dynamic> data) async {
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    await _client.from('medical_records').insert(data);
  }

  Future<void> deleteMedicalRecord(String recordId) async {
    await _client.from('medical_records').delete().eq('id', recordId);
  }

  /// Update an existing medical record. Previously medical_records had no
  /// UPDATE method — once created, records were immutable from the client.
  Future<void> updateMedicalRecord(String recordId, Map<String, dynamic> data) async {
    await _client.from('medical_records').update(data).eq('id', recordId);
  }

  // ==================== AVATAR STORAGE ====================
  /// Uploads an avatar image to the `avatars` storage bucket and returns the
  /// public URL. The path is `avatars/{userId}/avatar.jpg` — overwriting any
  /// previous avatar for the same user (so we don't accumulate stale files).
  ///
  /// The migration 005_avatars_bucket.sql bucket policy enforces that each
  /// user can only write to a path prefixed with their own user id.
  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String contentType,
  }) async {
    final path = '$userId/avatar.jpg';
    await _client.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  /// Remove the avatar file for the given user. Best-effort — does not throw
  /// if the file does not exist.
  Future<void> deleteAvatar(String userId) async {
    final path = '$userId/avatar.jpg';
    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (_) {
      // File may not exist; ignore.
    }
  }

  // ==================== SUPPORT TICKETS ====================
  /// Insert a new support ticket. RLS enforces user_id = auth.uid().
  /// Returns the created ticket row.
  Future<Map<String, dynamic>> insertSupportTicket({
    required String userId,
    required String subject,
    required String message,
    String priority = 'normal',
  }) async {
    final response = await _client
        .from('support_tickets')
        .insert({
          'user_id': userId,
          'subject': subject,
          'message': message,
          'priority': priority,
        })
        .select()
        .single();
    return response;
  }

  /// Fetch the user's support tickets (most recent first).
  Future<List<Map<String, dynamic>>> getSupportTickets(
    String userId, {
    int limit = 20,
  }) async {
    final response = await _client
        .from('support_tickets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return response.toList();
  }
}
