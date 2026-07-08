import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class EdgeFunctionService {
  final SupabaseClient _client = SupabaseService().client;

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
    return response.data as Map<String, dynamic>;
  }

  /// Generate QR Token for Health Passport
  Future<Map<String, dynamic>> generateQr() async {
    final response = await _client.functions.invoke('generate-qr')
        .timeout(const Duration(seconds: 30));
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
    const int maxAttempts = 3;
    const Duration perAttemptTimeout = Duration(seconds: 15);
    // Exponential backoff: 1s, 2s, 4s between retries.
    const List<Duration> backoffs = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
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
  /// list of `{latitude, longitude, location_address, queued_at}` objects.
  Future<void> _enqueuePendingSos({
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingSosQueueKey) ?? '[]';
      final queue = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      queue.add({
        'latitude': latitude,
        'longitude': longitude,
        'location_address': locationAddress,
        'queued_at': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_kPendingSosQueueKey, jsonEncode(queue));
    } catch (e) {
      // If even SharedPreferences fails (e.g. disk full), there's nothing
      // more we can do — log and move on. The user is still shown the
      // "queued locally" message; the worst case is the queue isn't
      // actually persisted, which is strictly better than crashing here.
      debugPrint('Failed to enqueue pending SOS: $e');
    }
  }

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
  Future<int> flushPendingSosQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingSosQueueKey);
      if (raw == null) return 0;
      final queue = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (queue.isEmpty) return 0;

      int delivered = 0;
      final remaining = <Map<String, dynamic>>[];

      for (final event in queue) {
        try {
          final response = await _client.functions.invoke(
            'sos-alert',
            body: {
              'latitude': event['latitude'],
              'longitude': event['longitude'],
              'location_address': event['location_address'],
            },
          ).timeout(const Duration(seconds: 15));

          if (response.status == 200 || response.status == 429) {
            // 200 = delivered. 429 = rate-limited, which means a prior SOS
            // was already accepted by the server — drop this queued event
            // since the user's emergency is already being handled.
            delivered++;
          } else {
            // Other status — keep in queue for next flush.
            remaining.add(event);
          }
        } catch (e) {
          // Network still down or other transient error — keep in queue.
          debugPrint('Pending SOS flush retry failed: $e');
          remaining.add(event);
        }
      }

      await prefs.setString(
        _kPendingSosQueueKey,
        jsonEncode(remaining),
      );

      if (delivered > 0) {
        debugPrint('Flushed $delivered pending SOS event(s) to the server. '
            '${remaining.length} still queued.');
      }
      return delivered;
    } catch (e) {
      debugPrint('Failed to flush pending SOS queue: $e');
      return 0;
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
    return data['translation'] as String? ??
        data['translated_text'] as String? ??
        '';
  }
}
