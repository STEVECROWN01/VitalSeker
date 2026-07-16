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
///
/// SECURITY NOTE (audit M-27): the cached data includes PHI (allergies,
/// conditions, medications, symptom logs). Hive supports encrypted boxes
/// via `Hive.openBox(name, encryptionKey: key)`. The current implementation
/// does NOT encrypt — to enable encryption, add `flutter_secure_storage`
/// to pubspec.yaml, generate a per-install key in the Android Keystore /
/// iOS Keychain, and pass it to `Hive.openBox`. See the TODO in
/// [_getEncryptionKey] below.
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

  /// TODO (audit M-27): implement encryption.
  ///
  /// To enable Hive encryption:
  /// 1. Add `flutter_secure_storage: ^9.0.0` to pubspec.yaml
  /// 2. Generate a per-install encryption key:
  ///    ```dart
  ///    final secureStorage = FlutterSecureStorage();
  ///    String? key = await secureStorage.read(key: 'hive_encryption_key');
  ///    if (key == null) {
  ///      key = base64Url.encode(Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256))));
  ///      await secureStorage.write(key: 'hive_encryption_key', value: key);
  ///    }
  ///    final encryptionKey = base64Url.decode(key);
  ///    ```
  /// 3. Pass `encryptionKey: encryptionKey` to each `Hive.openBox` call below.
  ///
  /// Without encryption, a device thief or root-access attacker can read
  /// the user's full medical history from Hive's plain-text files. This is
  /// a compliance concern (GDPR Art. 32, HIPAA Security Rule).
  Future<List<int>?> _getEncryptionKey() async {
    // Placeholder — returns null (no encryption) until flutter_secure_storage
    // is added to pubspec.yaml.
    return null;
  }

  /// Open all Hive boxes. Call once at app startup (after Hive.initFlutter).
  Future<void> initialize() async {
    try {
      // FIX (audit H-10): wrap each openBox in its own try/catch so a single
      // corrupt box doesn't prevent the others from opening.
      final encKey = await _getEncryptionKey();

      try {
        _passport = await Hive.openBox(_passportBox,
            encryptionKey: encKey);
      } catch (e) {
        debugPrint('[OfflineCache] passport box failed: $e');
      }

      try {
        _symptomLogs = await Hive.openBox(_symptomLogsBox,
            encryptionKey: encKey);
      } catch (e) {
        debugPrint('[OfflineCache] symptom logs box failed: $e');
      }

      try {
        _profile = await Hive.openBox(_profileBox,
            encryptionKey: encKey);
      } catch (e) {
        debugPrint('[OfflineCache] profile box failed: $e');
      }

      try {
        _pendingTriage = await Hive.openBox(_pendingTriageBox,
            encryptionKey: encKey);
      } catch (e) {
        debugPrint('[OfflineCache] pending triage box failed: $e');
      }

      try {
        _vitals = await Hive.openBox(_vitalsBox,
            encryptionKey: encKey);
      } catch (e) {
        debugPrint('[OfflineCache] vitals box failed: $e');
      }

      debugPrint('[OfflineCache] Initialized — boxes open');
    } catch (e) {
      debugPrint('[OfflineCache] Initialization failed: $e');
    }
  }

  /// FIX (audit H-9): check ALL 5 boxes, not just 3. Previously
  /// isInitialized returned true even if _pendingTriage or _vitals failed
  /// to open, causing queueTriageRequest and cacheVitals to silently no-op.
  bool get isInitialized =>
      _passport != null &&
      _symptomLogs != null &&
      _profile != null &&
      _pendingTriage != null &&
      _vitals != null;

  // ── Health Passport ───────────────────────────────────────────────────

  /// Cache TTL: 24 hours. Cached data older than this is considered stale
  /// and returns null from the getters, forcing a re-fetch from the server.
  /// FIX (audit M-28): the previous cache had no TTL — stale passport/profile
  /// data was served indefinitely. For a medical passport, stale data
  /// (wrong blood type, outdated allergies) can be dangerous.
  static const Duration _cacheTtl = Duration(hours: 24);

  /// Wrap cached data with a timestamp so we can enforce TTL on read.
  Map<String, dynamic> _wrapWithTtl(dynamic data) {
    return {
      'data': data,
      'cached_at': DateTime.now().toIso8601String(),
    };
  }

  /// Unwrap cached data and check TTL. Returns null if expired or corrupt.
  dynamic _unwrapWithTtl(String? raw) {
    if (raw == null) return null;
    try {
      final wrapper = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAtStr = wrapper['cached_at'] as String?;
      if (cachedAtStr != null) {
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt != null &&
            DateTime.now().difference(cachedAt) > _cacheTtl) {
          // Stale — return null to force a re-fetch.
          return null;
        }
      }
      return wrapper['data'];
    } catch (_) {
      // Maybe old-format cache without the wrapper — try parsing directly.
      try {
        return jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }
  }

  /// Cache the user's health passport for offline access.
  Future<void> cachePassport(String userId, Map<String, dynamic> passportJson) async {
    if (_passport == null) return;
    await _passport!.put(userId, jsonEncode(_wrapWithTtl(passportJson)));
  }

  /// Get the cached health passport. Returns null if not cached or expired.
  Map<String, dynamic>? getCachedPassport(String userId) {
    if (_passport == null) return null;
    final raw = _passport!.get(userId) as String?;
    final data = _unwrapWithTtl(raw);
    if (data is Map<String, dynamic>) return data;
    return null;
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
    await _symptomLogs!.put(userId, jsonEncode(_wrapWithTtl(logs)));
  }

  /// Get cached symptom logs. Returns empty list if not cached or expired.
  List<Map<String, dynamic>> getCachedSymptomLogs(String userId) {
    if (_symptomLogs == null) return [];
    final raw = _symptomLogs!.get(userId) as String?;
    final data = _unwrapWithTtl(raw);
    if (data is List) {
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  // ── User Profile ──────────────────────────────────────────────────────

  /// Cache the user's profile for offline passport display.
  Future<void> cacheProfile(String userId, Map<String, dynamic> profileJson) async {
    if (_profile == null) return;
    await _profile!.put(userId, jsonEncode(_wrapWithTtl(profileJson)));
  }

  Map<String, dynamic>? getCachedProfile(String userId) {
    if (_profile == null) return null;
    final raw = _profile!.get(userId) as String?;
    final data = _unwrapWithTtl(raw);
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  // ── Vitals ────────────────────────────────────────────────────────────

  Future<void> cacheVitals(String userId, List<Map<String, dynamic>> vitals) async {
    if (_vitals == null) return;
    await _vitals!.put(userId, jsonEncode(_wrapWithTtl(vitals)));
  }

  List<Map<String, dynamic>> getCachedVitals(String userId) {
    if (_vitals == null) return [];
    final raw = _vitals!.get(userId) as String?;
    final data = _unwrapWithTtl(raw);
    if (data is List) {
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
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
  ///
  /// FIX (audit H-11): also clear pending triage requests. The previous code
  /// deliberately preserved them ("those should still be submitted"), but on
  /// sign-out this leaks the previous user's symptom data — if user B signs
  /// in on the same device, the pending triage from user A would be submitted
  /// under user B's account.
  Future<void> clearAll(String userId) async {
    await clearPassport(userId);
    if (_symptomLogs != null) await _symptomLogs!.delete(userId);
    if (_profile != null) await _profile!.delete(userId);
    if (_vitals != null) await _vitals!.delete(userId);
    // CRITICAL FIX: clear ALL pending triage entries (they're keyed by
    // entry-id, not by userId, so delete(userId) was a no-op).
    if (_pendingTriage != null) await _pendingTriage!.clear();
    debugPrint('[OfflineCache] Cleared all cached data for user $userId');
  }
}
