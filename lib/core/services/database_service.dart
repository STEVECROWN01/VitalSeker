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
    // FIX (audit M-4): operate on a copy so the caller's map isn't mutated.
    final payload = {...data, 'updated_at': DateTime.now().toIso8601String()};
    final response = await _client
        .from('users')
        .update(payload)
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
    final payload = {...data, 'updated_at': DateTime.now().toIso8601String()};
    final response = await _client
        .from('health_passports')
        .update(payload)
        .eq('id', passportId)
        .select()
        .single();
    return HealthPassport.fromJson(response);
  }

  // ==================== SYMPTOM LOGS ====================
  /// FIX (audit M-7): clamp limit to [1, 500] and offset to >= 0 to prevent
  /// .range(0, -1) (which is undefined behavior) and unbounded queries.
  Future<List<SymptomLog>> getSymptomLogs(String userId, {int limit = 50, int offset = 0}) async {
    final clampedLimit = limit.clamp(1, 500);
    final clampedOffset = offset < 0 ? 0 : offset;
    final response = await _client
        .from('symptom_logs')
        .select()
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .range(clampedOffset, clampedOffset + clampedLimit - 1);
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
    final payload = {...data, 'updated_at': DateTime.now().toIso8601String()};
    final response = await _client
        .from('symptom_logs')
        .update(payload)
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
    final payload = {...data, 'updated_at': DateTime.now().toIso8601String()};
    final response = await _client
        .from('family_profiles')
        .update(payload)
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
    final payload = {...data, 'updated_at': DateTime.now().toIso8601String()};
    final response = await _client
        .from('subscriptions')
        .update(payload)
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

  /// FIX (audit M-5): use .maybeSingle() instead of .single() so a missing
  /// or already-resolved event doesn't throw PostgrestException. Returns
  /// null if no rows match.
  Future<SosEvent?> resolveSosEvent(String eventId) async {
    final response = await _client
        .from('sos_events')
        .update({
          'resolved': true,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', eventId)
        .select()
        .maybeSingle();
    if (response == null) return null;
    return SosEvent.fromJson(response);
  }

  // ==================== VITALS ====================
  /// FIX (audit M-7): clamp limit to [1, 500] and offset to >= 0.
  /// Also reduced default limit from 1000 to 500 to reduce memory pressure.
  Future<List<Map<String, dynamic>>> getVitals(String userId, {int limit = 500, int offset = 0}) async {
    final clampedLimit = limit.clamp(1, 500);
    final clampedOffset = offset < 0 ? 0 : offset;
    final response = await _client
        .from('vitals')
        .select()
        .eq('user_id', userId)
        .order('recorded_at', ascending: false)
        .range(clampedOffset, clampedOffset + clampedLimit - 1);
    return response.toList();
  }

  Future<void> insertVital(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data)..remove('id');
    payload['created_at'] = DateTime.now().toIso8601String();
    await _client.from('vitals').insert(payload);
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

  Future<String> insertMedication(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data)..remove('id');
    payload['created_at'] = DateTime.now().toIso8601String();
    payload['updated_at'] = DateTime.now().toIso8601String();
    final response = await _client
        .from('medications')
        .insert(payload)
        .select('id')
        .single();
    return response['id'].toString();
  }

  Future<void> updateMedication(String medicationId, Map<String, dynamic> data) async {
    final payload = {...data, 'updated_at': DateTime.now().toIso8601String()};
    await _client.from('medications').update(payload).eq('id', medicationId);
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

  Future<String> insertAppointment(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data)..remove('id');
    payload['created_at'] = DateTime.now().toIso8601String();
    payload['updated_at'] = DateTime.now().toIso8601String();
    final response = await _client
        .from('appointments')
        .insert(payload)
        .select('id')
        .single();
    return response['id'].toString();
  }

  Future<void> updateAppointment(String appointmentId, Map<String, dynamic> data) async {
    final payload = {...data, 'updated_at': DateTime.now().toIso8601String()};
    await _client.from('appointments').update(payload).eq('id', appointmentId);
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
    final payload = Map<String, dynamic>.from(data)..remove('id');
    payload['created_at'] = DateTime.now().toIso8601String();
    await _client.from('medical_records').insert(payload);
  }

  Future<void> deleteMedicalRecord(String recordId) async {
    await _client.from('medical_records').delete().eq('id', recordId);
  }

  /// Update an existing medical record.
  ///
  /// FIX (audit M-3): set `updated_at` for consistency with all other update
  /// methods. Previously this was the only update method that didn't set
  /// `updated_at`, leaving the column stale or null after client updates.
  Future<void> updateMedicalRecord(String recordId, Map<String, dynamic> data) async {
    final payload = {...data, 'updated_at': DateTime.now().toIso8601String()};
    await _client.from('medical_records').update(payload).eq('id', recordId);
  }

  // ==================== AVATAR STORAGE ====================
  /// Uploads an avatar image to the `avatars` storage bucket and returns the
  /// public URL. The path is `avatars/{userId}/avatar.jpg` — overwriting any
  /// previous avatar for the same user (so we don't accumulate stale files).
  ///
  /// The migration 005_avatars_bucket.sql bucket policy enforces that each
  /// user can only write to a path prefixed with their own user id.
  ///
  /// CRITICAL FIX: the avatars bucket is private (migration 010 set
  /// `public = false`), so `getPublicUrl` returns a URL that 400/403s on
  /// fetch. Use `createSignedUrl` instead — the URL expires after 1 hour
  /// but is refreshed on each profile load.
  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String contentType,
  }) async {
    // Always save as JPEG — image_picker already re-encodes with
    // imageQuality: 85 (JPEG), so the source bytes ARE JPEG even if the
    // original was PNG. Using a fixed extension simplifies deleteAvatar
    // (no need to remember the extension).
    final path = '$userId/avatar.jpg';
    await _client.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    // Create a signed URL (1-hour expiry) instead of a public URL — the
    // bucket is private so public URLs return 400/403.
    final signedUrlResponse = await _client.storage
        .from('avatars')
        .createSignedUrl(path, 3600);
    final signedUrl = signedUrlResponse;
    // Append a cache-busting timestamp so CachedNetworkImage fetches the
    // new image instead of serving the cached old one.
    final separator = signedUrl.contains('?') ? '&' : '?';
    return '$signedUrl${separator}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Remove the avatar file for the given user. Best-effort — does not throw
  /// if the file does not exist.
  Future<void> deleteAvatar(String userId) async {
    // Always .jpg now (see uploadAvatar).
    final path = '$userId/avatar.jpg';
    try {
      await _client.storage.from('avatars').remove([path]);
    } catch (_) {
      // File may not exist; ignore.
    }
  }

  /// Returns a fresh signed URL for the user's avatar (1-hour expiry).
  /// Call this on profile load to refresh expired URLs.
  /// Returns null if the avatar doesn't exist or the bucket is unreachable.
  Future<String?> refreshAvatarUrl(String userId) async {
    final path = '$userId/avatar.jpg';
    try {
      final signedUrl = await _client.storage
          .from('avatars')
          .createSignedUrl(path, 3600);
      return signedUrl;
    } catch (_) {
      return null;
    }
  }

  // ==================== AI CHAT MESSAGES ====================
  /// Load the most recent N AI chat messages for the user, ordered
  /// oldest-first (so they can be appended to the message list directly).
  Future<List<Map<String, dynamic>>> getChatMessages(
    String userId, {
    int limit = 50,
  }) async {
    final clampedLimit = limit.clamp(1, 500);
    final response = await _client
        .from('ai_chat_messages')
        .select('id, role, content, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(clampedLimit);
    // Reverse to oldest-first for display.
    return response.reversed.toList();
  }

  /// Insert a chat message. Returns the inserted row's id.
  Future<String> insertChatMessage({
    required String userId,
    required String role, // 'user' or 'assistant'
    required String content,
  }) async {
    final response = await _client
        .from('ai_chat_messages')
        .insert({
          'user_id': userId,
          'role': role,
          'content': content,
        })
        .select('id')
        .single();
    return response['id'].toString();
  }

  /// Delete all chat messages for the user (clear history).
  Future<void> clearChatMessages(String userId) async {
    await _client
        .from('ai_chat_messages')
        .delete()
        .eq('user_id', userId);
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
