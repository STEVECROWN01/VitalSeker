import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../core/services/database_service.dart';
import '../../../shared/theme/app_colors.dart';

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  bool _isSending = false;
  bool _sosActive = false;
  String? _sosMessage;
  Map<String, dynamic>? _sosResult;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                if (!_sosActive) ...[
                  // SOS Button
                  Text(
                    'Press and hold to send\nemergency alert',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onLongPress: _triggerSos,
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
                            color: AppColors.urgencyEmergency.withValues(alpha: 0.4),
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
                  const SizedBox(height: 24),
                  Text(
                    'Hold for 3 seconds',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
                    ),
                  ),
                ] else ...[
                  // SOS Active
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.urgencyEmergency.withValues(alpha: 0.1),
                      border: Border.all(color: AppColors.urgencyEmergency, width: 4),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emergency, color: AppColors.urgencyEmergency, size: 64),
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
                  const SizedBox(height: 24),
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
                    const SizedBox(height: 12),
                    Text(
                      '${(_sosResult?['contacts_notified'] as List?)?.where((c) => c['status'] == 'sent').length ?? 0} contact(s) notified via SMS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: isDark ? AppColors.grey400 : AppColors.grey500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _resolveSos,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('I\'m Safe - Resolve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.urgencyLow,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],

                const Spacer(),

                // Emergency tip
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.urgencyMedium.withValues(alpha: isDark ? 0.1 : 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.urgencyMedium.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.urgencyMedium, size: 20),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
