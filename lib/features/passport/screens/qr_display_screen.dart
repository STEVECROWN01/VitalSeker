import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class QrDisplayScreen extends ConsumerStatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  ConsumerState<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends ConsumerState<QrDisplayScreen> {
  String? _qrToken;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadQrToken();
  }

  Future<void> _loadQrToken() async {
    final passport = ref.read(healthPassportProvider).valueOrNull;
    if (passport?.qrToken != null) {
      setState(() => _qrToken = passport!.qrToken);
    } else {
      await _generateQr();
    }
  }

  Future<void> _generateQr() async {
    setState(() => _isGenerating = true);
    try {
      final edgeService = EdgeFunctionService();
      final result = await edgeService.generateQr();
      setState(() => _qrToken = result['qr_token'] as String?);
      ref.invalidate(healthPassportProvider);
    } catch (e) {
      if (mounted) AppSnackBar.errorFromException(context, 'Failed to generate QR code. Please try again.', e);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Health Passport QR')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isGenerating)
                const CircularProgressIndicator()
              else if (_qrToken != null) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface(isDark),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary(isDark).withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_rounded, color: AppColors.primary(isDark), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'VitalSeker Health Passport',
                            style: TextStyle(
                              fontFamily: 'ClashDisplay',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      QrImageView(
                        data: _qrToken!,
                        version: QrVersions.auto,
                        size: 250,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.circle,
                          color: AppColors.primary(isDark),
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Scan to view health passport',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _generateQr,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (_qrToken != null) {
                          Share.share(
                            'My VitalSeker Health Passport QR Token: $_qrToken\n\nScan this at vitalseker.app to view my health information.',
                            subject: 'VitalSeker Health Passport',
                          );
                        }
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ] else ...[
                Icon(Icons.qr_code_2, size: 80, color: AppColors.textTertiary(isDark)),
                const SizedBox(height: 16),
                Text(
                  'No QR Code Generated',
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _generateQr,
                  child: const Text('Generate QR Code'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
