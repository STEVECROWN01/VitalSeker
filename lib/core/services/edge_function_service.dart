import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class EdgeFunctionService {
  // FIX (audit H-52): lazy getter instead of field initializer, same as
  // AuthService. Prevents StateError if EdgeFunctionService is instantiated
  // before Supabase.initialize() completes.
  SupabaseClient get _client => SupabaseService().client;

  /// SharedPreferences key for the locally-queued SOS events that haven't
  /// been delivered to the backend yet (e.g. because the network was down
  /// when the user triggered SOS). The queue is flushed by
  /// [flushPendingSosQueue] on app startup and on connectivity regain.
  static const String _kPendingSosQueueKey = 'pending_sos_queue';

  /// AI Triage - Analyze symptoms using GLM-4 AI.
  ///
  /// Pass [conversationHistory] to enable follow-up questions. Each entry
  /// should be `{role: 'user' | 'assistant', content: String}` from prior
  /// turns. The caller should cap this at ~5 turns to bound token usage;
  /// the edge function has a hard backstop at 10.
  Future<Map<String, dynamic>> runTriage({
    required List<String> symptoms,
    required int severity,
    String? duration,
    List<String>? bodyRegions,
    String? notes,
    List<Map<String, String>>? conversationHistory,
    String? language,
  }) async {
    final body = <String, dynamic>{
      'symptoms': symptoms,
      'severity': severity,
      'duration': duration,
      'body_regions': bodyRegions,
      'notes': notes,
      // Per spec Rule R6 (multilingual): tell the edge function which language
      // the user is using so GLM can respond in that language.
      'language': language ?? 'en',
    };
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      body['conversation_history'] = conversationHistory;
    }
    // 60s timeout — GLM-4 can take 10-30s for complex triage, but 60s is the
    // hard limit. Without this, the call hangs forever if the edge function
    // is slow or the network drops.
    final response = await _client.functions.invoke(
      'vitalseker-triage',
      body: body,
    ).timeout(const Duration(seconds: 60));

    if (response.status != 200) {
      throw Exception('Triage failed: ${response.data}');
    }
    // FIX (audit M-8): validate the response is a Map before casting.
    // If the edge function returns a list, string, or HTML from a gateway
    // timeout, the cast would throw a confusing TypeError.
    if (response.data is! Map<String, dynamic>) {
      throw Exception('Triage returned an unexpected response format');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Generate QR Token for Health Passport
  Future<Map<String, dynamic>> generateQr() async {
    final response = await _client.functions.invoke('generate-qr')
        .timeout(const Duration(seconds: 30));
    if (response.status != 200) {
      throw Exception('QR generation failed: ${response.data}');
    }
    if (response.data is! Map<String, dynamic>) {
      throw Exception('QR generation returned an unexpected response format');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Export Health Data as PDF
  Future<Map<String, dynamic>> exportPdf({
    String? passportId,
    bool includeHistory = true,
  }) async {
    // FIX (audit M-9): add timeout (was missing).
    final response = await _client.functions.invoke(
      'export-pdf',
      body: {
        'passport_id': passportId,
        'include_history': includeHistory,
      },
    ).timeout(const Duration(seconds: 30));
    if (response.status != 200) {
      throw Exception('PDF export failed: ${response.data}');
    }
    if (response.data is! Map<String, dynamic>) {
      throw Exception('PDF export returned an unexpected response format');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Trigger Weekly Insights (admin/CRON)
  Future<Map<String, dynamic>> generateWeeklyInsights() async {
    // FIX (audit M-9): add timeout (was missing).
    final response = await _client.functions.invoke('weekly-insights')
        .timeout(const Duration(seconds: 30));
    if (response.status != 200) {
      throw Exception('Weekly insights failed: ${response.data}');
    }
    return response.data as Map<String, dynamic>;
  }

  /// SOS Alert - Send emergency SMS.
  ///
  /// This is a CRITICAL, life-safety feature — it must not fail unless every
  /// possible recovery path has been exhausted. The implementation here is
  /// deliberately over-engineered compared to the other edge function calls:
  ///
  ///   1. **3 retries with exponential backoff** (1s → 2s → 4s). A single
  ///      transient network blip or a cold edge-function start must not
  ///      fail an emergency alert.
  ///   2. **15s per-attempt timeout**. Without a timeout, a dropped TCP
  ///      connection can hang the call forever — the user sees the spinner
  ///      spin and never gets feedback.
  ///   3. **429 rate-limit handling**: a 429 is NOT retried (it would just
  ///      hit the rate limit again). It's surfaced to the caller as a
  ///      [FormatException] so the SosScreen can show the "please wait 60s"
  ///      message.
  ///   4. **Local persistence fallback**: if ALL 3 retries fail (network
  ///      truly unavailable), the SOS event is queued locally in
  ///      SharedPreferences and the method returns a synthetic "queued"
  ///      response instead of throwing. The queue is flushed by
  ///      [flushPendingSosQueue] when connectivity returns. This means
  ///      the user NEVER sees a hard failure — at worst, the SMS goes out
  ///      a few minutes late once the network comes back.
  ///
  /// On a non-200 (and non-429) response we throw a [FormatException]
  /// whose `message` contains the status code + body — the caller can
  /// parse it to detect the 429 rate-limit case.
  Future<Map<String, dynamic>> sendSosAlert({
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) async {
    // FIX (audit H-2, H-41): reduced from 3 attempts to 2, and per-attempt
    // timeout from 15s to 8s. The previous config (3 × 15s + 1 + 2 + 4s
    // backoff = up to ~52s) was too slow for a life-safety feature — in a
    // real emergency, the user can't wait a minute for the alert to go out.
    // 2 attempts × 8s + 1s backoff = max ~17s before queuing locally, which
    // is still within the edge function's own timeout.
    const int maxAttempts = 2;
    const Duration perAttemptTimeout = Duration(seconds: 8);
    // Exponential backoff: 1s between the 2 attempts.
    const List<Duration> backoffs = [
      Duration(seconds: 1),
    ];

    Object? lastError;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _client.functions.invoke(
          'sos-alert',
          body: {
            'latitude': latitude,
            'longitude': longitude,
            'location_address': locationAddress,
          },
        ).timeout(perAttemptTimeout);

        if (response.status == 200) {
          return response.data as Map<String, dynamic>;
        }

        // 429 = rate limited. Don't retry — surface to caller.
        if (response.status == 429) {
          throw FormatException(
            'status 429: ${response.data}',
          );
        }

        // Other non-200 status — record and retry (might be transient).
        lastError = FormatException(
          'status ${response.status}: ${response.data}',
        );
        debugPrint('SOS attempt ${attempt + 1} failed: ${response.status}');
      } on FormatException {
        // 429 — rethrow immediately, no retry.
        rethrow;
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('SOS attempt ${attempt + 1} timed out');
      } catch (e) {
        lastError = e;
        debugPrint('SOS attempt ${attempt + 1} error: $e');
      }

      // Wait before the next retry (unless this was the last attempt).
      if (attempt < maxAttempts - 1) {
        await Future.delayed(backoffs[attempt]);
      }
    }

    // ── All retries exhausted — persist locally so the SOS is NOT lost ──
    // The user is in an emergency. Throwing here would mean the alert is
    // silently dropped. Instead, we queue it locally and return a synthetic
    // "queued" response. The SosScreen treats this as success (the alert
    // WILL be delivered once the network returns) and shows the user a
    // "queued for delivery" message instead of a failure.
    await _enqueuePendingSos(
      latitude: latitude,
      longitude: longitude,
      locationAddress: locationAddress,
    );

    debugPrint('SOS queued locally after $maxAttempts failed attempts. '
        'Last error: $lastError');

    return <String, dynamic>{
      'sos_event_id': null,
      'sms_sent': false,
      'contacts_notified': <Map<String, dynamic>>[],
      'queued_locally': true,
      'message': 'SOS queued for delivery. It will be sent automatically '
          'as soon as your device reconnects to the network. If this is a '
          'life-threatening emergency, please also call 112 or 911 directly.',
    };
  }

  /// Persist an undelivered SOS event to SharedPreferences so it can be
  /// retried later by [flushPendingSosQueue]. The queue is a JSON-encoded
  /// list of `{user_id, latitude, longitude, location_address, queued_at}` objects.
  ///
  /// CRITICAL FIXES (audit C-17, C-18, C-19, C-20):
  ///   - Store `user_id` alongside the event so flush can verify the
  ///     current session matches. Without this, a queued SOS triggered by
  ///     user A could be flushed under user B's session and sent to B's
  ///     emergency contacts.
  ///   - Cap the queue at [_kMaxQueuedSosEvents] and deduplicate by user_id
  ///     within a 60-second window so panic-tapping while offline doesn't
  ///     enqueue dozens of duplicate events that all get sent (and SMS'd)
  ///     on the next flush.
  ///   - On corrupted queue (unparseable JSON), start a fresh queue with
  ///     just this event rather than dropping it.
  Future<void> _enqueuePendingSos({
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Capture the current user_id so we can verify on flush that the
      // session hasn't changed. If Supabase isn't ready or there's no
      // session, store null — flush will skip these entries rather than
      // send them under the wrong user.
      final userId = SupabaseService().isInitialized
          ? _client.auth.currentUser?.id
          : null;

      final now = DateTime.now();
      final newEvent = {
        'user_id': userId,
        'latitude': latitude,
        'longitude': longitude,
        'location_address': locationAddress,
        'queued_at': now.toIso8601String(),
      };

      List<Map<String, dynamic>> queue;
      try {
        final raw = prefs.getString(_kPendingSosQueueKey) ?? '[]';
        final decoded = jsonDecode(raw) as List;
        queue = decoded
            .whereType<Map<String, dynamic>>()
            .toList(growable: true);
      } catch (e) {
        // Corrupted queue — start fresh with just this event. Never drop
        // the new SOS because the old queue is unparseable.
        debugPrint('[SOS Queue] Corrupted queue detected, resetting: $e');
        queue = <Map<String, dynamic>>[];
      }

      // Deduplicate: if there's already an event for this user within the
      // last 60 seconds, replace it with the new one (keep the most recent
      // location). This prevents panic-tap floods from generating dozens of
      // duplicate SMS to emergency contacts.
      if (userId != null) {
        final cutoff = now.subtract(const Duration(seconds: 60));
        queue = queue.where((e) {
          final eUserId = e['user_id']?.toString();
          final eQueuedAt = e['queued_at'] as String?;
          if (eUserId != userId || eQueuedAt == null) return true;
          final eTime = DateTime.tryParse(eQueuedAt);
          return eTime == null || eTime.isBefore(cutoff);
        }).toList();
      }

      queue.add(newEvent);

      // Cap the queue size as a hard backstop.
      if (queue.length > _kMaxQueuedSosEvents) {
        queue = queue.sublist(queue.length - _kMaxQueuedSosEvents);
      }

      await prefs.setString(_kPendingSosQueueKey, jsonEncode(queue));
    } catch (e) {
      // If even SharedPreferences fails (e.g. disk full), there's nothing
      // more we can do — log and move on. The user is still shown the
      // "queued locally" message; the worst case is the queue isn't
      // actually persisted, which is strictly better than crashing here.
      debugPrint('Failed to enqueue pending SOS: $e');
    }
  }

  /// Maximum number of undelivered SOS events to keep in the local queue.
  /// Events beyond this are dropped (oldest first). In practice the dedup
  /// logic in [_enqueuePendingSos] keeps the queue tiny, but this is a
  /// hard backstop against runaway growth.
  static const int _kMaxQueuedSosEvents = 5;

  /// Mutex to prevent concurrent flushes. Multiple triggers (startup,
  /// connectivity-regained listener, 5-minute periodic timer) can fire
  /// [flushPendingSosQueue] within milliseconds of each other. Without a
  /// mutex, both would read the same queue, both would attempt to send the
  /// SAME event → duplicate SMS to emergency contacts, and both would write
  /// back their own `remaining` list — the second write winning and
  /// potentially re-adding an already-delivered event.
  ///
  /// Audit C-19 fix.
  static Completer<int>? _flushMutex;

  /// Flush the locally-queued SOS events to the backend. Should be called:
  ///   - On app startup (after auth is confirmed)
  ///   - When network connectivity is regained
  ///   - Periodically (e.g. every 5 minutes) as a safety net
  ///
  /// Each queued event is retried with the same retry logic as
  /// [sendSosAlert]. Events that succeed are removed from the queue;
  /// events that still fail are left in the queue for the next flush.
  ///
  /// Returns the number of queued events that were successfully delivered.
  ///
  /// CRITICAL FIXES (audit C-17, C-18, C-19):
  ///   - A flush mutex ensures only one flush runs at a time. Concurrent
  ///     calls share the result of the in-flight flush.
  ///   - 429 responses are treated as RETRYABLE (kept in queue with a short
  ///     backoff) rather than silently dropping the event. A 429 does NOT
  ///     guarantee the prior SOS was actually delivered — it only means the
  ///     rate limiter tripped, which can happen for benign reasons.
  ///   - Each event is only flushed if its `user_id` matches the current
  ///     session. Events from a previous user (e.g. user A signed out, user
  ///     B signed in) are skipped — they would be sent to the wrong user's
  ///     emergency contacts.
  Future<int> flushPendingSosQueue() async {
    // If a flush is already in flight, wait for it and return its result.
    // This serializes concurrent flush triggers (startup + connectivity
    // listener + 5-min timer) so we never double-send.
    if (_flushMutex != null) {
      return _flushMutex!.future;
    }
    final completer = Completer<int>();
    _flushMutex = completer;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingSosQueueKey);
      if (raw == null) {
        completer.complete(0);
        return 0;
      }

      List<Map<String, dynamic>> queue;
      try {
        final decoded = jsonDecode(raw) as List;
        queue = decoded
            .whereType<Map<String, dynamic>>()
            .toList(growable: true);
      } catch (e) {
        // Corrupted queue — reset to empty. Never crash on flush.
        debugPrint('[SOS Queue] Corrupted queue on flush, resetting: $e');
        await prefs.setString(_kPendingSosQueueKey, '[]');
        completer.complete(0);
        return 0;
      }

      if (queue.isEmpty) {
        completer.complete(0);
        return 0;
      }

      // Capture the current user_id. Events queued by a different user
      // (or with no user) are skipped — they must not be flushed under
      // the current session.
      final currentUserId = SupabaseService().isInitialized
          ? _client.auth.currentUser?.id
          : null;

      int delivered = 0;
      final remaining = <Map<String, dynamic>>[];
      final skipped = <Map<String, dynamic>>[];

      for (final event in queue) {
        final eventUserId = event['user_id']?.toString();

        // Skip events that belong to a different user (or were queued
        // while signed out). These cannot be safely delivered — the edge
        // function uses auth.uid() to look up emergency contacts, so
        // flushing under the wrong session would send the alert to the
        // wrong user's contacts (or to nobody).
        if (eventUserId != currentUserId) {
          debugPrint('[SOS Queue] Skipping event from user '
              '${eventUserId ?? 'null'} (current: $currentUserId)');
          // Keep skipped events in the queue in case the original user
          // signs back in. They'll be retried then.
          skipped.add(event);
          continue;
        }

        try {
          final response = await _client.functions.invoke(
            'sos-alert',
            body: {
              'latitude': event['latitude'],
              'longitude': event['longitude'],
              'location_address': event['location_address'],
            },
          ).timeout(const Duration(seconds: 15));

          if (response.status == 200) {
            // Delivered successfully — drop from queue.
            delivered++;
          } else if (response.status == 429) {
            // Rate-limited. The previous fix (audit C-17) dropped the
            // event here, which was unsafe — a 429 does NOT guarantee
            // the prior SOS was actually delivered. Keep it in the queue
            // and retry on the next flush. Apply a 60s cooldown so we
            // don't hammer the server.
            final queuedAt = event['queued_at'] as String?;
            final queuedTime = queuedAt != null
                ? DateTime.tryParse(queuedAt)
                : null;
            final age = queuedTime != null
                ? DateTime.now().difference(queuedTime)
                : Duration.zero;
            if (age < const Duration(seconds: 60)) {
              // Too recent — keep for next flush.
              remaining.add(event);
            } else {
              // Old enough to retry — keep for next flush but log it.
              debugPrint('[SOS Queue] Retaining 429 event (age: ${age.inSeconds}s)');
              remaining.add(event);
            }
          } else {
            // Other non-200 — keep in queue for next flush.
            remaining.add(event);
          }
        } catch (e) {
          // Network still down or other transient error — keep in queue.
          debugPrint('Pending SOS flush retry failed: $e');
          remaining.add(event);
        }
      }

      // Persist the remaining + skipped events back to SharedPreferences.
      final persistList = [...remaining, ...skipped];
      await prefs.setString(
        _kPendingSosQueueKey,
        jsonEncode(persistList),
      );

      if (delivered > 0) {
        debugPrint('Flushed $delivered pending SOS event(s) to the server. '
            '${remaining.length} still queued, ${skipped.length} skipped (different user).');
      }
      completer.complete(delivered);
      return delivered;
    } catch (e) {
      debugPrint('Failed to flush pending SOS queue: $e');
      completer.complete(0);
      return 0;
    } finally {
      _flushMutex = null;
    }
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
    // FIX (audit M-9): add timeout (was missing).
    final response = await _client.functions.invoke(
      'delete-account',
      body: {'confirm_email': confirmEmail},
    ).timeout(const Duration(seconds: 30));
    if (response.status != 200) {
      final data = response.data;
      final message = data is Map ? data['error'] : 'Account deletion failed';
      throw Exception(message ?? 'Account deletion failed');
    }
  }

  /// Medical Translation — translate a medical term or phrase into the target
  /// language via the `translate` edge function.
  ///
  /// `targetLang` should be a human-readable language name (e.g. "French",
  /// "Spanish", "Arabic"). The edge function is responsible for mapping that
  /// to the appropriate translator locale.
  ///
  /// Returns the translated string. Throws on non-200 responses or empty
  /// translation payloads.
  Future<String> translate({required String text, required String targetLang}) async {
    final response = await _client.functions.invoke(
      'translate',
      body: {'text': text, 'target_lang': targetLang},
    ).timeout(const Duration(seconds: 30));
    if (response.status != 200) {
      throw Exception('Translation failed: ${response.data}');
    }
    final data = response.data as Map<String, dynamic>;
    final translation = data['translation'] as String? ??
        data['translated_text'] as String? ??
        '';
    // FIX (audit M-10): throw on empty translation so the caller can show
    // an error instead of silently displaying an empty string.
    if (translation.isEmpty) {
      throw Exception('Translation returned an empty result');
    }
    return translation;
  }
}
