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
  final SupabaseClient _client = SupabaseService().client;

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
}
