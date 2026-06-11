import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/insights_provider.dart';
import '../../../shared/theme/app_colors.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final insightsAsync = ref.watch(weeklyInsightsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Insights')),
      body: insightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (insights) {
          if (insights.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.lightSecondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.insights, color: AppColors.lightSecondary, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Weekly Insights',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upgrade to Pro to unlock AI-powered weekly health insights. Get personalized recommendations and trend analysis every Monday.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: isDark ? AppColors.grey400 : AppColors.grey500,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pro Plan - \$${AppConfig.proPriceMonthly}/mo',
                                style: TextStyle(
                                  fontFamily: 'ClashDisplay',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Weekly insights, unlimited triage',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: insights.length,
            itemBuilder: (context, index) {
              final insight = insights[index];
              final trend = insight.trendAnalysis;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Week header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDateRange(insight.weekStart, insight.weekEnd),
                            style: TextStyle(
                              fontFamily: 'ClashDisplay',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.lightOnBackground,
                            ),
                          ),
                          if (trend.direction != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _trendColor(trend.direction!).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _trendIcon(trend.direction!),
                                    size: 14,
                                    color: _trendColor(trend.direction!),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    trend.direction!.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'DMSans',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _trendColor(trend.direction!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Summary
                      Text(
                        insight.summary,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: isDark ? AppColors.grey300 : AppColors.grey700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats
                      Row(
                        children: [
                          _StatChip(
                            label: 'Symptoms',
                            value: '${trend.symptomFrequency}',
                            color: AppColors.lightSecondary,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'Avg Severity',
                            value: trend.avgSeverity.toStringAsFixed(1),
                            color: _severityColor(trend.avgSeverity.round()),
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'Score Change',
                            value: '${insight.vitalScoreChange > 0 ? '+' : ''}${insight.vitalScoreChange}',
                            color: insight.vitalScoreChange >= 0 ? AppColors.urgencyLow : AppColors.urgencyEmergency,
                          ),
                        ],
                      ),

                      // Recommendations
                      if (insight.recommendations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Recommendations',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.grey300 : AppColors.grey700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...insight.recommendations.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle, size: 16, color: AppColors.lightPrimary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: isDark ? AppColors.grey400 : AppColors.grey600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _trendColor(String direction) {
    switch (direction) {
      case 'improving': return AppColors.urgencyLow;
      case 'stable': return AppColors.lightInfo;
      case 'declining': return AppColors.urgencyHigh;
      default: return AppColors.grey400;
    }
  }

  IconData _trendIcon(String direction) {
    switch (direction) {
      case 'improving': return Icons.trending_up;
      case 'stable': return Icons.trending_flat;
      case 'declining': return Icons.trending_down;
      default: return Icons.remove;
    }
  }

  Color _severityColor(int severity) {
    if (severity <= 3) return AppColors.urgencyLow;
    if (severity <= 6) return AppColors.urgencyMedium;
    return AppColors.urgencyHigh;
  }

  String _formatDateRange(DateTime start, DateTime end) {
    return '${start.day} ${_monthAbbr(start.month)} - ${end.day} ${_monthAbbr(end.month)}';
  }

  String _monthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
