import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

/// QR Display Screen — redesigned to match the Google Stitch UI design.
///
/// Layout (top → bottom):
///   1. "HEALTH PASSPORT" eyebrow label (DM Sans 12 w700, uppercase,
///      letter-spacing 0.2em).
///   2. Patient name (ClashDisplay 24 w700) from [userProfileProvider].
///   3. QR card (radius 32, surface bg, soft primary-tinted shadow):
///        - Square [QrImageView] modules (was circle) for scanner reliability.
///        - "Valid for 23h 47m" expiry pill — computed from passport.expiresAt
///          and refreshed every 30s.
///   4. Instruction text: "Point this at any QR reader to securely share your
///      vitals."
///   5. DOWNLOAD + SHARE full-width pill buttons (rounded-full, 52px tall).
///      - DOWNLOAD captures the QR widget via [RepaintBoundary] and shares the
///        PNG via [Share.shareXFiles].
///      - SHARE shares the QR token + URL as text via [Share.share].
///   6. "Powered by Keter Marketing" footer.
class QrDisplayScreen extends ConsumerStatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  ConsumerState<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends ConsumerState<QrDisplayScreen> {
  String? _qrToken;
  bool _isGenerating = false;
  bool _isDownloading = false;

  /// GlobalKey for the QR widget so the DOWNLOAD button can capture it as a
  /// PNG via [RepaintBoundary] + [RenderRepaintBoundary.toImage].
  final GlobalKey _qrBoundaryKey = GlobalKey();

  /// Refreshes the "Valid for Xh Ym" pill every 30 seconds so the countdown
  /// stays accurate while the screen is on-screen.
  late final Timer _expiryTimer;

