import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/symptom_log.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/symptom_log_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/urgency_badge.dart';
import '../../../shared/widgets/vital_score_ring.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Weekly Insights',
            onPressed: () => context.push(AppConfig.insights),
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
                          color: AppColors.lightPrimary.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Health Score',
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
                          _scoreDescription(vitalScore),
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
                        'Risk Factors',
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
                      final riskFactors = <Map<String, dynamic>>[];

                      if (profile?.allergies.isNotEmpty ?? false) {
                        riskFactors.add({
                          'label': '${profile!.allergies.length} Allerg${profile.allergies.length == 1 ? 'y' : 'ies'}',
                          'color': AppColors.urgencyHigh,
                          'icon': Icons.warning_amber,
                        });
                      }
                      if (profile?.chronicConditions.isNotEmpty ?? false) {
                        riskFactors.add({
                          'label': '${profile!.chronicConditions.length} Chronic Condition${profile.chronicConditions.length == 1 ? '' : 's'}',
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
                                'No risk factors identified',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: isDark ? AppColors.grey400 : AppColors.grey500,
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
                          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Recent Triage Results',
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
                  symptomLogsAsync.when(
                    data: (logs) {
                      if (logs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.grey50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2A2F3E) : AppColors.grey200,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 32,
                                  color: isDark ? AppColors.grey500 : AppColors.grey400),
                              const SizedBox(height: 12),
                              Text(
                                'No triage results yet',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: isDark ? AppColors.grey400 : AppColors.grey500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => context.push(AppConfig.triage),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Start Triage'),
                                style: TextButton.styleFrom(
                                  foregroundColor: isDark
                                      ? AppColors.darkPrimary
                                      : AppColors.lightPrimary,
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
                          color: AppColors.lightInfo, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Recommended Actions',
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
                  ..._buildRecommendedActions(isDark, vitalScore),
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
                  onPressed: () => context.push(AppConfig.insights),
                  icon: const Icon(Icons.insights_outlined),
                  label: const Text('View Weekly Insights'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    side: BorderSide(
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
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

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  String _scoreDescription(int score) {
    if (score >= 80) return 'Your health metrics are looking great! Keep it up.';
    if (score >= 60) return 'Good progress. A few areas could use attention.';
    if (score >= 40) return 'Some health metrics need improvement. Consider our recommendations.';
    if (score >= 20) return 'Several areas need attention. Please consult a healthcare provider.';
    return 'Immediate attention recommended. Please seek medical advice.';
  }

  List<Widget> _buildRecommendedActions(bool isDark, int vitalScore) {
    final actions = <Map<String, dynamic>>[];

    if (vitalScore < 60) {
      actions.add({
        'icon': Icons.local_hospital_outlined,
        'title': 'Schedule a Check-up',
        'description': 'Your health score suggests it\'s time for a medical review.',
        'color': AppColors.urgencyMedium,
      });
    }

    actions.addAll([
      {
        'icon': Icons.monitor_heart_outlined,
        'title': 'Log Your Vitals',
        'description': 'Track your blood pressure, heart rate, and other key metrics.',
        'color': AppColors.lightPrimary,
      },
      {
        'icon': Icons.psychology_outlined,
        'title': 'Run a Symptom Check',
        'description': 'Use AI triage to assess any symptoms you\'re experiencing.',
        'color': AppColors.lightSecondary,
      },
      {
        'icon': Icons.nightlight_outlined,
        'title': 'Improve Sleep Quality',
        'description': 'Quality sleep is essential for recovery and immune function.',
        'color': AppColors.lightInfo,
      },
      {
        'icon': Icons.fitness_center_outlined,
        'title': 'Stay Active',
        'description': 'Regular exercise helps maintain cardiovascular health.',
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
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action['description'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isDark ? AppColors.grey400 : AppColors.grey500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: isDark ? AppColors.grey500 : AppColors.grey400, size: 20),
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
    final urgencyLevel = log.triageResult?.urgencyLevel ?? 'medium';
    final timeAgo = _formatTimeAgo(log.loggedAt);

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
                      color: isDark ? Colors.white : AppColors.lightOnBackground,
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
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
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

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
