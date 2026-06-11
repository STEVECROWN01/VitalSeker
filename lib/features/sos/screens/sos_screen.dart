import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';

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

  // Pulse animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _triggerSos() async {
    // Haptic feedback
    HapticFeedback.heavyImpact();

    setState(() {
      _isSending = true;
      _sosMessage = 'Sending emergency alert...';
    });

    try {
      Position? position;
      try {
        position = await _getCurrentLocation();
      } catch (_) {}

      final edgeService = EdgeFunctionService();
      final result = await edgeService.sendSosAlert(
        latitude: position?.latitude,
        longitude: position?.longitude,
        locationAddress: position != null
            ? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
            : null,
      );

      setState(() {
        _sosActive = true;
        _sosResult = result;
        _sosMessage = result['message'] as String? ?? 'Emergency alert sent!';
      });

      // Continuous haptic
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        _sosMessage = 'Failed to send alert: $e';
      });
      HapticFeedback.heavyImpact();
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _resolveSos() {
    setState(() {
      _sosActive = false;
      _sosMessage = null;
      _sosResult = null;
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
    try {
      final position = await _getCurrentLocation();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get current location')),
          );
        }
        return;
      }
      final locationText =
          'My emergency location: https://maps.google.com/?q=${position.latitude},${position.longitude}';
      await Clipboard.setData(ClipboardData(text: locationText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location link copied to clipboard!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: _sosActive ? AppColors.urgencyEmergency : null,
        foregroundColor: _sosActive ? Colors.white : null,
      ),
      body: Container(
        decoration: _sosActive
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.urgencyEmergency.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              )
            : null,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── SOS Button ──
                if (!_sosActive) ...[
                  Text(
                    'Press and hold to send\nemergency alert',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onLongPress: _triggerSos,
                    child: ScaleTransition(
                      scale: _pulseAnimation,
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
                        child: _isSending
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 4,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.emergency,
                                      color: Colors.white, size: 64),
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
                  const SizedBox(height: 16),
                  Text(
                    'Hold for 3 seconds',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
                    ),
                  ),
                ] else ...[
                  // SOS Active state
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          AppColors.urgencyEmergency.withValues(alpha: 0.1),
                      border: Border.all(
                          color: AppColors.urgencyEmergency, width: 4),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emergency,
                            color: AppColors.urgencyEmergency, size: 64),
                        SizedBox(height: 8),
                        Text(
                          'SOS\nACTIVE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.urgencyEmergency,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _sosMessage ?? 'Emergency alert sent!',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.urgencyEmergency,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_sosResult?['sms_sent'] == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${(_sosResult?['contacts_notified'] as List?)?.where((c) => c['status'] == 'sent').length ?? 0} contact(s) notified via SMS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: isDark ? AppColors.grey400 : AppColors.grey500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _resolveSos,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('I\'m Safe - Resolve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.urgencyLow,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Quick Dial ──
                Row(
                  children: [
                    Icon(Icons.phone_in_talk,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Dial',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
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
                      foregroundColor:
                          isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
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
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Emergency Contacts',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
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
                          color: isDark ? AppColors.darkSurface : AppColors.grey50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2A2F3E)
                                : AppColors.grey200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.person_add_outlined,
                                size: 32,
                                color: isDark
                                    ? AppColors.grey500
                                    : AppColors.grey400),
                            const SizedBox(height: 8),
                            Text(
                              'No emergency contacts configured',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.grey400
                                    : AppColors.grey500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add contacts in your profile settings',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.grey500
                                    : AppColors.grey400,
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
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Nearby Hospitals',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.grey50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A2F3E)
                          : AppColors.grey200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.map_outlined,
                          size: 40,
                          color: isDark ? AppColors.grey500 : AppColors.grey400),
                      const SizedBox(height: 12),
                      Text(
                        'Coming Soon',
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.grey400 : AppColors.grey500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hospital finder will be available in a future update',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? AppColors.grey500 : AppColors.grey400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Medical ID Summary ──
                Row(
                  children: [
                    Icon(Icons.medical_information_outlined,
                        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Medical ID',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
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
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2A2F3E)
                              : AppColors.grey200,
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
                              child: Text(
                                'No medical information on file. Update your profile to add medical ID data.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.grey400
                                      : AppColors.grey500,
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
                            color: isDark ? AppColors.grey400 : AppColors.grey500,
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
                  color: isDark ? AppColors.grey400 : AppColors.grey500,
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
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2F3E) : AppColors.grey200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.lightPrimary
                    .withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person,
                  color: AppColors.lightPrimary, size: 22),
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
                      color: isDark
                          ? Colors.white
                          : AppColors.lightOnBackground,
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
                            color: isDark
                                ? AppColors.grey400
                                : AppColors.grey500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '·',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.grey500
                                : AppColors.grey400,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        contact.phone,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          color: isDark
                              ? AppColors.grey400
                              : AppColors.grey500,
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
                  color: AppColors.lightInfo, size: 22),
              style: IconButton.styleFrom(
                backgroundColor:
                    AppColors.lightInfo.withValues(alpha: isDark ? 0.12 : 0.08),
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
              color: isDark ? AppColors.grey400 : AppColors.grey500,
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
                color: isDark ? Colors.white : AppColors.lightOnBackground,
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
