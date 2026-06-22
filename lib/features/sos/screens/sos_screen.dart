import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Emergency SOS?'),
        content: const Text(
          'This will send an SMS with your live location to all of your emergency contacts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.urgencyEmergency,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send SOS'),
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
  /// Returns the [Position] on success, or `null` on any failure (with a
  /// contextual snackbar shown to the user via [AppSnackBar]).
  Future<Position?> _getCurrentLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are off — offer to open the system settings so
        // the user can enable GPS. This is the most common cause of the old
        // "Could not get current location" message.
        if (mounted) {
          AppSnackBar.error(
            context,
            'Location services are disabled. Please enable GPS in your device settings.',
          );
        }
        // Best-effort attempt to open the system location settings so the
        // user can flip the switch without leaving the flow. The user comes
        // back to the app after enabling.
        try {
          await Geolocator.openLocationSettings();
        } catch (_) {
          // openLocationSettings may not be implemented on every platform —
          // the snackbar above already told the user what to do.
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
          if (mounted) {
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
        if (mounted) {
          AppSnackBar.error(
            context,
            'Location permission is permanently denied. Please enable it in your app settings to use this feature.',
          );
        }
        try {
          await Geolocator.openAppSettings();
        } catch (_) {}
        return null;
      }

      // Use a 10s time limit so a slow GPS fix doesn't hang the call
      // forever — the previous implementation could block indefinitely in
      // tunnels / indoors.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } on TimeoutException {
      if (mounted) {
        AppSnackBar.error(
          context,
          'Could not get a GPS fix. Please try again outdoors or near a window.',
        );
      }
      return null;
    } catch (e) {
      debugPrint('_getCurrentLocation error: $e');
      if (mounted) {
        AppSnackBar.errorFromException(
          context,
          'Could not get current location. Please check location permissions.',
          e,
        );
      }
      return null;
    }
  }

  Future<void> _triggerSos() async {
    // Haptic feedback
    HapticFeedback.heavyImpact();

    setState(() {
      _isSending = true;
      _sosMessage = 'Sending emergency alert...';
      _locationText = null;
    });

    _startCountdown();

    try {
      Position? position;
      try {
        position = await _getCurrentLocation();
      } catch (_) {
        // Best-effort — the SOS still goes out without coordinates.
      }

      final locationText = position != null
          ? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
          : null;
      if (locationText != null) {
        setState(() => _locationText = locationText);
      }

      final edgeService = EdgeFunctionService();
      final result = await edgeService.sendSosAlert(
        latitude: position?.latitude,
        longitude: position?.longitude,
        locationAddress: locationText,
      );

      // ── Success ──
      // Flip _sosActive ON so the active state UI renders with the result
      // message + contacts-notified card. The previous code already set
      // _sosActive here, but combined with the finally-block that resets
      // _isSending = false, the active state needs _sosActive to stay true
      // — which it does. The bug was that on the error path below, the
      // active state was never shown and the user saw no feedback at all.
      setState(() {
        _sosActive = true;
        _sosResult = result;
        _sosMessage = result['message'] as String? ??
            'Emergency alert sent! Your contacts have been notified.';
      });

      // Continuous haptic
      HapticFeedback.mediumImpact();
    } catch (e) {
      // ── Failure ──
      // Set _sosActive = true here too so the active-state UI renders with
      // the failure message — previously the error was written to
      // _sosMessage but never shown because _isActiveState was false.
      debugPrint('SOS trigger error: $e');
      setState(() {
        _sosActive = true;
        _sosResult = null;
        _sosMessage =
            'Failed to send alert. Please call emergency services directly (112 / 911).';
      });
      if (mounted) {
        AppSnackBar.errorFromException(
          context,
          'SOS delivery failed. Please call 112 or 911 directly.',
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

  void _resolveSos() {
    _countdownTimer?.cancel();
    setState(() {
      _sosActive = false;
      _isSending = false;
      _sosMessage = null;
      _sosResult = null;
      _locationText = null;
      _countdownSeconds = _kCountdownFrom;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch call to $phoneNumber')),
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
    final position = await _getCurrentLocation();
    // _getCurrentLocation already shows a contextual snackbar on every
    // failure mode (services off / permission denied / timeout / exception),
    // so we just bail out silently here when it returns null.
    if (position == null) return;
    try {
      final locationText =
          'My emergency location: https://maps.google.com/?q=${position.latitude},${position.longitude}';
      await Clipboard.setData(ClipboardData(text: locationText));
      if (mounted) {
        AppSnackBar.success(context, 'Location link copied to clipboard!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(
            context, 'Failed to copy location to clipboard.', e);
      }
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
    Position? position;
    try {
      position = await _getCurrentLocation();
    } catch (_) {
      // GPS unavailable — fall through to generic search.
    }

    // Build both candidate URIs up-front so we can fall through cleanly.
    final Uri geoUri = position != null
        ? Uri.parse('geo:${position.latitude},${position.longitude}?q=hospital')
        : Uri.parse('geo:0,0?q=hospital');
    final Uri httpsUri = position != null
        ? Uri.parse(
            'https://www.google.com/maps/search/hospital/@${position.latitude},${position.longitude},15z')
        : Uri.parse('https://www.google.com/maps/search/hospital');

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
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
                    'Press and hold to send\nemergency alert',
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
                    _isHolding ? 'Keep holding...' : 'Hold for 3 seconds',
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
                      'Quick Dial',
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
                        label: '112',
                        subtitle: 'EU Emergency',
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
                        subtitle: 'US Emergency',
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
                    onPressed: _shareLocation,
                    icon: const Icon(Icons.location_on_outlined, size: 20),
                    label: const Text('Share My Location'),
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
                      'Emergency Contacts',
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
                              'No emergency contacts configured',
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
                                'Add contacts in your profile settings',
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
                      'Nearby Hospitals',
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
                      'Medical ID',
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
                              label: 'Blood Type',
                              value: profile.bloodType!,
                              color: AppColors.urgencyEmergency,
                              isDark: isDark,
                            ),
                          if (profile.allergies.isNotEmpty)
                            _MedicalIdRow(
                              icon: Icons.warning_amber_rounded,
                              label: 'Allergies',
                              value: profile.allergies.join(', '),
                              color: AppColors.urgencyMedium,
                              isDark: isDark,
                            ),
                          if (profile.chronicConditions.isNotEmpty)
                            _MedicalIdRow(
                              icon: Icons.medical_information,
                              label: 'Conditions',
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
                                    const TextSpan(
                                      text:
                                          'No medical information on file. Update your profile to ',
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: GestureDetector(
                                        onTap: () => context
                                            .push(AppConfig.medicalId),
                                        child: Text(
                                          'add medical ID data',
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
                          'SOS sends your GPS location to your emergency contacts via SMS. Make sure your contacts are configured in your profile.',
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
    final smsSent = _sosResult?['sms_sent'] == true;
    final contactsNotified = (_sosResult?['contacts_notified'] as List?) ?? [];
    final sentCount =
        contactsNotified.where((c) => c['status'] == 'sent').length;
    // Whether the SOS alert actually went out. False in the catch-block path
    // of [_triggerSos] (edge-function error, network failure, etc.) — we
    // still want to render the active state so the user sees the failure
    // message + can dismiss it, but with a "FAILED" label instead of
    // "SOS ACTIVE".
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
                ? const Column(
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
                        'SENDING',
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
                        sendFailed ? Icons.error_outline : Icons.check_circle,
                        color: Colors.white,
                        size: 60,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sendFailed ? 'SOS FAILED' : 'SOS ACTIVE',
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
              ? 'Sending Emergency Alert'
              : (sendFailed
                  ? 'Alert Could Not Be Sent'
                  : 'Emergency Alert Sent'),
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
            'Sending in $_countdownSeconds…',
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
          Row(
            children: [
              // On failure, show a "Try Again" button that re-triggers the
              // SOS. On success, just show the "I'm Safe - Resolve" button.
              if (sendFailed)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _triggerSos,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
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
              if (sendFailed) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resolveSos,
                  icon: Icon(sendFailed ? Icons.close : Icons.check_circle),
                  label: Text(sendFailed ? 'Dismiss' : "I'm Safe - Resolve"),
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
                    'Find Hospitals Near Me',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Opens your maps app with emergency hospitals nearby',
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
                      'Live Location',
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
                              ? 'Acquiring GPS coordinates…'
                              : 'Location unavailable'),
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
                        'Contacts Notified',
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
                        '$sentCount contact${sentCount == 1 ? '' : 's'} reached via SMS',
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
