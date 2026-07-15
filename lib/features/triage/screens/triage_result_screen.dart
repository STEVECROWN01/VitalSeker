import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/pro_feature_gate.dart';
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
class TriageResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> triageData;

  const TriageResultScreen({super.key, required this.triageData});

  @override
  ConsumerState<TriageResultScreen> createState() => _TriageResultScreenState();
}

class _TriageResultScreenState extends ConsumerState<TriageResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  bool _isSaving = false;

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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPro = ref.watch(isProUserProvider);

    // Pro gate — triage results are Pro-only
    // Free users complete the 5-step triage but see a gate instead of results
    if (!isPro) {
      return const ProFeatureGate(
        featureName: 'AI Triage Results',
        featureDescription: 'Your AI triage analysis has been completed. Subscribe to VitalSeker Pro to view your detailed results, including AI analysis, possible conditions, recommended actions, and emergency red flags.',
        featureIcon: Icons.healing,
      );
    }

    final triage =
        widget.triageData['triage'] as Map<String, dynamic>? ?? widget.triageData;
    final urgencyLevel = triage['urgency_level'] as String? ??
        triage['urgency'] as String? ?? 'medium';
    // JSON numbers may decode as int or double — use num?.toInt() to be safe.
    final urgencyScore = (triage['urgency_score'] as num?)?.toInt() ?? 50;
    final seekCare = triage['seek_care'] as String? ??
        // FIX (audit H-9, 8.4): map 'critical' and 'red' to emergency.
        // The previous mapping missed 'critical' (a plausible AI return),
        // sending critical emergencies to 'schedule-appointment'.
        // Also: unknown urgency levels default to 'urgent-care' (conservative)
        // instead of 'schedule-appointment' — better to over-triage than
        // under-triage for a health app.
        (urgencyLevel == 'red' || urgencyLevel == 'emergency' || urgencyLevel == 'critical' ? 'emergency'
        : urgencyLevel == 'yellow' || urgencyLevel == 'medium' || urgencyLevel == 'high' ? 'urgent-care'
        : urgencyLevel == 'green' || urgencyLevel == 'low' ? 'self-care'
        : 'urgent-care'); // conservative default for unknown

    // ── Full result fields from the edge function ──
    // The edge function returns: urgency, urgency_label, possible_areas,
    // recommended_action, explanation, when_to_escalate, disclaimer,
    // clarifying_question. Display ALL of these so the user gets a complete
    // medical result, not just "visit urgent care + urgency score".
    final urgencyLabel = triage['urgency_label'] as String? ?? '';
    final possibleAreas =
        (triage['possible_areas'] as List<dynamic>? ?? []).cast<String>();
    final recommendedAction = triage['recommended_action'] as String? ?? '';
    final explanation = triage['explanation'] as String? ?? '';
    final whenToEscalate = triage['when_to_escalate'] as String? ?? '';

    final recommendations =
        <String>[...(triage['recommendations'] as List<dynamic>? ?? const []).cast<String>()];
    final redFlags =
        (triage['red_flags'] as List<dynamic>? ?? []).cast<String>();
    final possibleConditions = triage['possible_conditions'] as List<dynamic>? ?? [];
    final disclaimer = triage['disclaimer'] as String? ?? l10n.triageDisclaimer;
    final followUpQuestions =
        (triage['follow_up_questions'] as List<dynamic>? ?? []).cast<String>();

    // If recommended_action exists, add it as the first recommendation
    if (recommendedAction.isNotEmpty && !recommendations.contains(recommendedAction)) {
      recommendations.insert(0, recommendedAction);
    }
    // If when_to_escalate exists, add it to red flags
    if (whenToEscalate.isNotEmpty && !redFlags.contains(whenToEscalate)) {
      redFlags.add(whenToEscalate);
    }

    final heroColor = _urgencyColor(urgencyLevel);
    final headline = _seekCareHeadline(seekCare, l10n);

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
      if (possibleConditions.isEmpty) _seekCareLabel(seekCare, l10n),
    ];

    return Scaffold(
      // AppBar back arrow uses the "intelligent back" pattern: pop back to
      // whatever screen the user came from (triage wizard, history list,
      // chat, etc.) if there is a previous route on the stack. Only fall
      // back to the dashboard if the stack is empty (deep-link / cold
      // start). This matches the user expectation that the back arrow
      // returns to "the screen I just came from", not a hardcoded screen.
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(AppConfig.dashboard);
            }
          },
        ),
        title: Text(l10n.triageResults),
      ),
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
                    l10n.urgencyScoreCaption(urgencyScore),
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

            // ── 4b. AI Explanation (what might be happening) ──
            if (explanation.isNotEmpty) ...[
              _SectionTitle(
                title: 'AI Analysis',
                icon: Icons.psychology_outlined,
                color: AppColors.primary(isDark),
              ),
              const SizedBox(height: 8),
              Card(
                color: AppColors.primaryContainer(isDark),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    explanation,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.6,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── 4c. Possible areas (what body systems might be involved) ──
            if (possibleAreas.isNotEmpty) ...[
              _SectionTitle(
                title: 'Possible Areas',
                icon: Icons.medical_information_outlined,
                color: AppColors.info(isDark),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: possibleAreas
                    .map((area) => Chip(
                          label: Text(area),
                          backgroundColor: AppColors.info(isDark)
                              .withValues(alpha: isDark ? 0.15 : 0.10),
                          labelStyle: TextStyle(
                            color: AppColors.textPrimary(isDark),
                            fontSize: 12,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            // ── 4d. Recommended Action ──
            if (recommendedAction.isNotEmpty) ...[
              _SectionTitle(
                title: 'Recommended Action',
                icon: Icons.medical_services_outlined,
                color: AppColors.success(isDark),
              ),
              const SizedBox(height: 8),
              Card(
                color: AppColors.success(isDark).withValues(alpha: isDark ? 0.12 : 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.success(isDark), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          recommendedAction,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── 4e. Urgency Label (short description like "Surveillance à domicile") ──
            if (urgencyLabel.isNotEmpty) ...[
              _SectionTitle(
                title: 'Assessment',
                icon: Icons.verified_outlined,
                color: heroColor,
              ),
              const SizedBox(height: 8),
              Card(
                color: heroColor.withValues(alpha: isDark ? 0.12 : 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    urgencyLabel,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── 5. "When to escalate" amber card ──
            _EscalationCard(
              isDark: isDark,
              criteria: _escalationCriteria(urgencyLevel, redFlags, l10n),
            ),
            const SizedBox(height: 24),

            // ── 6a. Red Flags ──
            if (redFlags.isNotEmpty) ...[
              _SectionTitle(
                title: l10n.redFlags,
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
                title: l10n.recommendations,
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
                title: l10n.possibleConditions,
                icon: Icons.medical_information_outlined,
                color: AppColors.secondary(isDark),
              ),
              const SizedBox(height: 8),
              ...possibleConditions.map((condition) {
                // Defensive cast: the AI may return either Map or bare String.
                // The defensive path on line ~89 handles both; this must too.
                final c = condition is Map<String, dynamic>
                    ? condition
                    : <String, dynamic>{'name': condition.toString()};
                final probability = (c['probability'] ?? 'low').toString();
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
                title: l10n.followUpQuestions,
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

            // ── 6.5. Emergency quick-dial (audit H-3) ──
            // When the triage result indicates emergency or urgent care,
            // show a prominent "Call 112 / 911 Now" button so the user
            // can dial emergency services with one tap without leaving
            // the app. The button uses tel: URI launch (same pattern as
            // the SOS screen). For non-emergency results, this button is
            // hidden.
            if (seekCare == 'emergency' || seekCare == 'urgent-care' ||
                urgencyLevel == 'red' || urgencyLevel == 'critical') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _callEmergencyServices(),
                  icon: const Icon(Icons.phone_in_talk, size: 22),
                  label: Text(
                    // Use 112 (universal EU) as the default — most users
                    // who see this will be in regions where 112 works.
                    // The SOS screen also has 911 and 15 quick-dial buttons.
                    'Call 112 / 911 Now',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.urgencyEmergency,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── 7. Action buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _saveToPassport,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: Text(_isSaving ? l10n.saving : l10n.saveToPassport),
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
                    onPressed: () => SharePlus.instance.share(ShareParams(
                      text: 'My VitalSeker triage result:\n'
                      'Urgency: ${urgencyLevel.toUpperCase()} ($urgencyScore/100)\n'
                      'Recommendation: ${_seekCareLabel(seekCare, l10n)}\n\n'
                      '$disclaimer',
                      title: 'VitalSeker Triage Result',
                    )),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(l10n.shareResult),
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

  /// Launch the phone dialer with 112 (universal EU emergency number).
  ///
  /// Audit H-3 fix: previously, the triage result screen showed "Emergency
  /// Care Now" as a headline but provided no quick-dial button — the user
  /// had to leave the app, open the phone app, and dial manually. In a
  /// real emergency this delay is dangerous.
  ///
  /// We use 112 as the default because it's the universal EU emergency
  /// number and also works on most mobile networks worldwide (GSM phones
  /// route 112 to the local emergency number even without a SIM). The SOS
  /// screen has additional quick-dial buttons for 911 (US) and 15 (FR SAMU).
  Future<void> _callEmergencyServices() async {
    final uri = Uri(scheme: 'tel', path: '112');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          AppSnackBar.error(
            context,
            'Could not open the phone dialer. Please call 112 or your local '
            'emergency number manually.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'Could not open the phone dialer. Please call 112 or your local '
          'emergency number manually.',
        );
      }
    }
  }

  /// Persist the current triage result to the user's health passport.
  ///
  /// Updates `last_assessment_date` to now and nudges `vital_score` based on
  /// the triage urgency score (0–100, higher = more urgent). Higher urgency
  /// lowers the vital score; lower urgency slightly raises it.
  Future<void> _saveToPassport() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) {
        AppSnackBar.error(
            context, 'You must be signed in to save to your passport.');
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Prefer the cached passport; fall back to awaiting the future if it
      // hasn't resolved yet.
      final passportAsync = ref.read(healthPassportProvider);
      final passport = passportAsync.valueOrNull ??
          await ref.read(healthPassportProvider.future);

      if (passport == null) {
        // No passport exists — create one automatically instead of showing
        // an error. This is the correct UX: the user just did a triage and
        // wants to save the result; we should create the passport for them.
        try {
          await ref.read(databaseServiceProvider).createHealthPassport({
            'user_id': user.id,
            'last_assessment_date': DateTime.now().toIso8601String(),
            'vital_score': 75, // Default starting score
          });
          ref.invalidate(healthPassportProvider);
          if (mounted) {
            AppSnackBar.success(
              context,
              'Health passport created! Saving triage result...',
            );
            // Retry the save now that the passport exists
            await Future.delayed(const Duration(milliseconds: 500));
            await _saveToPassport();
          }
        } catch (e) {
          if (mounted) {
            AppSnackBar.error(
              context,
              'Could not create health passport. Please try again.',
            );
          }
        }
        return;
      }

      final triage = widget.triageData['triage'] as Map<String, dynamic>? ??
          widget.triageData;
      final urgencyScore = (triage['urgency_score'] as num?)?.toInt() ?? 50;
      // urgency_score: 0–100, higher = more urgent.
      // vital_score:   0–100, higher = better health.
      // delta is clamped to [−15, +10] so a single triage session never swings
      // the score by more than 15 points.
      final delta = ((50 - urgencyScore) / 5).round().clamp(-15, 10);
      final newVitalScore = (passport.vitalScore + delta).clamp(0, 100);

      await ref.read(databaseServiceProvider).updateHealthPassport(
            passport.id,
            {
              'last_assessment_date': DateTime.now().toIso8601String(),
              'vital_score': newVitalScore,
            },
          );

      // Refresh the cached passport so downstream UI (vital score ring, etc.)
      // reflects the new values immediately.
      ref.invalidate(healthPassportProvider);

      if (mounted) {
        AppSnackBar.success(
            context, 'Triage result saved to your health passport!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.errorFromException(
          context,
          'Failed to save triage result. Please try again.',
          e,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _urgencyColor(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return AppColors.urgencyLow;
      case 'medium':
        return AppColors.urgencyMedium;
      case 'high':
        return AppColors.urgencyHigh;
      case 'emergency':
      case 'critical':
      case 'red':
        return AppColors.urgencyEmergency;
      default:
        // FIX (audit 8.10): default to HIGH (not medium) for unrecognized
        // urgency levels — conservative. Better to over-alert than
        // under-alert for a health app.
        return AppColors.urgencyHigh;
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
  //
  // FIX (audit H-9): the default case previously returned `monitorAtHome`
  // (self-care) for unknown seek_care values. For a health app, defaulting
  // to self-care for an unknown urgency is unsafe — the user might actually
  // need urgent care. The default is now `seeDoctorSoon` (schedule
  // appointment) — conservative but not alarmist.
  String _seekCareHeadline(String care, AppLocalizations l10n) {
    switch (care) {
      case 'self-care':
        return l10n.monitorAtHome;
      case 'schedule-appointment':
        return l10n.seeDoctorSoon;
      case 'urgent-care':
        return l10n.visitUrgentCare;
      case 'emergency':
        return l10n.emergencyCareNow;
      default:
        return l10n.seeDoctorSoon; // conservative default for unknown
    }
  }

  String _seekCareLabel(String care, AppLocalizations l10n) {
    switch (care) {
      case 'self-care':
        return l10n.selfCareRecommended;
      case 'schedule-appointment':
        return l10n.scheduleAppointmentCare;
      case 'urgent-care':
        return l10n.visitUrgentCare;
      case 'emergency':
        return l10n.seekEmergencyCare;
      default:
        return l10n.consultHealthcareProvider;
    }
  }

  /// Build the escalation-criteria list for the amber card. Uses red flags as
  /// the primary source, then appends per-urgency static advice so the card is
  /// never empty.
  List<String> _escalationCriteria(
      String urgencyLevel, List<String> redFlags, AppLocalizations l10n) {
    final criteria = <String>[];
    if (redFlags.isNotEmpty) {
      criteria.addAll(redFlags.take(3));
    }
    switch (urgencyLevel.toLowerCase()) {
      case 'low':
        criteria.addAll([
          l10n.escalateLow1,
          l10n.escalateLow2,
          l10n.escalateLow3,
        ]);
        break;
      case 'medium':
        criteria.addAll([
          l10n.escalateMedium1,
          l10n.escalateMedium2,
          l10n.escalateMedium3,
        ]);
        break;
      case 'high':
        criteria.addAll([
          l10n.escalateHigh1,
          l10n.escalateHigh2,
          l10n.escalateHigh3,
        ]);
        break;
      case 'emergency':
        criteria.addAll([
          l10n.escalateEmergency1,
          l10n.escalateEmergency2,
          l10n.escalateEmergency3,
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
    final l10n = AppLocalizations.of(context)!;
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
                l10n.whenToEscalate,
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
