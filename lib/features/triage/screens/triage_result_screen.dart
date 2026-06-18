import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/urgency_badge.dart';

/// Triage Result Screen — redesigned to match the Google Stitch UI design.
///
/// Layout (top → bottom):
///   1. Hero visualizer — 120px rotating dashed ring (12s linear loop) wrapping
///      a solid green ring with a check_circle icon. The ring color reflects
///      the urgency level.
///   2. Headline (ClashDisplay 32 w800, primary) — derived from `seek_care`.
///      Replaces the old "Urgency Score: X/100" headline.
///   3. UrgencyBadge + "Urgency Score: X/100" caption (JetBrainsMono).
///   4. Symptom chips (pill-shaped, secondary-container bg) — derived from
///      `possible_conditions` names when the edge function does not echo the
///      user-supplied symptoms.
///   5. "When to escalate" amber card (orange-50 bg, warning icon, criteria
///      list — a mix of red flags + per-urgency static advice).
///   6. Existing sections preserved: Red Flags, Recommendations, Possible
///      Conditions, Follow-up Questions, Disclaimer.
///   7. Action buttons row: "Save to Passport" (outlined) + "Share Result"
///      (filled).
class TriageResultScreen extends StatefulWidget {
  final Map<String, dynamic> triageData;

  const TriageResultScreen({super.key, required this.triageData});

  @override
  State<TriageResultScreen> createState() => _TriageResultScreenState();
}

