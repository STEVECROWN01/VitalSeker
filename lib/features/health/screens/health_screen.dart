import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/symptom_log.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/symptom_log_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/urgency_badge.dart';
import '../../../shared/widgets/vital_score_ring.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vitalScore = ref.watch(vitalScoreProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final symptomLogsAsync = ref.watch(symptomLogsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.healthTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: l10n.weeklyInsightsTooltip,
            onPressed: () => context.go(AppConfig.insights),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Health Score Section ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary(isDark).withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          l10n.yourHealthScore,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        VitalScoreRing(
                          score: vitalScore,
                          size: 140,
                          showLabel: true,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _scoreDescription(vitalScore, l10n),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
                ],
              ),
            ),
          ),

          // ── Risk Factors Section ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.urgencyMedium, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.riskFactors,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  profileAsync.when(
                    data: (profile) {
                      final riskFactors = <Map<String, dynamic>>[];

                      if (profile?.allergies.isNotEmpty ?? false) {
                        riskFactors.add({
                          'label': l10n.allergyCount(profile!.allergies.length),
                          'color': AppColors.urgencyHigh,
                          'icon': Icons.warning_amber,
                        });
                      }
                      if (profile?.chronicConditions.isNotEmpty ?? false) {
                        riskFactors.add({
                          'label': l10n.chronicConditionCount(profile!.chronicConditions.length),
                          'color': AppColors.urgencyMedium,
                          'icon': Icons.medical_information,
                        });
                      }

                      if (riskFactors.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.urgencyLow.withValues(alpha: isDark ? 0.1 : 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.urgencyLow.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: AppColors.urgencyLow, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                l10n.noRiskFactors,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: AppColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: riskFactors.map((factor) {
                          final color = factor['color'] as Color;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(factor['icon'] as IconData,
                                    size: 16, color: color),
                                const SizedBox(width: 8),
                                Text(
                                  factor['label'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 40,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Recent Triage Results ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology_outlined,
                          color: AppColors.primary(isDark),
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.recentTriageResults,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  symptomLogsAsync.when(
                    data: (logs) {
                      if (logs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.subtleBackground(isDark),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border(isDark),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 32,
                                  color: AppColors.textHint(isDark)),
                              const SizedBox(height: 12),
                              Text(
                                l10n.noTriageResults,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: AppColors.textSecondary(isDark),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => context.go(AppConfig.triage),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l10n.startTriage),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary(isDark),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final recentLogs = logs.take(3).toList();
                      return Column(
                        children: recentLogs.map((log) {
                          return _TriageResultCard(
                            log: log,
                            isDark: isDark,
                          ).animate().fadeIn(duration: 300.ms);
                        }).toList(),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Recommended Actions ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: isDark ? AppColors.darkInfo : AppColors.lightInfo, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.recommendedActions,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._buildRecommendedActions(isDark, vitalScore, l10n),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── View Weekly Insights Link ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => context.go(AppConfig.insights),
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(l10n.viewWeeklyInsights),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary(isDark),
                    side: BorderSide(
                      color: AppColors.primary(isDark),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Medical Disclaimer (per Cahier des Charges Section 7) ──
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: MedicalDisclaimerBanner(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  String _scoreDescription(int score, AppLocalizations l10n) {
    if (score >= 80) return l10n.scoreDescriptionGreat;
    if (score >= 60) return l10n.scoreDescriptionGood;
    if (score >= 40) return l10n.scoreDescriptionModerate;
    if (score >= 20) return l10n.scoreDescriptionLow;
    return l10n.scoreDescriptionCritical;
  }

  List<Widget> _buildRecommendedActions(bool isDark, int vitalScore, AppLocalizations l10n) {
    final actions = <Map<String, dynamic>>[];

    if (vitalScore < 60) {
      actions.add({
        'icon': Icons.local_hospital_outlined,
        'title': l10n.actionScheduleCheckup,
        'description': l10n.actionScheduleCheckupDesc,
        'color': AppColors.urgencyMedium,
      });
    }

    actions.addAll([
      {
        'icon': Icons.monitor_heart_outlined,
        'title': l10n.actionLogVitals,
        'description': l10n.actionLogVitalsDesc,
        'color': AppColors.primary(isDark),
      },
      {
        'icon': Icons.psychology_outlined,
        'title': l10n.actionRunSymptomCheck,
        'description': l10n.actionRunSymptomCheckDesc,
        'color': AppColors.secondary(isDark),
      },
      {
        'icon': Icons.nightlight_outlined,
        'title': l10n.actionImproveSleep,
        'description': l10n.actionImproveSleepDesc,
        'color': isDark ? AppColors.darkInfo : AppColors.lightInfo,
      },
      {
        'icon': Icons.fitness_center_outlined,
        'title': l10n.actionStayActive,
        'description': l10n.actionStayActiveDesc,
        'color': AppColors.urgencyLow,
      },
    ]);
    return actions.map((action) {
      final color = action['color'] as Color;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action['icon'] as IconData, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action['title'] as String,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action['description'] as String,
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
              Icon(Icons.chevron_right,
                  color: AppColors.textHint(isDark), size: 20),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms);
    }).toList();
  }
}

class _TriageResultCard extends StatelessWidget {
  final SymptomLog log;
  final bool isDark;

  const _TriageResultCard({required this.log, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final urgencyLevel = log.triageResult?.urgencyLevel ?? 'medium';
    final timeAgo = _formatTimeAgo(log.loggedAt, l10n);

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
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _urgencyColor(urgencyLevel).withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _urgencyIcon(urgencyLevel),
                color: _urgencyColor(urgencyLevel),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.symptoms.take(3).join(', '),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textHint(isDark),
                    ),
                  ),
                ],
              ),
            ),
            UrgencyBadge(urgencyLevel: urgencyLevel, fontSize: 10),
          ],
        ),
      ),
    );
  }

  Color _urgencyColor(String level) {
    switch (level.toLowerCase()) {
      case 'low': return AppColors.urgencyLow;
      case 'medium': return AppColors.urgencyMedium;
      case 'high': return AppColors.urgencyHigh;
      case 'emergency': return AppColors.urgencyEmergency;
      default: return AppColors.grey400;
    }
  }

  IconData _urgencyIcon(String level) {
    switch (level.toLowerCase()) {
      case 'low': return Icons.check_circle_outline;
      case 'medium': return Icons.warning_amber_rounded;
      case 'high': return Icons.error_outline_rounded;
      case 'emergency': return Icons.emergency_rounded;
      default: return Icons.info_outline;
    }
  }

  String _formatTimeAgo(DateTime dt, AppLocalizations l10n) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return l10n.weeksAgo((diff.inDays / 7).floor());
  }
}
