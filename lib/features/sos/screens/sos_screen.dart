import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with TickerProviderStateMixin {
  bool _isSending = false;
  bool _sosActive = false;
  String? _sosMessage;
  Map<String, dynamic>? _sosResult;
  // Live GPS coordinates obtained during the SOS trigger — shown in the
  // active state contact card so the user can see what was shared.
  String? _locationText;
  // True while _shareLocation is acquiring GPS and preparing the share sheet.
  // Guards against re-entrancy (user re-tapping the button during the 7-12s
  // GPS acquisition window) and drives a spinner + disabled state on the
  // button so the user gets immediate visual feedback that their tap was
  // registered. Without this, the button stayed enabled and showed no
  // progress while GPS was being acquired, so users re-tapped — stacking
  // multiple _getCurrentLocation calls and seeing the first call's late-
  // arriving timeout error appear "in response to" the second tap.
  bool _isLocating = false;
  // True when the most recent SOS attempt was rejected by the edge
  // function's 60-second rate limit. Drives a different failure message
  // ("please wait 60s") instead of the generic "delivery failed".
  bool _sosRateLimited = false;

  /// True while the alert is being sent OR after it has been sent (before the
  /// user resolves it). Drives the full-screen red gradient + active UI.
  bool get _isActiveState => _isSending || _sosActive;

  // Pulse animation — subtle breathing of the SOS button.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // SOS ripple — 3 concentric expanding rings per the animation spec:
  // 2s loop, scale 1.0→1.8, opacity 0.6→0, curve cubic-bezier(0, 0, 0.2, 1)
  // (approximated with Curves.easeOutCubic). Rings are staggered by 0.66s
  // so they emanate continuously from the button centre.
  static const int _kRippleCount = 3;
  static const Duration _rippleDuration = Duration(milliseconds: 2000);
  static const List<Duration> _rippleDelays = [
    Duration.zero,
    Duration(milliseconds: 666),
    Duration(milliseconds: 1333),
  ];
  final List<AnimationController> _rippleControllers = [];
  final List<Animation<double>> _rippleScales = [];
  final List<Animation<double>> _rippleOpacities = [];

  // Countdown for the "Sending in N…" headline during the sending state.
  Timer? _countdownTimer;
  int _countdownSeconds = _kCountdownFrom;
  static const int _kCountdownFrom = 5;

  // Hold-to-trigger SOS state. The UI hint says "Hold for 3 seconds" so we
  // honour that with a real 3-second hold timer + a progress ring.
  static const Duration _sosHoldDuration = Duration(seconds: 3);
  late final AnimationController _holdController;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Build the 3 staggered ripple controllers. Each ring scales 1.0→1.8 and
    // fades 0.6→0 over 2s; staggered starts (0s, 0.66s, 1.33s) produce a
    // continuous emanating ripple around the SOS button.
    for (int i = 0; i < _kRippleCount; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: _rippleDuration,
      );
      final curved = CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      );
      _rippleControllers.add(controller);
      _rippleScales.add(
        Tween<double>(begin: 1.0, end: 1.8).animate(curved),
      );
      _rippleOpacities.add(
        Tween<double>(begin: 0.6, end: 0.0).animate(curved),
      );
    }
    // Stagger the start of each ring so they emanate continuously.
    for (int i = 0; i < _kRippleCount; i++) {
      Future.delayed(_rippleDelays[i], () {
        if (mounted) _rippleControllers[i].repeat();
      });
    }

    _holdController = AnimationController(
      vsync: this,
      duration: _sosHoldDuration,
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isHolding) {
        _isHolding = false;
        _confirmAndTriggerSos();
      }
    });

    // CRITICAL FIX: restore active SOS state if the user reopens the app
    // with an unresolved SOS event from a previous session. Without this,
    // the user sees the idle SOS button and has no way to resolve the
    // prior alert — their emergency contacts receive no cancellation
    // signal, and the 60s rate limit blocks new SOS triggers.
    _restoreActiveSosState();
  }

  /// Queries the most recent unresolved SOS event for the current user.
  /// If found and < 1 hour old, restores the active SOS UI so the user
  /// can resolve it.
  Future<void> _restoreActiveSosState() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final db = ref.read(databaseServiceProvider);
      final events = await db.getSosEvents(user.id);
      if (events.isEmpty) return;
      // The query returns events ordered by created_at DESC, so the first
      // is the most recent.
      final latest = events.first;
      // Only restore if the event is unresolved AND less than 1 hour old.
      // Events older than 1 hour are almost certainly for emergencies
      // that are long over — showing the active UI would be confusing.
      if (latest.resolved) return;
      final age = DateTime.now().difference(latest.createdAt);
      if (age > const Duration(hours: 1)) return;

      if (!mounted) return;
      // Restore the active state.
      final locationText = (latest.latitude != null && latest.longitude != null)
          ? '${latest.latitude!.toStringAsFixed(4)}, ${latest.longitude!.toStringAsFixed(4)}'
          : null;
      setState(() {
        _sosActive = true;
        _sosResult = {
          'sos_event_id': latest.id,
          'sms_sent': latest.smsSent,
          'contacts_notified': latest.contactsNotified
              .map((c) => {'name': c.name, 'phone': c.phone, 'status': c.status})
              .toList(),
          'queued_locally': false,
          'message': latest.smsSent
              ? 'Emergency alert sent to ${latest.contactsNotified.where((c) => c.status == 'sent').length} contact(s)'
              : 'SOS event recorded. SMS not sent - check emergency contacts setup.',
        };
        _locationText = locationText;
        _sosMessage = latest.smsSent
            ? null
            : 'SOS event recorded. SMS not sent - check emergency contacts setup.';
      });
      debugPrint('[SOS] restored active state for unresolved event ${latest.id} '
          '(age: ${age.inMinutes}min)');
    } catch (e) {
      debugPrint('[SOS] _restoreActiveSosState failed (non-fatal): $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    for (final c in _rippleControllers) {
      c.dispose();
    }
    _holdController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (_isSending || _sosActive) return;
    setState(() => _isHolding = true);
    HapticFeedback.selectionClick();
    _holdController.forward(from: 0.0);
  }

  void _cancelHold() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    _holdController.stop();
    _holdController.reset();
  }

  Future<void> _confirmAndTriggerSos() async {
    // Confirmation dialog — prevents accidental triggers from a completed
    // 3-second hold (e.g. phone in pocket).
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sendEmergencySOS),
        content: Text(l10n.sosMessageBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.urgencyEmergency,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.sendSOS),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _triggerSos();
    } else {
      // Reset hold state if user backed out.
      _holdController.reset();
    }
  }

  /// Acquire the user's current GPS position.
  ///
  /// Robustly handles every failure mode that previously surfaced as a
  /// generic "Could not get current location" message:
  ///   1. Location services (GPS) disabled — opens the system location
  ///      settings so the user can enable them.
  ///   2. Permission denied — calls [Geolocator.requestPermission] first.
  ///   3. Permission denied forever — prompts the user to open app settings.
  ///   4. GPS acquisition takes too long — a 10s [timeLimit] is set so the
  ///      caller doesn't hang forever waiting for a fix.
  ///
  /// [silent] suppresses the error snackbars AND the system-settings
  /// redirects — used by [_triggerSos] so that GPS failures during an
  /// emergency don't open the location-settings screen or stack a location
  /// snackbar on top of the SOS failure snackbar. The SOS flow handles the
  /// "no location" case itself by sending the alert without coordinates.
  ///
  /// Returns the [Position] on success, or `null` on any failure (with a
  /// contextual snackbar shown to the user via [AppSnackBar] when [silent]
  /// is false).
  Future<Position?> _getCurrentLocation({bool silent = false}) async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are off — offer to open the system settings so
        // the user can enable GPS. This is the most common cause of the old
        // "Could not get current location" message.
        if (!silent && mounted) {
          AppSnackBar.error(
            context,
            'Location services are disabled. Please enable GPS in your device settings.',
          );
          // Best-effort attempt to open the system location settings so the
          // user can flip the switch without leaving the flow. The user comes
          // back to the app after enabling.
          try {
            await Geolocator.openLocationSettings();
          } catch (_) {
            // openLocationSettings may not be implemented on every platform —
            // the snackbar above already told the user what to do.
          }
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Explicitly request permission here. This is the call that was
        // sometimes failing silently — calling it on the user gesture (the
        // "Share My Location" / "Find Hospitals" tap) instead of proactively
        // in initState gives Android the in-context permission dialog it
        // expects.
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (!silent && mounted) {
            AppSnackBar.error(
              context,
              'Location permission denied. Please grant location access in your device settings.',
            );
          }
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        // The user previously selected "Deny forever" — the OS won't show
        // the permission dialog again, so we have to send them to app
        // settings.
        if (!silent && mounted) {
          AppSnackBar.error(
            context,
            'Location permission is permanently denied. Please enable it in your app settings to use this feature.',
          );
          try {
            await Geolocator.openAppSettings();
          } catch (_) {}
        }
        return null;
      }

      // FAST PATH: try the last-known position first. On a cold GPS (e.g.
      // indoors, or the user just opened the app), `getCurrentPosition` can
      // take 7-15s for a high-accuracy fix — but `getLastKnownPosition`
      // returns instantly from the OS's cache. For SOS purposes, a 1-5
      // minute-old fix is more than accurate enough (emergency responders
      // don't need sub-meter precision; they need to know which block you're
      // on). This was the missing piece that caused "Location unavailable"
      // during the 3-second outer SOS-timeout window.
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          final age = DateTime.now().difference(lastKnown.timestamp);
          if (age < const Duration(minutes: 5)) {
            debugPrint('[SOS] using last-known position (age: ${age.inSeconds}s)');
            return lastKnown;
          }
        }
      } catch (e) {
        debugPrint('[SOS] getLastKnownPosition failed (non-fatal): $e');
        // Continue to the live getCurrentPosition call below.
      }

      // Use a 7s time limit for high accuracy. If it times out (common
      // indoors), fall back to low accuracy with another 5s. This two-stage
      // approach dramatically reduces "Could not get a GPS fix" failures.
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 7),
        );
      } on TimeoutException {
        // High accuracy timed out — try low accuracy (network/cell tower)
        try {
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
        } on TimeoutException {
          if (!silent && mounted) {
            AppSnackBar.error(
              context,
              'Could not get a GPS fix. Please try again outdoors or near a window.',
            );
          }
          return null;
        }
      }
    } catch (e) {
      debugPrint('_getCurrentLocation error: $e');
      if (!silent && mounted) {
        AppSnackBar.errorFromException(
          context,
          'Could not get current location. Please check location permissions.',
          e,
        );
      }
      return null;
    }
  }

  Future<void> _triggerSos({bool overrideRateLimit = false}) async {
    final l10n = AppLocalizations.of(context)!;
    // Haptic feedback
    HapticFeedback.heavyImpact();

    setState(() {
      _isSending = true;
      _sosMessage = l10n.acquiringGps;
      _locationText = null;
      // Reset prior failure flag so the UI doesn't briefly render the old
      // failure state while we re-attempt.
      _sosRateLimited = false;
    });

    _startCountdown();

    try {
      final edgeService = EdgeFunctionService();

      // ── Step 1: Acquire GPS FIRST (with a 10s timeout) ──
      //
      // FIX (regression from audit H-39): the previous 3s outer timeout was
      // shorter than the inner GPS timeLimit (7s high-accuracy). It fired
      // before any real fix could arrive, guaranteeing `position == null`
      // and "Location unavailable" in the active-state card. 3s was only
      // enough for an instantaneous cached fix, which `_getCurrentLocation`
      // now provides via `getLastKnownPosition` (fast path) — so the cold-
      // start case needs a longer outer timeout.
      //
      // 10s gives the inner 7s high-accuracy call room to complete, plus
      // a 3s buffer for the OS to grant permission / wake the GPS radio.
      // If GPS still hasn't returned after 10s, we send the SOS without
      // location rather than delaying further.
      //
      // `silent: true` suppresses the location-error snackbars and the
      // system-settings redirects that would otherwise fire when GPS is
      // unavailable — during an emergency we don't want to yank the user
      // out of the SOS flow into the location-settings screen, and we
      // don't want a "GPS disabled" snackbar stacking on top of the SOS
      // failure snackbar.
      Position? position;
      try {
        position = await _getCurrentLocation(silent: true).timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint('GPS acquisition failed (non-fatal): $e');
        // Don't propagate — we still want to send the SOS without location.
      }

      // Update display with whatever we got (null is fine).
      final locationText = position != null
          ? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
          : null;
      if (locationText != null) {
        setState(() => _locationText = locationText);
      }

      // ── Step 2: Send the SOS alert WITH actual coordinates ──
      setState(() {
        _sosMessage = position != null
            ? l10n.sendingWithLocation
            : l10n.sendingNoGps;
      });

      final result = await edgeService.sendSosAlert(
        latitude: position?.latitude,
        longitude: position?.longitude,
        locationAddress: null,
        overrideRateLimit: overrideRateLimit,
      );

      // ── Step 3: Handle the response ──
      // The edge function returns 200 with `sms_sent: true|false`. Even if
      // no SMS was sent (e.g. user has no emergency contacts configured),
      // the SOS event was still recorded in the database — that's a
      // PARTIAL success, not a hard failure. We surface the actual server
      // message so the user knows exactly what happened.
      setState(() {
        _sosActive = true;
        _sosResult = result;
        _sosMessage = result['message'] as String? ??
            l10n.emergencyAlertSent;
      });

      HapticFeedback.mediumImpact();
    } on FormatException catch (e) {
      // FormatException is what we throw from EdgeFunctionService when the
      // response status is not 200. We parse the body to detect the 429
      // rate-limit case and show a more helpful message.
      final raw = e.message;
      final isRateLimited = raw.contains('429') ||
          raw.toLowerCase().contains('rate limit');
      debugPrint('SOS edge function error: $raw');
      setState(() {
        _sosActive = true;
        _sosResult = null;
        _sosRateLimited = isRateLimited;
        _sosMessage = isRateLimited
            ? l10n.sosRateLimitMessage
            : l10n.sosDeliveryFailedMessage;
      });
      if (mounted) {
        AppSnackBar.error(
          context,
          isRateLimited
              ? l10n.sosRateLimitRetryMessage
              : l10n.sosDeliveryFailedMessage,
        );
      }
      HapticFeedback.heavyImpact();
    } catch (e) {
      // ── Hard failure (network error, edge function 500, etc.) ──
      // Still show the active-state UI so the user sees the failure
      // message + has buttons to retry or call emergency services.
      debugPrint('SOS trigger error: $e');
      setState(() {
        _sosActive = true;
        _sosResult = null;
        _sosMessage =
            l10n.sosDeliveryFailedMessage;
      });
      if (mounted) {
        AppSnackBar.errorFromException(
          context,
          l10n.sosDeliveryFailedMessage,
          e,
        );
      }
      HapticFeedback.heavyImpact();
    } finally {
      _countdownTimer?.cancel();
      setState(() => _isSending = false);
    }
  }

  /// Start the 5-second "Sending in N…" countdown shown while the alert is
  /// being dispatched. The countdown is purely visual — the actual send
  /// completes asynchronously via [EdgeFunctionService.sendSosAlert].
  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = _kCountdownFrom);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 1) {
          _countdownSeconds--;
        } else {
          // Hold at 1 — the actual send completes asynchronously.
          timer.cancel();
        }
      });
    });
  }

  /// Confirm and override the rate limit to resend the SOS.
  ///
  /// FIX (audit H-5): the 60s rate limit is a spam guard, not a safety
  /// guard. If the user has a NEW emergency within 60s of the previous SOS,
  /// blocking the alert is dangerous. This method shows a strong warning
  /// confirmation dialog, then re-triggers the SOS flow. The server-side
  /// rate limit may still reject the request, but at least the user has
  /// the option to try.
  Future<void> _confirmOverrideAndResend() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.overrideRateLimitTitle),
        content: const Text(
          'You sent an SOS less than 60 seconds ago. If this is a NEW '
          'emergency (not a repeat of the same one), you can override '
          'the rate limit and send another alert.\n\n'
          'Warning: overriding will send a second SMS to all your '
          'emergency contacts. Only do this if you have a genuinely '
          'new emergency.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.urgencyEmergency,
            ),
            child: Text(l10n.overrideAndSend),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Reset the rate-limit flag and re-trigger the SOS flow.
      setState(() {
        _sosRateLimited = false;
        _sosActive = false;
        _sosResult = null;
      });
      // Pass overrideRateLimit: true so the edge function skips its 60s
      // rate-limit check. The user has explicitly confirmed this is a new
      // emergency. Without this flag, the edge function would return 429
      // again and the user would be trapped (their explicit override did
      // nothing — the user-reported "Override doesn't work" bug).
      _triggerSos(overrideRateLimit: true);
    }
  }

  /// Resolve the active SOS — resets the UI to the initial state.
  ///
  /// FIX (audit H-40): show a confirmation dialog before resolving. The
  /// previous code resolved immediately on tap, which meant an accidental
  /// tap (e.g. while handing the phone to someone) would dismiss the SOS
  /// and emergency contacts might stop responding. The confirmation dialog
  /// requires an explicit "Yes, I'm safe" to proceed.
  ///
  /// CRITICAL FIX (user-reported): previously this method ONLY reset local
  /// UI state. The server's `sos_events` row stayed `resolved = false`,
  /// so emergency contacts who received the SOS SMS got no cancellation
  /// signal, and the next SOS trigger hit the 60s rate limit because the
  /// prior event was still "active" in the DB. Now we call
  /// `EdgeFunctionService.resolveSos()` to mark the event as resolved
  /// server-side BEFORE resetting the local UI state.
  Future<void> _resolveSos() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.imSafeResolve),
        content: Text(
          'Are you safe? Your emergency contacts will be notified that '
          'the alert has been resolved. If you are NOT safe, tap "Cancel" '
          'and call emergency services directly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary(Theme.of(context).brightness == Brightness.dark),
            ),
            child: Text(l10n.yesImSafeButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // Show a resolving state so the user sees feedback while we call the
    // server.
    setState(() {
      _isSending = true;
      _sosMessage = 'Resolving alert…';
    });

    try {
      // Capture the sos_event_id from the result before clearing it.
      final sosEventId = _sosResult?['sos_event_id']?.toString();
      await EdgeFunctionService().resolveSos(sosEventId);
    } catch (e) {
      debugPrint('[SOS] resolveSos failed (non-fatal — resetting UI anyway): $e');
    }

    _countdownTimer?.cancel();
    setState(() {
      _sosActive = false;
      _isSending = false;
      _sosMessage = null;
      _sosResult = null;
      _locationText = null;
      _sosRateLimited = false;
      _countdownSeconds = _kCountdownFrom;
    });
    HapticFeedback.lightImpact();

    // Navigate back to the previous screen (typically the dashboard) so the
    // user isn't left staring at the idle SOS button after resolving.
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotLaunchCall(phoneNumber))),
        );
      }
    }
  }

  Future<void> _sendSms(String phoneNumber) async {
    final uri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareLocation() async {
    // Re-entrancy guard: if a previous tap is still acquiring GPS or sharing,
    // ignore subsequent taps. The button is also disabled in the UI via
    // `_isLocating`, but this guards against the brief window between the
    // tap event firing and setState rebuilding the button as disabled.
    if (_isLocating) return;

    setState(() => _isLocating = true);
    try {
      // Acquire GPS with a hard 9-second outer timeout. The inner
      // _getCurrentLocation has a 7s+5s chain (12s) — but we cap the total
      // at 9s here so the user always sees feedback within a reasonable
      // window. If GPS hasn't returned by then, we show an explicit error
      // instead of leaving the "Getting your location…" snackbar to expire
      // silently 8s later (which was the previous behavior and made the
      // button appear to "hang").
      //
      // silent: true — _getCurrentLocation's own error snackbars would stack
      // on top of our explicit error below, doubling up the failure message.
      Position? position;
      try {
        position = await _getCurrentLocation(silent: true).timeout(
          const Duration(seconds: 9),
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint('[ShareLocation] GPS acquisition error: $e');
      }

      if (position == null) {
        if (mounted) {
          AppSnackBar.error(
            context,
            'Could not get a GPS fix. Please try again outdoors or near a window.',
          );
        }
        return;
      }

      final locationText =
          'My emergency location: https://maps.google.com/?q=${position.latitude},${position.longitude}';
      await Share.share(locationText, subject: 'Emergency Location');
      // Explicit success feedback — the system share sheet opening is the
      // real success signal, but a snackbar confirms it for users who miss
      // the sheet (e.g. it appeared behind another window).
      if (mounted) {
        AppSnackBar.success(
          context,
          'Location ready to share.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(
            context, 'Failed to share location.', e);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Open the native maps app with a "hospitals near me" search centered on
  /// the user's GPS location.
  ///
  /// Two-launch strategy:
  ///   1. Try the `geo:` URI scheme which opens the native maps app
  ///      (Apple Maps on iOS, Google Maps on Android) for an in-app,
  ///      no-network experience.
  ///   2. Fall back to `https://www.google.com/maps/search/hospital…` —
  ///      this opens in the browser (or the Google Maps web app) and works
  ///      on every device even if no maps app is installed. Using
  ///      [LaunchMode.externalApplication] forces the system to hand the
  ///      URL off to the user's preferred browser/maps app instead of
  ///      rendering inside the in-app webview.
  ///
  /// If location permission is denied, we still launch a generic
  /// "hospitals near me" search — the maps app will use its own location.
  Future<void> _findNearbyHospitals() async {
    HapticFeedback.selectionClick();

    // Skip GPS acquisition — the maps app has its own location services
    // which are faster and more reliable than getting a fix from within
    // the app. Using geo:0,0?q=hospital tells the maps app to use the
    // user's current location and search for nearby hospitals.
    final Uri geoUri = Uri.parse('geo:0,0?q=hospital');
    final Uri httpsUri = Uri.parse('https://www.google.com/maps/search/hospital');

    // ── Attempt 1: native maps app via geo: ──
    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('geo: launch failed: $e');
    }

    // ── Attempt 2: https URL — always works (browser or maps web app) ──
    // Skip the canLaunchUrl check for https URLs on Android — package
    // visibility can make it return false even when a browser is installed.
    // Just try to launch and let the OS handle it.
    try {
      final launched =
          await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (e) {
      debugPrint('https maps launch failed: $e');
    }

    // ── Last resort ──
    if (mounted) {
      AppSnackBar.error(
        context,
        'Could not open maps app. Please search "hospital near me" in your browser manually.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.emergencySosTitle),
        backgroundColor: _isActiveState ? const Color(0xFFB8321D) : null,
        foregroundColor: _isActiveState ? Colors.white : null,
      ),
      body: Container(
        // Full-screen red radial gradient (#E53935 → #B8321D) when an SOS
        // alert is sending or active — matches the Google Stitch mockup.
        decoration: _isActiveState
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.4,
                  colors: [Color(0xFFE53935), Color(0xFFB8321D)],
                ),
              )
            : null,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── SOS Button ──
                if (!_isActiveState) ...[
                  Text(
                    l10n.pressAndHold,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: AppColors.textSecondary(isDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildIdleSosButton(),
                  const SizedBox(height: 16),
                  Text(
                    _isHolding ? l10n.keepHolding : l10n.holdFor3Seconds,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight:
                          _isHolding ? FontWeight.w600 : FontWeight.w400,
                      color: _isHolding
                          ? AppColors.urgencyEmergency
                          : AppColors.textHint(isDark),
                    ),
                  ),
                ] else ...[
                  _buildActiveState(),
                ],

                // ── Quick Dial, Share Location, Emergency Contacts ──
                // Only show these in idle state OR successful SOS state.
                // When SOS FAILED, skip them — the user just needs to retry
                // or dismiss. This prevents the layout overflow where the
                // failure banner pushed "Share My Location" off-screen.
                if (!_isActiveState || (_sosActive && _sosResult != null)) ...[
                const SizedBox(height: 32),

                // ── Quick Dial ──
                Row(
                  children: [
                    Icon(Icons.phone_in_talk,
                        color: _isActiveState
                            ? Colors.white
                            : AppColors.primary(isDark),
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.quickDial,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _isActiveState
                            ? Colors.white
                            : AppColors.textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickDialButton(
                        label: '15',
                        subtitle: l10n.samuEmergency,
                        icon: Icons.phone,
                        color: AppColors.urgencyEmergency,
                        isDark: isDark,
                        onTap: () => _makePhoneCall('15'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickDialButton(
                        label: '112',
                        subtitle: l10n.euEmergency,
                        icon: Icons.phone,
                        color: AppColors.urgencyEmergency,
                        isDark: isDark,
                        onTap: () => _makePhoneCall('112'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickDialButton(
                        label: '911',
                        subtitle: l10n.usEmergency,
                        icon: Icons.phone,
                        color: AppColors.urgencyHigh,
                        isDark: isDark,
                        onTap: () => _makePhoneCall('911'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Share Location ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    // Disable the button while GPS is being acquired so the
                    // user gets immediate visual feedback (spinner + greyed
                    // label) and can't fire overlapping _getCurrentLocation
                    // calls. Previously the button stayed enabled for the
                    // entire 12s acquisition window, so users re-tapped and
                    // stacked calls — the first call's late-arriving timeout
                    // error then appeared "in response to" the second tap.
                    onPressed: _isLocating ? null : _shareLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.location_on_outlined, size: 20),
                    label: Text(_isLocating
                        ? 'Getting your location…'
                        : l10n.shareMyLocation),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isActiveState
                          ? Colors.white
                          : AppColors.primary(isDark),
                      side: BorderSide(
                        color: _isActiveState
                            ? Colors.white
                            : AppColors.primary(isDark),
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Emergency Contacts ──
                Row(
                  children: [
                    Icon(Icons.contacts,
                        color: _isActiveState
                            ? Colors.white
                            : AppColors.primary(isDark),
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.emergencyContacts,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _isActiveState
                            ? Colors.white
                            : AppColors.textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                profileAsync.when(
                  data: (profile) {
                    final contacts = profile?.emergencyContacts ?? [];
                    if (contacts.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.subtleBackground(isDark),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.border(isDark),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.person_add_outlined,
                                size: 32,
                                color: AppColors.textHint(isDark)),
                            const SizedBox(height: 8),
                            Text(
                              l10n.noEmergencyContacts,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: AppColors.textSecondary(isDark),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // "Add contacts in your profile settings" — the
                            // entire text is tappable and deep-links to the
                            // Edit Profile screen where the user can manage
                            // their emergency contacts. Rendered as a
                            // GestureDetector-wrapped Text so the whole
                            // phrase is the tap target (per Bug 1 #3).
                            GestureDetector(
                              onTap: () => context.push(AppConfig.editProfile),
                              child: Text(
                                l10n.addContactsInProfile,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.primary(isDark),
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: contacts.map((contact) {
                        return _EmergencyContactCard(
                          contact: contact,
                          isDark: isDark,
                          onCall: () => _makePhoneCall(contact.phone),
                          onText: () => _sendSms(contact.phone),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 28),

                // ── Nearby Hospitals (Placeholder) ──
                Row(
                  children: [
                    Icon(Icons.local_hospital_outlined,
                        color: _isActiveState
                            ? Colors.white
                            : AppColors.primary(isDark),
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.nearbyHospitals,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _isActiveState
                            ? Colors.white
                            : AppColors.textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Hospital finder — opens the native maps app with a
                // "hospitals near me" search centered on the user's GPS
                // location. Works on iOS (Apple Maps) and Android (Google
                // Maps) without requiring an API key. Falls back to a
                // generic search if location is unavailable.
                _HospitalFinderCard(
                  isDark: isDark,
                  onFindHospitals: _findNearbyHospitals,
                ),

                const SizedBox(height: 28),

                // ── Medical ID Summary ──
                Row(
                  children: [
                    Icon(Icons.medical_information_outlined,
                        color: _isActiveState
                            ? Colors.white
                            : AppColors.primary(isDark),
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.medicalIDSection,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _isActiveState
                            ? Colors.white
                            : AppColors.textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                profileAsync.when(
                  data: (profile) {
                    if (profile == null) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(isDark),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border(isDark),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (profile.bloodType != null)
                            _MedicalIdRow(
                              icon: Icons.bloodtype,
                              label: l10n.bloodType,
                              value: profile.bloodType!,
                              color: AppColors.urgencyEmergency,
                              isDark: isDark,
                            ),
                          if (profile.allergies.isNotEmpty)
                            _MedicalIdRow(
                              icon: Icons.warning_amber_rounded,
                              label: l10n.allergies,
                              value: profile.allergies.join(', '),
                              color: AppColors.urgencyMedium,
                              isDark: isDark,
                            ),
                          if (profile.chronicConditions.isNotEmpty)
                            _MedicalIdRow(
                              icon: Icons.medical_information,
                              label: l10n.conditions,
                              value: profile.chronicConditions.join(', '),
                              color: AppColors.urgencyHigh,
                              isDark: isDark,
                            ),
                          if (profile.bloodType == null &&
                              profile.allergies.isEmpty &&
                              profile.chronicConditions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              // Per Bug 1 #4: only the "add medical ID data"
                              // portion is tappable and deep-links to the
                              // Medical ID screen. Implemented with Text.rich
                              // + a WidgetSpan wrapping a GestureDetector so
                              // we don't have to manage a TapGestureRecognizer
                              // lifecycle (which would otherwise leak on
                              // every rebuild of this `.when` callback).
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: AppColors.textSecondary(isDark),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: l10n.noMedicalInfoPrefix,
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: GestureDetector(
                                        onTap: () => context
                                            .push(AppConfig.medicalId),
                                        child: Text(
                                          l10n.addMedicalIdData,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            color: AppColors.primary(isDark),
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor:
                                                AppColors.primary(isDark),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // ── Emergency tip ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.urgencyMedium
                        .withValues(alpha: isDark ? 0.1 : 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            AppColors.urgencyMedium.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.urgencyMedium, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.sosTip,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                ], // end if (Quick Dial + Share Location + Emergency Contacts)
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // SOS button (idle state) — 3 concentric ripple rings stacked behind the
  // actual button. Rings are staggered ScaleTransition + FadeTransition
  // widgets driven by [_rippleControllers].
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildIdleSosButton() {
    return SizedBox(
      width: 360,
      height: 360,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3 concentric ripple rings (spec: 2s loop, scale 1.0→1.8,
          // opacity 0.6→0, curve cubic-bezier(0, 0, 0.2, 1)). Staggered
          // starts (0s, 0.66s, 1.33s) produce a continuous emanating ripple.
          for (int i = 0; i < _kRippleCount; i++)
            FadeTransition(
              opacity: _rippleOpacities[i],
              child: ScaleTransition(
                scale: _rippleScales[i],
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.urgencyEmergency,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),

          // Hold-progress ring (visible only while holding).
          if (_isHolding)
            SizedBox(
              width: 220,
              height: 220,
              child: AnimatedBuilder(
                animation: _holdController,
                builder: (_, __) => CircularProgressIndicator(
                  value: _holdController.value,
                  strokeWidth: 6,
                  color: AppColors.urgencyEmergency,
                  backgroundColor:
                      AppColors.urgencyEmergency.withValues(alpha: 0.15),
                ),
              ),
            ),

          // The SOS button itself with a subtle breathing pulse. Renders on
          // top of the ripple rings.
          ScaleTransition(
            scale: _pulseAnimation,
            child: GestureDetector(
              onLongPressStart: (_) => _startHold(),
              onLongPressEnd: (_) => _cancelHold(),
              onLongPressCancel: _cancelHold,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE53935), Color(0xFFFF5722)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.urgencyEmergency
                          .withValues(alpha: 0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emergency, color: Colors.white, size: 64),
                    SizedBox(height: 8),
                    Text(
                      'SOS',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                duration: 2000.ms,
                color: Colors.white.withValues(alpha: 0.1),
              ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Active / sending state — full-screen red radial gradient (applied on
  // the body Container) + "Sending Emergency Alert" headline + countdown +
  // contact card with live location.
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildActiveState() {
    final l10n = AppLocalizations.of(context)!;
    final smsSent = _sosResult?['sms_sent'] == true;
    // True when the SOS was queued locally (network was unavailable). The
    // alert WILL be delivered automatically once the device reconnects —
    // this is NOT a failure, so we show a distinct "QUEUED" indicator
    // instead of the "SOS ACTIVE" success label.
    final bool queuedLocally = _sosResult?['queued_locally'] == true;
    final contactsNotified = (_sosResult?['contacts_notified'] as List?) ?? [];
    // FIX (audit 12.8): count any non-failure status, not just 'sent'.
    // The edge function may return 'delivered', 'queued', or 'submitted'
    // — those all mean the SMS was accepted by Twilio.
    final sentCount =
        contactsNotified.where((c) {
          final status = c['status'] as String? ?? '';
          return status != 'failed' && status != 'rejected' && status != 'error' && status != 'invalid';
        }).length;
    // Whether the SOS alert actually went out. False in the catch-block path
    // of [_triggerSos] (edge-function error, network failure, etc.) — we
    // still want to render the active state so the user sees the failure
    // message + can dismiss it, but with a "FAILED" label instead of
    // "SOS ACTIVE".
    //
    // A 200 response with `sms_sent: false` is a PARTIAL success (the SOS
    // event was recorded in the database, but no SMS went out because the
    // user has no emergency contacts configured OR Twilio isn't set up
    // server-side). That's NOT a hard failure — we still show the active
    // state, but the message below will tell the user exactly what happened.
    final bool sendFailed = !_isSending && _sosResult == null;

    return Column(
      children: [
        const SizedBox(height: 8),
        // Pulsing indicator circle.
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: _isSending
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 4,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        l10n.sendingCaps,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        // Show an error icon when the send failed so the
                        // user immediately understands the alert did not go
                        // through (per Bug 1 #5 — give the user feedback).
                        // Show a "cloud upload" / "offline bolt" icon when
                        // the SOS was queued locally — distinct from both
                        // the success check and the error X.
                        sendFailed
                            ? Icons.error_outline
                            : (queuedLocally
                                ? Icons.cloud_upload_outlined
                                : Icons.check_circle),
                        color: Colors.white,
                        size: 60,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sendFailed
                            ? l10n.sosFailed
                            : (queuedLocally ? l10n.sosQueuedLabel : l10n.sosActive),
                        style: const TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _isSending
              ? l10n.sendingEmergencyAlert
              : (sendFailed
                  ? l10n.alertCouldNotBeSent
                  : (queuedLocally
                      ? l10n.emergencyAlertQueuedLabel
                      : l10n.emergencyAlertSent)),
          style: const TextStyle(
            fontFamily: 'ClashDisplay',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        if (_isSending)
          Text(
            l10n.sendingIn(_countdownSeconds),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Colors.white70,
            ),
          )
        else if (_sosMessage != null)
          Text(
            _sosMessage!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 24),
        // Contact / location card.
        _ActiveContactCard(
          isSending: _isSending,
          smsSent: smsSent,
          sentCount: sentCount,
          locationText: _locationText,
        ),
        const SizedBox(height: 24),
        if (!_isSending)
          // ── Action buttons row ──
          // On failure: show THREE buttons — "Call 112" (most prominent,
          // filled white), "Try Again" (outlined), and "Dismiss" (outlined).
          // Previously we only showed "Try Again" + "Dismiss", which meant
          // when the user was told "please call 112 or 911 directly" they
          // had no button to actually do it — they had to leave the app,
          // open the phone app, and dial manually. The Call 112 button
          // opens the system dialer directly via the `tel:` URL scheme.
          //
          // On success: just "I'm Safe - Resolve".
          if (sendFailed)
            Column(
              children: [
                // Call 112 — full-width, most prominent. This is the
                // action the user is being told to take; make it impossible
                // to miss.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _makePhoneCall('112'),
                    icon: const Icon(Icons.phone_in_talk, size: 22),
                    label: Text(l10n.callEmergencyNow),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFB8321D),
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!_sosRateLimited)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _triggerSos,
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.tryAgain),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    if (!_sosRateLimited) const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _resolveSos,
                        icon: const Icon(Icons.close),
                        label: Text(l10n.dismiss),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // FIX (audit H-5): when rate-limited, show an "Override and
                // resend" button so the user can force a new SOS if this is
                // a NEW emergency (not a double-tap). The 60s rate limit is
                // a spam guard, not a safety guard — blocking a real second
                // emergency is dangerous. The button requires explicit
                // confirmation to prevent accidental overrides.
                if (_sosRateLimited) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmOverrideAndResend(),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: Text(
                        l10n.overrideButtonText,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 2),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            )
          else
            // Success — single "I'm Safe - Resolve" button.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resolveSos,
                icon: const Icon(Icons.check_circle),
                label: Text(l10n.imSafeResolve),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFB8321D),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _QuickDialButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickDialButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: isDark ? 0.12 : 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final bool isDark;
  final VoidCallback onCall;
  final VoidCallback onText;

  const _EmergencyContactCard({
    required this.contact,
    required this.isDark,
    required this.onCall,
    required this.onText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.border(isDark),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary(isDark)
                    .withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person,
                  color: AppColors.primary(isDark), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (contact.relationship != null) ...[
                        Text(
                          contact.relationship!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '·',
                          style: TextStyle(
                            color: AppColors.textHint(isDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        contact.phone,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onCall,
              icon: Icon(Icons.phone,
                  color: AppColors.urgencyLow, size: 22),
              style: IconButton.styleFrom(
                backgroundColor:
                    AppColors.urgencyLow.withValues(alpha: isDark ? 0.12 : 0.08),
                minimumSize: const Size(40, 40),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: onText,
              icon: Icon(Icons.message,
                  color: AppColors.info(isDark), size: 22),
              style: IconButton.styleFrom(
                backgroundColor:
                    AppColors.info(isDark).withValues(alpha: isDark ? 0.12 : 0.08),
                minimumSize: const Size(40, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalIdRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MedicalIdRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(isDark),
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(isDark),
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable card that launches the native maps app to search for nearby
/// hospitals. Replaces the previous "Coming Soon" placeholder.
class _HospitalFinderCard extends StatelessWidget {
  final bool isDark;
  final Future<void> Function() onFindHospitals;

  const _HospitalFinderCard({
    required this.isDark,
    required this.onFindHospitals,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onFindHospitals,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E2230), const Color(0xFF151925)]
                : [const Color(0xFFE8E5FF), const Color(0xFFE0F2F1)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary(isDark).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_hospital_rounded,
                color: AppColors.primary(isDark),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.findHospitalsNearMe,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.opensMapsHospitals,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary(isDark),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primary(isDark),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card shown in the active / sending SOS state — displays the live location
/// being shared with emergency contacts and (after the send completes) the
/// number of contacts notified via SMS. Renders on the red radial gradient
/// background, so all text is white.
class _ActiveContactCard extends StatelessWidget {
  final bool isSending;
  final bool smsSent;
  final int sentCount;
  final String? locationText;

  const _ActiveContactCard({
    required this.isSending,
    required this.smsSent,
    required this.sentCount,
    required this.locationText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Live location row.
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.liveLocation,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locationText ??
                          (isSending
                              ? l10n.acquiringGps
                              : l10n.locationUnavailable),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Contacts notified row (only after the send completes).
          if (!isSending && smsSent) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.phone_in_talk,
                    color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.contactsNotified,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.contactsNotifiedCount(sentCount),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
