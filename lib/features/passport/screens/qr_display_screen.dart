import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/config/app_config.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';

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
  bool _isSharing = false;

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
        // Show a user-friendly message. The raw exception (e.g.
        // "FunctionException(status: 503, details: {code: BOOT_ERROR, ...})")
        // is logged via debugPrint above for developer debugging, but
        // must NOT be shown to end users — it leaks backend internals.
        final l10n = AppLocalizations.of(context)!;
        AppSnackBar.error(
          context,
          l10n.qrGenerationFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// Capture the QR widget as a PNG and save directly to the device's
  /// Downloads directory (no folder picker — saves automatically).
  Future<void> _downloadQrImage() async {
    if (_qrToken == null || _isDownloading || _isSharing) return;
    setState(() => _isDownloading = true);
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        AppSnackBar.error(
            context, 'Could not capture the QR code. Please try again.');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          AppSnackBar.error(context, 'Could not render the QR image.');
        }
        return;
      }
      final bytes = byteData.buffer.asUint8List();

      // FIX (audit H-7): platform-aware save location.
      //
      // On iOS, getDownloadsDirectory() returns null (iOS has no public
      // Downloads directory). The previous code fell back to a hardcoded
      // Android path (/storage/emulated/0/Download) that doesn't exist on
      // iOS, then to getTemporaryDirectory() — but the success snackbar
      // still said "saved to Downloads", which was a lie. iOS also purges
      // temp files.
      //
      // Now: on iOS we save to the app's documents directory and present
      // a share sheet so the user can save to Photos or Files. On Android
      // we use getDownloadsDirectory() (works via SAF on Android 10+).
      final fileName = 'vitalseker_qr_${DateTime.now().millisecondsSinceEpoch}.png';

      if (Platform.isIOS) {
        // iOS: save to app documents, then offer a share sheet so the user
        // can save to Photos or Files. The share sheet is the iOS-native
        // way to let users choose where to save.
        final docsDir = await path_provider.getApplicationDocumentsDirectory();
        final file = File('${docsDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        if (mounted) {
          // Present the share sheet — the user can save to Photos, Files,
          // or send via Messages/Mail.
          await SharePlus.instance.share(ShareParams(
            files: [XFile(file.path)],
            text: 'VitalSeker Health Passport QR Code',
          ));
          AppSnackBar.success(
            context,
            'QR code saved. Use the share sheet to save to Photos or Files.',
          );
        }
      } else {
        // Android: save to the public Downloads directory.
        Directory? saveDir;
        try {
          saveDir = await path_provider.getDownloadsDirectory();
        } catch (_) {}

        if (saveDir == null) {
          // Fallback: app-specific external storage (still accessible via
          // the system file picker on Android 10+).
          try {
            saveDir = await path_provider.getExternalStorageDirectory() ??
                await path_provider.getTemporaryDirectory();
          } catch (_) {
            saveDir = await path_provider.getTemporaryDirectory();
          }
        }

        final file = File('${saveDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        if (mounted) {
          AppSnackBar.success(
            context,
            'QR code saved to ${saveDir.path.contains('Download') ? "Downloads" : "app storage"}.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(
            context, 'Download failed. Please try again.', e);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Share the QR code image (not text) via the system share sheet.
  ///
  /// Uses its own [_isSharing] flag (NOT [_isDownloading]) so the loading
  /// spinner appears on the Share button — not on the Download button —
  /// while the share sheet is being prepared.
  Future<void> _shareToken() async {
    if (_qrToken == null || _isDownloading || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        AppSnackBar.error(context, 'Could not capture the QR code.');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await path_provider.getTemporaryDirectory();
      final file = File(
          '${dir.path}/vitalseker_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      // FIX (audit H-8): show a confirmation dialog before sharing so the
      // user understands they're sharing their full medical passport. The
      // previous code shared immediately on tap — anyone receiving the share
      // (messages, email, social media) could scan the QR and view the user's
      // blood type, allergies, conditions, and medications.
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Share Medical Passport?'),
          content: const Text(
            'This QR code grants access to your medical information '
            '(blood type, allergies, chronic conditions, medications, '
            'emergency contacts). Anyone who receives it can scan it '
            'and view your health data.\n\n'
            'Only share it with people you trust — doctors, nurses, or '
            'emergency contacts. Do not post it on social media.\n\n'
            'The QR code expires in 24 hours.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.share),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      // Share the QR image (not text)
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'My VitalSeker Health Passport QR Code — scan to view my medical info. '
              'This code expires in 24 hours. Only share with trusted healthcare providers.',
      ));
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not share QR code.');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
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
                            const Image(
                              image: AssetImage(
                                'assets/images/branding/app_logo.png',
                              ),
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
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
                        // The QR encodes a URL that scanners can open — when
                        // scanned, it opens the VitalSeker passport viewer
                        // web page which decrypts and displays the health data.
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            // FIX (audit H-54): encode a real URL so standard
                            // QR scanners (phone camera, third-party apps)
                            // can open it in a browser. The previous format
                            // 'VITALSEKER_PASSPORT:token' was not a URL —
                            // standard scanners saw it as text and did nothing.
                            // An emergency responder with a standard scanner
                            // would see gibberish instead of the passport.
                            //
                            // The URL points to the VitalSeker passport viewer
                            // web page, which decodes the token and displays
                            // the medical info. The domain must be configured
                            // in your DNS — replace 'passport.vitalseker.app'
                            // with your actual domain.
                            data: 'https://passport.vitalseker.app/v/$_qrToken',
                            version: QrVersions.auto,
                            size: 240,
                            backgroundColor: Colors.white,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
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
                // NOTE: each button uses its OWN loading flag so a Share tap
                // doesn't make the Download button appear active (and vice
                // versa). Both buttons are also disabled while either is busy.
                _PillActionButton(
                  label: l10n.download,
                  icon: Icons.download_outlined,
                  isDark: isDark,
                  isLoading: _isDownloading,
                  primary: true,
                  onPressed: _isSharing ? null : _downloadQrImage,
                ),
                const SizedBox(height: 12),
                _PillActionButton(
                  label: l10n.share,
                  icon: Icons.share_outlined,
                  isDark: isDark,
                  isLoading: _isSharing,
                  primary: false,
                  onPressed: _isDownloading ? null : _shareToken,
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
              const MedicalDisclaimerBanner(),
              const SizedBox(height: 16),
              // ── 6. Footer ──
              Text(
                l10n.poweredBy(AppConfig.producer),
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
  /// Nullable so the parent can disable a button while the OTHER button's
  /// action is in progress (e.g. disable Download while Share is sharing).
  final VoidCallback? onPressed;

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
        // HitTestBehavior.opaque ensures the ENTIRE 52x∞ button area is
        // tappable — even the transparent outlined area on the Share button.
        // Without this, only the icon/text/border register taps, so a tap
        // on the middle of the outlined Share button could silently miss.
        behavior: HitTestBehavior.opaque,
        onTap: (isLoading || onPressed == null) ? null : onPressed,
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