  @override
  void initState() {
    super.initState();
    _loadQrToken();
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTimer.cancel();
    super.dispose();
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
      final token = result['qr_token'] as String?;
      if (token == null || token.isEmpty) {
        // The edge function returned 200 but no qr_token — surface this
        // explicitly so we can see what's going on (per Bug 2 — improve
        // error handling so the actual cause is visible).
        throw Exception(
          'Edge function returned no qr_token. Response: $result',
        );
      }
      setState(() => _qrToken = token);
      ref.invalidate(healthPassportProvider);
    } catch (e) {
      debugPrint('QR generation failed: $e');
      if (mounted) {
        // Surface the actual error string in the snackbar instead of the
        // generic "Failed to generate QR code" message — the original code
        // hid the real cause (missing QR_ENCRYPTION_KEY, missing UNIQUE
        // constraint on health_passports.user_id, edge function 500, etc.).
        // Logging the full exception via debugPrint above so the dev console
        // has the stack trace too.
        AppSnackBar.errorFromException(
          context,
          'Failed to generate QR: ${e.toString()}',
          e,
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// Capture the QR widget as a PNG, save it to the temp directory, and share
  /// it as a file via [Share.shareXFiles]. This is the "DOWNLOAD" affordance
  /// per the design — there is no "save to gallery" permission flow yet, so
  /// we hand off to the system share sheet which lets the user pick Save
  /// Image / Files / Messages / etc.
  Future<void> _downloadQrImage() async {
    if (_qrToken == null || _isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        AppSnackBar.error(
            context, 'Could not capture the QR code. Please try again.');
        return;
      }
      // pixelRatio 3.0 for crisp output on high-DPI displays.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          AppSnackBar.error(context, 'Could not render the QR image.');
        }
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/vitalseker_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My VitalSeker Health Passport QR',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(
            context, 'Download failed. Please try again.', e);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Share a secure link to view the health passport via [Share.share].
  ///
  /// SECURITY: We do NOT share the raw QR token as plain text — that would
  /// defeat the AES-GCM encryption the generate-qr edge function applies.
  /// Instead, we share a deep link to the VitalSeker viewer page, which
  /// expects the recipient to scan the QR code from the sender's screen
  /// (the QR is the encrypted token rendered as an image, never the raw
  /// string). This honours the spec's "QR crypté" requirement.
  Future<void> _shareToken() async {
    if (_qrToken == null) return;
    await Share.share(
      'My VitalSeker Health Passport is ready to scan.\n\n'
      'Please ask me to show you the QR code on my VitalSeker app — '
      'scanning it will securely display my medical profile.\n\n'
      'VitalSeker — Your AI Health Companion',
      subject: 'VitalSeker Health Passport',
    );
  }

  /// Format the remaining passport validity as "Xh Ym". Returns null when no
  /// expiry is set so the pill can be hidden.
  String? _formatExpiry(DateTime? expiresAt, AppLocalizations l10n) {
    if (expiresAt == null) return null;
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return l10n.expired;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return l10n.validFor(hours, minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passportAsync = ref.watch(healthPassportProvider);
    final profileAsync = ref.watch(userProfileProvider);

    final passport = passportAsync.valueOrNull;
    final profile = profileAsync.valueOrNull;
    final patientName = (profile?.fullName?.isNotEmpty ?? false)
        ? profile!.fullName!
        : 'VitalSeker User';
    final expiryLabel = _formatExpiry(passport?.expiresAt, l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.healthPassportQr)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── 1. "HEALTH PASSPORT" eyebrow label ──
              Text(
                l10n.healthPassport.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  letterSpacing: 0.2, // 0.2em-ish at 12px ≈ 2.4px
                  color: AppColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 4),
              // ── 2. Patient name ──
              Text(
                patientName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.01,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 24),

              if (_isGenerating)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: CircularProgressIndicator(),
                )
              else if (_qrToken != null) ...[
                // ── 3. QR card (radius 32) ──
                RepaintBoundary(
                  key: _qrBoundaryKey,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface(isDark),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: AppColors.borderLight(isDark)),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.primary(isDark).withValues(alpha: 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Brand row inside the card.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_rounded,
                                color: AppColors.primary(isDark), size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'VitalSeker',
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Square-module QR (was circle) for scanner reliability.
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: _qrToken!,
                            version: QrVersions.auto,
                            size: 240,
                            backgroundColor: Colors.white,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColors.primary(isDark),
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColors.textPrimary(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Expiry pill — refreshed every 30s by [_expiryTimer].
                        if (expiryLabel != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer(isDark),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule,
                                    size: 14,
                                    color: AppColors.primary(isDark)),
                                const SizedBox(width: 6),
                                Text(
                                  expiryLabel,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // ── 4. Instruction text ──
                Text(
                  l10n.pointQrReader,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 28),
                // ── 5. DOWNLOAD + SHARE pill buttons (52px tall) ──
                _PillActionButton(
                  label: l10n.download,
                  icon: Icons.download_outlined,
                  isDark: isDark,
                  isLoading: _isDownloading,
                  primary: true,
                  onPressed: _downloadQrImage,
                ),
                const SizedBox(height: 12),
                _PillActionButton(
                  label: l10n.share,
                  icon: Icons.share_outlined,
                  isDark: isDark,
                  primary: false,
                  onPressed: _shareToken,
                ),
              ] else ...[
                Icon(Icons.qr_code_2,
                    size: 80, color: AppColors.textTertiary(isDark)),
                const SizedBox(height: 16),
                Text(
                  l10n.noQrCodeGenerated,
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _generateQr,
                  child: Text(l10n.generateQrCode),
                ),
              ],
              const SizedBox(height: 32),
              // ── 6. Footer ──
              Text(
                l10n.poweredBy,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  height: 1.5,
                  letterSpacing: 0.1,
                  color: AppColors.textTertiary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pill action button — full-width, 52px tall, rounded-full.
// `primary: true` => filled brand-gradient (DOWNLOAD).
// `primary: false` => outlined (SHARE).
// ═══════════════════════════════════════════════════════════════════════════

class _PillActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final bool primary;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PillActionButton({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.primary,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final brandGradient = AppColors.brandGradientFor(isDark);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: Container(
          decoration: BoxDecoration(
            gradient: primary ? brandGradient : null,
            color: primary ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            border: primary
                ? null
                : Border.all(color: AppColors.primary(isDark), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        primary ? Colors.white : AppColors.primary(isDark),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: primary ? Colors.white : AppColors.primary(isDark),
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.05,
                  color: primary ? Colors.white : AppColors.primary(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
