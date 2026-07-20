import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

/// Full-screen overlay shown while the AI is processing the user's symptoms.
///
/// Animation choreography (per `vitalseker_animation_spec_sheet_text.md`):
///  - Brain icon:    subtle float (±5px Y-axis), 3s, ease-in-out
///  - Dashed ring:   clockwise rotation, 360°, 4s, linear
///  - Progress bar:  incremental fill (0 → 90%), 3s, ease-out
///
/// Additional ambient layers (cosmetic, not in the spec sheet but matched
/// to the design language):
///  - Animated dots that trail the headline ("Analyzing your symptoms…")
///  - A pulsing JetBrains-Mono "data stream" of fake compiler-style lines
///  - A footer disclaimer reminding the user this is information, not a
///    medical diagnosis.
///
/// The overlay is purely visual — the parent screen is responsible for
/// mounting and dismissing it based on its own `_isProcessing` flag.
class AiThinkingScreen extends StatefulWidget {
  const AiThinkingScreen({super.key});

  @override
  State<AiThinkingScreen> createState() => _AiThinkingScreenState();
}

class _AiThinkingScreenState extends State<AiThinkingScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ───────────────────────────────────────────
  late final AnimationController _ringRotationController; // 4s linear, loop
  late final AnimationController _brainFloatController; // 3s ease-in-out, loop
  late final AnimationController _progressController; // 3s ease-out, once
  late final AnimationController _dotsController; // 1.2s, loop (headline dots)
  late final AnimationController _pulseController; // 1.6s, loop (data stream)

  static const Duration _ringRotationDuration = Duration(seconds: 4);
  static const Duration _brainFloatDuration = Duration(seconds: 3);
  static const Duration _progressDuration = Duration(seconds: 3);
  static const Duration _dotsDuration = Duration(milliseconds: 1200);
  static const Duration _pulseDuration = Duration(milliseconds: 1600);

  // Cosmetic data-stream lines (cycled through with a staggered pulse).
  // Purely decorative — they make the screen feel alive while Claude thinks.
  static const List<String> _dataStreamLines = [
    '> compiling_metrics...',
    '> matching_heuristics...',
    '> cross_referencing_vitals...',
    '> estimating_urgency...',
  ];

  @override
  void initState() {
    super.initState();

    // Dashed ring: infinite clockwise rotation, linear curve.
    _ringRotationController = AnimationController(
      vsync: this,
      duration: _ringRotationDuration,
    )..repeat();

    // Brain float: ping-pong ±5px Y, ease-in-out curve applied inline.
    _brainFloatController = AnimationController(
      vsync: this,
      duration: _brainFloatDuration,
    )..repeat(reverse: true);

    // Progress bar: one-shot 0 → 90%, ease-out. We leave it at 0.9 if the
    // AI takes longer than 3s — better than pinning at 100% before the
    // response actually arrives.
    _progressController = AnimationController(
      vsync: this,
      duration: _progressDuration,
    )..forward();

    // Headline dots: cycle through 0..3 dots, looping forever.
    _dotsController = AnimationController(
      vsync: this,
      duration: _dotsDuration,
    )..repeat();

    // Data-stream pulse: gentle opacity breathing.
    _pulseController = AnimationController(
      vsync: this,
      duration: _pulseDuration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringRotationController.dispose();
    _brainFloatController.dispose();
    _progressController.dispose();
    _dotsController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppColors.background(isDark);
    final primaryColor = AppColors.primary(isDark);

    // FIX: wrap in PopScope(canPop: false) so the back gesture/button
    // doesn't dismiss the overlay mid-request. The previous code had no
    // guard — if the user hit back while runTriage was in flight, the
    // overlay was popped but the parent was still awaiting. When the
    // future resolved, navigator.pop() popped the PARENT screen, and
    // context.push(triageResult) either crashed or was silently lost.
    return PopScope(
      canPop: false,
      child: Stack(
      children: [
        // 1) Blur the screen behind the overlay + opaque dim layer so the
        //    background is no longer visible/bleeding through.
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: bgColor.withValues(alpha: 0.94),
            ),
          ),
        ),
        // 2) Subtle radial gradient on top of the blur (kept very subtle so
        //    it does not re-introduce transparency at the center).
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.85,
                colors: [
                  primaryColor.withValues(alpha: isDark ? 0.10 : 0.06),
                  bgColor.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
        // 3) Actual overlay content.
        Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              const Spacer(flex: 3),
              _buildCluster(isDark),
              const SizedBox(height: 40),
              _buildHeadline(isDark, context),
              const SizedBox(height: 8),
              _buildSubtitle(isDark, context),
              const SizedBox(height: 32),
              _buildProgressBar(isDark),
              const SizedBox(height: 24),
              _buildDataStream(isDark),
              const Spacer(flex: 3),
              _buildFooter(isDark, context),
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
      ],
      ),
    );
  }

  // ── 192×192 cluster: dashed ring + ambient ring + floating brain ─────
  Widget _buildCluster(bool isDark) {
    return SizedBox(
      width: 192,
      height: 192,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer dashed ring — rotates clockwise, 360° / 4s, linear.
          AnimatedBuilder(
            animation: _ringRotationController,
            builder: (context, _) {
              return Transform.rotate(
                angle: _ringRotationController.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(192, 192),
                  painter: _DashedRingPainter(
                    color: AppColors.primary(isDark).withValues(alpha: 0.45),
                    dashCount: 32,
                    dashWidth: 2.5,
                    gapFactor: 0.6,
                    strokeWidth: 2.0,
                  ),
                ),
              );
            },
          ),

          // Inner ambient ring — surface-container fill + soft brand glow.
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer(isDark),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary(isDark).withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // Brain icon — 72px, floats ±5px on Y over 3s, ease-in-out.
          AnimatedBuilder(
            animation: _brainFloatController,
            builder: (context, child) {
              final t =
                  Curves.easeInOut.transform(_brainFloatController.value);
              // Map t (0..1) to dy in [-5, +5]. With reverse: true the
              // icon bobs down then up continuously.
              final dy = (t * 2 - 1) * 5.0;
              return Transform.translate(
                offset: Offset(0, dy),
                child: child,
              );
            },
            child: Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              child: Icon(
                Icons.psychology,
                size: 72,
                color: AppColors.primary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Headline + animated trailing dots ────────────────────────────────
  Widget _buildHeadline(bool isDark, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Pre-computed strings for 0..3 trailing dots (padded so the text width
    // doesn't jump as dots appear/disappear).
    const dotChars = ['   ', '.  ', '.. ', '...'];

    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        final idx = (_dotsController.value * 3).floor() % 4;
        return RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: l10n.analyzingSymptoms,
                style: AppTextStyles.subheading1.copyWith(
                  fontSize: 24,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              TextSpan(
                text: dotChars[idx],
                style: AppTextStyles.subheading1.copyWith(
                  fontSize: 24,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubtitle(bool isDark, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.aiProcessing,
      textAlign: TextAlign.center,
      style: AppTextStyles.bodyLarge.copyWith(
        color: AppColors.textSecondary(isDark),
      ),
    );
  }

  // ── Progress bar: 200×8, 0 → 90% over 3s, ease-out ───────────────────
  Widget _buildProgressBar(bool isDark) {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_progressController.value);
        final fill = t * 0.9; // cap at 90% per spec
        final percent = (fill * 100).round();
        return Column(
          children: [
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: LinearProgressIndicator(
                    value: fill,
                    minHeight: 8,
                    backgroundColor:
                        AppColors.primary(isDark).withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary(isDark),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$percent%',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary(isDark),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Cosmetic data-stream (JetBrains Mono 13px, pulsing opacity) ──────
  Widget _buildDataStream(bool isDark) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        // Base opacity 50%, breathing ±15% → 0.35..0.65.
        final opacity = 0.50 + 0.15 * (_pulseController.value * 2 - 1).abs();
        return Opacity(
          opacity: opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in _dataStreamLines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    line,
                    style: AppTextStyles.monoRegular.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Footer disclaimer (DM Sans 12px w700, opacity 70%) ──────────────
  Widget _buildFooter(bool isDark, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Opacity(
        opacity: 0.70,
        child: Text(
          l10n.medicalDisclaimer,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 12,
            color: AppColors.textSecondary(isDark),
          ),
        ),
      ),
    );
  }
}

/// Paints a circular dashed ring — used by [AiThinkingScreen] for the
/// rotating outer ring around the brain icon.
///
/// The ring is built from N evenly-spaced arcs; each dash occupies
/// `dashWidth / circumference` of the circle, and the gap is sized by
/// `gapFactor` (the fraction of each segment that is empty).
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final int dashCount;
  final double dashWidth; // in pixels along the circumference
  final double gapFactor; // 0..1, fraction of each segment that is gap
  final double strokeWidth;

  _DashedRingPainter({
    required this.color,
    required this.dashCount,
    required this.dashWidth,
    required this.gapFactor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final circumference = 2 * math.pi * radius;

    final dashArc = (dashWidth / circumference) * 2 * math.pi;
    // Solve for gapArc so that gapArc / (dashArc + gapArc) == gapFactor.
    final denom = (1 - gapFactor).clamp(0.01, 1.0);
    final gapArc = dashArc * gapFactor / denom;
    final segment = dashArc + gapArc;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Start at the top (−π/2) so the first dash is centered at 12 o'clock.
    var start = -math.pi / 2;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashArc,
        false,
        paint,
      );
      start += segment;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashCount != dashCount ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.gapFactor != gapFactor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