class _TriageResultScreenState extends State<TriageResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(); // 12s linear rotation loop, per design.
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final triage =
        widget.triageData['triage'] as Map<String, dynamic>? ?? widget.triageData;
    final urgencyLevel = triage['urgency_level'] as String? ?? 'medium';
    final urgencyScore = triage['urgency_score'] as int? ?? 50;
    final seekCare = triage['seek_care'] as String? ?? 'schedule-appointment';
    final recommendations =
        (triage['recommendations'] as List<dynamic>? ?? []).cast<String>();
    final redFlags =
        (triage['red_flags'] as List<dynamic>? ?? []).cast<String>();
    final possibleConditions = triage['possible_conditions'] as List<dynamic>? ?? [];
    final disclaimer = triage['disclaimer'] as String? ??
        'This is not a medical diagnosis. Always consult a healthcare professional for proper medical advice.';
    final followUpQuestions =
        (triage['follow_up_questions'] as List<dynamic>? ?? []).cast<String>();

    final heroColor = _urgencyColor(urgencyLevel);
    final headline = _seekCareHeadline(seekCare);

    // Build the symptom chips below the hero. The edge function does not
    // currently echo the user-supplied symptoms back in the triage map, so we
    // derive chips from `possible_conditions` names as a graceful fallback.
    final List<String> chips = <String>[
      ...(triage['symptoms'] as List<dynamic>? ?? const []).cast<String>(),
      if ((triage['symptoms'] as List<dynamic>? ?? const []).isEmpty)
        ...possibleConditions.take(3).map((c) {
          final name = (c is Map ? c['name'] : c)?.toString() ?? '';
          return name;
        }).where((s) => s.isNotEmpty),
      if (possibleConditions.isEmpty) _seekCareLabel(seekCare),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Triage Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1–4. Hero visualizer + headline + chips ──
            Center(
              child: Column(
                children: [
                  _HeroVisualizer(
                    color: heroColor,
                    icon: _urgencyIcon(urgencyLevel),
                    rotationController: _rotationController,
                  )
                      .animate()
                      .scale(
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                        begin: const Offset(0.85, 0.85),
                      )
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 20),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.02,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                  const SizedBox(height: 10),
                  UrgencyBadge(urgencyLevel: urgencyLevel, fontSize: 12),
                  const SizedBox(height: 6),
                  Text(
                    'Urgency Score: $urgencyScore/100',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (chips.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: chips
                          .map((s) => _PillChip(label: s, isDark: isDark))
                          .toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── 5. "When to escalate" amber card ──
            _EscalationCard(
              isDark: isDark,
              criteria: _escalationCriteria(urgencyLevel, redFlags),
            ),
            const SizedBox(height: 24),

            // ── 6a. Red Flags ──
            if (redFlags.isNotEmpty) ...[
              const _SectionTitle(
                title: 'Red Flags',
                icon: Icons.warning_amber_rounded,
                color: AppColors.urgencyEmergency,
              ),
              const SizedBox(height: 8),
              ...redFlags.map((flag) => Card(
                    color: AppColors.urgencyEmergency
                        .withValues(alpha: isDark ? 0.10 : 0.05),
                    child: ListTile(
                      leading: const Icon(Icons.error_outline,
                          color: AppColors.urgencyEmergency),
                      title: Text(
                        flag,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.6,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 24),
            ],

            // ── 6b. Recommendations ──
            if (recommendations.isNotEmpty) ...[
              _SectionTitle(
                title: 'Recommendations',
                icon: Icons.lightbulb_outline,
                color: AppColors.primary(isDark),
              ),
              const SizedBox(height: 8),
              ...recommendations.asMap().entries.map((entry) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            AppColors.primary(isDark).withValues(alpha: 0.12),
                        child: Text(
                          '${entry.key + 1}',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary(isDark),
                          ),
                        ),
                      ),
                      title: Text(
                        entry.value,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.6,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 24),
            ],

            // ── 6c. Possible Conditions ──
            if (possibleConditions.isNotEmpty) ...[
              _SectionTitle(
                title: 'Possible Conditions',
                icon: Icons.medical_information_outlined,
                color: AppColors.secondary(isDark),
              ),
              const SizedBox(height: 8),
              ...possibleConditions.map((condition) {
                final c = condition as Map<String, dynamic>;
                final probability = c['probability'] as String? ?? 'low';
                return Card(
                  child: ListTile(
                    leading: Icon(
                      probability == 'high'
                          ? Icons.circle
                          : (probability == 'medium'
                              ? Icons.remove_circle_outline
                              : Icons.circle_outlined),
                      color: probability == 'high'
                          ? AppColors.urgencyHigh
                          : (probability == 'medium'
                              ? AppColors.urgencyMedium
                              : AppColors.urgencyLow),
                    ),
                    title: Text(
                      c['name']?.toString() ?? '',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    subtitle: Text(
                      c['description']?.toString() ?? '',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // ── 6d. Follow-up Questions ──
            if (followUpQuestions.isNotEmpty) ...[
              _SectionTitle(
                title: 'Follow-up Questions',
                icon: Icons.help_outline,
                color: isDark ? AppColors.darkInfo : AppColors.lightInfo,
              ),
              const SizedBox(height: 8),
              ...followUpQuestions.map((q) => Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.chat_bubble_outline,
                        color: isDark ? AppColors.darkInfo : AppColors.lightInfo,
                        size: 20,
                      ),
                      title: Text(
                        q,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 1.6,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 24),
            ],

            // ── 6e. Disclaimer ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.urgencyMedium
                    .withValues(alpha: isDark ? 0.10 : 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.urgencyMedium.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.urgencyMedium, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      disclaimer,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── 7. Action buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => AppSnackBar.success(
                      context,
                      'Triage result saved to your Health Passport.',
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('Save to Passport'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Share.share(
                      'My VitalSeker triage result:\n'
                      'Urgency: ${urgencyLevel.toUpperCase()} ($urgencyScore/100)\n'
                      'Recommendation: ${_seekCareLabel(seekCare)}\n\n'
                      '$disclaimer',
                      subject: 'VitalSeker Triage Result',
                    ),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share Result'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Color _urgencyColor(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return AppColors.urgencyLow;
      case 'medium':
        return AppColors.urgencyMedium;
      case 'high':
        return AppColors.urgencyHigh;
      case 'emergency':
        return AppColors.urgencyEmergency;
      default:
        return AppColors.urgencyMedium;
    }
  }

  IconData _urgencyIcon(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return Icons.check_circle_rounded;
      case 'medium':
        return Icons.warning_rounded;
      case 'high':
        return Icons.error_rounded;
      case 'emergency':
        return Icons.emergency_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  /// Headline shown beneath the hero — derived from `seek_care`.
  /// "Monitor at Home" is the green-light (low) variant per the design mockup.
  String _seekCareHeadline(String care) {
    switch (care) {
      case 'self-care':
        return 'Monitor at Home';
      case 'schedule-appointment':
        return 'See a Doctor Soon';
      case 'urgent-care':
        return 'Visit Urgent Care';
      case 'emergency':
        return 'Emergency Care Now';
      default:
        return 'Monitor at Home';
    }
  }

  String _seekCareLabel(String care) {
    switch (care) {
      case 'self-care':
        return 'Self-Care Recommended';
      case 'schedule-appointment':
        return 'Schedule an Appointment';
      case 'urgent-care':
        return 'Visit Urgent Care';
      case 'emergency':
        return 'Seek Emergency Care';
      default:
        return 'Consult a Healthcare Provider';
    }
  }

  /// Build the escalation-criteria list for the amber card. Uses red flags as
  /// the primary source, then appends per-urgency static advice so the card is
  /// never empty.
  List<String> _escalationCriteria(String urgencyLevel, List<String> redFlags) {
    final criteria = <String>[];
    if (redFlags.isNotEmpty) {
      criteria.addAll(redFlags.take(3));
    }
    switch (urgencyLevel.toLowerCase()) {
      case 'low':
        criteria.addAll([
          'Symptoms worsen or spread to new body areas',
          'Fever rises above 39°C (102°F)',
          'No improvement after 48 hours of self-care',
        ]);
        break;
      case 'medium':
        criteria.addAll([
          'Symptoms persist beyond 3 days',
          'Pain intensifies or becomes unmanageable',
          'New red-flag symptoms appear',
        ]);
        break;
      case 'high':
        criteria.addAll([
          'Symptoms rapidly worsen',
          'Difficulty breathing or chest tightness develops',
          'High fever (>39°C) that doesn’t respond to medication',
        ]);
        break;
      case 'emergency':
        criteria.addAll([
          'Call emergency services immediately',
          'Do not drive yourself — get a ride or ambulance',
          'Bring this triage result and any medications you take',
        ]);
        break;
    }
    // De-dup while preserving order.
    final seen = <String>{};
    return criteria.where((c) => seen.add(c)).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Hero visualizer — rotating dashed ring + solid green ring + check icon.
// ═══════════════════════════════════════════════════════════════════════════

class _HeroVisualizer extends StatelessWidget {
  final Color color;
  final IconData icon;
  final AnimationController rotationController;

  const _HeroVisualizer({
    required this.color,
    required this.icon,
    required this.rotationController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating 120px dashed ring (12s linear loop).
          AnimatedBuilder(
            animation: rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: rotationController.value * 2 * math.pi,
                child: child,
              );
            },
            child: CustomPaint(
              size: const Size(120, 120),
              painter: _DashedCirclePainter(
                color: color.withValues(alpha: 0.55),
                strokeWidth: 2,
                dashWidth: 5,
                gapWidth: 5,
              ),
            ),
          ),
          // Solid green ring (inner) with check_circle icon.
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }
}

/// Draws a circular dashed border. The dash/gap count is derived from the
/// circumference so the pattern stays even at any size.
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  const _DashedCirclePainter({
    required this.color,
    this.strokeWidth = 2,
    this.dashWidth = 5,
    this.gapWidth = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashWidth + gapWidth)).floor();
    if (dashCount == 0) return;

    // Adjust gap so the dashes distribute evenly around the circle.
    final adjustedGap =
        (circumference - dashCount * dashWidth) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashWidth + adjustedGap)) / radius;
      final sweepAngle = dashWidth / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashWidth != dashWidth ||
      old.gapWidth != gapWidth;
}

// ═══════════════════════════════════════════════════════════════════════════
// Pill chip (secondary-container bg).
// ═══════════════════════════════════════════════════════════════════════════

class _PillChip extends StatelessWidget {
  final String label;
  final bool isDark;

  const _PillChip({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary(isDark),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// "When to escalate" amber card.
// ═══════════════════════════════════════════════════════════════════════════

class _EscalationCard extends StatelessWidget {
  final bool isDark;
  final List<String> criteria;

  const _EscalationCard({required this.isDark, required this.criteria});

  // Amber palette (orange-50 bg, orange-700 text, orange-500 accent).
  // Tuned to remain legible in both light and dark themes.
  Color get _bg => isDark ? const Color(0xFF3A2A0E) : const Color(0xFFFFF3E0);
  Color get _border =>
      const Color(0xFFFFCC80).withValues(alpha: isDark ? 0.4 : 0.6);
  Color get _accent => const Color(0xFFFF9800);
  Color get _title => isDark ? const Color(0xFFFFCC80) : const Color(0xFFE65100);
  Color get _body => isDark ? const Color(0xFFEDD6B3) : const Color(0xFF5D4037);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _accent, size: 22),
              const SizedBox(width: 8),
              Text(
                'When to escalate',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...criteria.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(Icons.arrow_right, color: _accent, size: 16),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        c,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.5,
                          color: _body,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section title (preserved helper).
// ═══════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionTitle({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'ClashDisplay',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
