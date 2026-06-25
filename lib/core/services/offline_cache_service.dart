import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

/// Offline cache service using Hive.
///
/// Per Cahier des Charges Section 2.3: "Mode Hors-Ligne — Triage de base et
/// passeport complet accessibles sans internet. Critique pour les marchés
/// émergents et les zones rurales."
///
/// This service caches:
/// - Health passport data (so it's accessible without network)
/// - Symptom log history (for offline viewing)
/// - Pending triage requests (queued for retry when network returns)
/// - User profile (for offline passport display)
///
/// Hive was chosen over Isar/SQLite because:
/// - No native dependencies (pure Dart) — simpler build
/// - Fast key-value storage — sufficient for our caching needs
/// - Type-adapters are optional — we store JSON strings for simplicity
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  static const String _passportBox = 'passport_cache';
  static const String _symptomLogsBox = 'symptom_logs_cache';
  static const String _profileBox = 'profile_cache';
  static const String _pendingTriageBox = 'pending_triage';
  static const String _vitalsBox = 'vitals_cache';

  Box? _passport;
  Box? _symptomLogs;
  Box? _profile;
  Box? _pendingTriage;
  Box? _vitals;

  /// Open all Hive boxes. Call once at app startup (after Hive.initFlutter).
  Future<void> initialize() async {
    try {
      _passport = await Hive.openBox(_passportBox);
      _symptomLogs = await Hive.openBox(_symptomLogsBox);
      _profile = await Hive.openBox(_profileBox);
      _pendingTriage = await Hive.openBox(_pendingTriageBox);
      _vitals = await Hive.openBox(_vitalsBox);
      debugPrint('[OfflineCache] Initialized — all boxes open');
    } catch (e) {
      debugPrint('[OfflineCache] Initialization failed: $e');
    }
  }

  bool get isInitialized =>
      _passport != null && _symptomLogs != null && _profile != null;

  // ── Health Passport ───────────────────────────────────────────────────

  /// Cache the user's health passport for offline access.
  Future<void> cachePassport(String userId, Map<String, dynamic> passportJson) async {
    if (_passport == null) return;
    await _passport!.put(userId, jsonEncode(passportJson));
  }

  /// Get the cached health passport. Returns null if not cached.
  Map<String, dynamic>? getCachedPassport(String userId) {
    if (_passport == null) return null;
    final raw = _passport!.get(userId) as String?;
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clear the cached passport (e.g. on sign-out).
  Future<void> clearPassport(String userId) async {
    if (_passport == null) return;
    await _passport!.delete(userId);
  }

  // ── Symptom Logs ──────────────────────────────────────────────────────

  /// Cache the user's symptom logs for offline viewing.
  Future<void> cacheSymptomLogs(String userId, List<Map<String, dynamic>> logs) async {
    if (_symptomLogs == null) return;
    await _symptomLogs!.put(userId, jsonEncode(logs));
  }

  /// Get cached symptom logs. Returns empty list if not cached.
  List<Map<String, dynamic>> getCachedSymptomLogs(String userId) {
    if (_symptomLogs == null) return [];
    final raw = _symptomLogs!.get(userId) as String?;
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // ── User Profile ──────────────────────────────────────────────────────

  /// Cache the user's profile for offline passport display.
  Future<void> cacheProfile(String userId, Map<String, dynamic> profileJson) async {
    if (_profile == null) return;
    await _profile!.put(userId, jsonEncode(profileJson));
  }

  Map<String, dynamic>? getCachedProfile(String userId) {
    if (_profile == null) return null;
    final raw = _profile!.get(userId) as String?;
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Vitals ────────────────────────────────────────────────────────────

  Future<void> cacheVitals(String userId, List<Map<String, dynamic>> vitals) async {
    if (_vitals == null) return;
    await _vitals!.put(userId, jsonEncode(vitals));
  }

  List<Map<String, dynamic>> getCachedVitals(String userId) {
    if (_vitals == null) return [];
    final raw = _vitals!.get(userId) as String?;
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Pending Triage Queue ──────────────────────────────────────────────

  /// Queue a triage request for later submission when network is available.
  /// Returns the queue entry ID.
  Future<String> queueTriageRequest({
    required List<String> symptoms,
    required int severity,
    String? duration,
    String? notes,
  }) async {
    if (_pendingTriage == null) return '';
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = {
      'id': id,
      'symptoms': symptoms,
      'severity': severity,
      'duration': duration,
      'notes': notes,
      'queued_at': DateTime.now().toIso8601String(),
    };
    await _pendingTriage!.put(id, jsonEncode(entry));
    debugPrint('[OfflineCache] Queued triage request $id');
    return id;
  }

  /// Get all pending triage requests (for retry when network returns).
  List<Map<String, dynamic>> getPendingTriageRequests() {
    if (_pendingTriage == null) return [];
    final results = <Map<String, dynamic>>[];
    for (final key in _pendingTriage!.keys) {
      final raw = _pendingTriage!.get(key) as String?;
      if (raw == null) continue;
      try {
        results.add(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return results;
  }

  /// Remove a triage request from the queue after successful submission.
  Future<void> removePendingTriage(String id) async {
    if (_pendingTriage == null) return;
    await _pendingTriage!.delete(id);
  }

  /// Check if there are pending triage requests to retry.
  bool get hasPendingTriage =>
      _pendingTriage != null && _pendingTriage!.isNotEmpty;

  // ── Clear All ─────────────────────────────────────────────────────────

  /// Clear all cached data for a user (e.g. on sign-out or account deletion).
  Future<void> clearAll(String userId) async {
    await clearPassport(userId);
    if (_symptomLogs != null) await _symptomLogs!.delete(userId);
    if (_profile != null) await _profile!.delete(userId);
    if (_vitals != null) await _vitals!.delete(userId);
    // Don't clear pending triage — those should still be submitted
    debugPrint('[OfflineCache] Cleared all cached data for user $userId');
  }
}
