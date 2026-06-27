import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/weekly_insight.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/insights_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';

/// Weekly Insights screen — redesigned to match the Google Stitch UI design.
///
/// Layout (top → bottom) when insights exist:
///   1. Compact app bar with "VitalSeker" title + "Weekly Insights" subtitle +
///      date-range pill.
///   2. AI Summary hero card — brand gradient bg, "Pro Analysis" badge
///      (auto_awesome icon), "Your health this week" title, big score number
///      (ClashDisplay w800 white), "+X pts" trend pill, summary paragraph.
///   3. Trend Analysis — a simple CustomPaint line chart showing symptom
///      frequency over 4 weeks (gradient fill + Y-axis High/Avg/Low +
///      X-axis W1..W4 in JetBrains Mono 10px).
///   4. Personalized Focus — horizontally-scrollable tip cards with icon
///      containers (bedtime/water_drop/directions_run).
///   5. Generate New Insights — full-width gradient CTA.
///   6. Below the hero content, the existing per-week insight list cards are
///      preserved (each shows week range, trend, summary, stats, and
///      recommendations) — these are valuable when multiple weeks of data
///      exist.
///
/// Empty/pro-upsell + error states are preserved as the prior behavior.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final insightsAsync = ref.watch(weeklyInsightsProvider);
    final passportAsync = ref.watch(healthPassportProvider);
    // Whether the signed-in user is on a Pro plan. Used to differentiate the
    // "no insights yet" empty state from the "upgrade to Pro" upsell.
    final isProUser = ref.watch(isProUserProvider);

    final vitalScore = passportAsync.maybeWhen(
      data: (p) => p?.vitalScore ?? 0,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: insightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(weeklyInsightsProvider),
          isDark: isDark,
        ),
        data: (insights) {
          if (insights.isEmpty) {
            // Branch the empty-state on Pro status:
            //  - Pro user with no insights generated yet → "No insights yet"
            //    message + a "Generate Now" button (NOT the upgrade screen).
            //  - Non-Pro user with no insights → upsell to Pro (prior behavior).
            if (isProUser) {
              return _ProEmptyState(
                isDark: isDark,
                onGenerate: () async {
                  try {
                    await EdgeFunctionService().generateWeeklyInsights();
                  } catch (_) {
                    // The edge function is admin/CRON-triggered and may not be
                    // invokable directly from the client — that's OK, we still
                    // refresh the local provider so any newly-persisted rows
                    // surface.
                  }
                  if (context.mounted) {
                    ref.invalidate(weeklyInsightsProvider);
                  }
                },
              );
            }
            return _ProUpsellEmptyState(isDark: isDark);
          }

          // Most-recent week drives the hero card.
          final latest = insights.first;
          final trend = latest.trendAnalysis;

          // Build the 4-week symptom-frequency series from the available
          // insights. If we have fewer than 4 weeks, we pad deterministically
          // so the chart still shows a smooth 4-point curve.
          final series = _buildSymptomSeries(insights);

          return CustomScrollView(
            slivers: [
              _InsightsAppBar(isDark: isDark, latest: latest),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AiSummaryHeroCard(
                        isDark: isDark,
                        score: vitalScore,
                        scoreChange: latest.vitalScoreChange,
                        summary: latest.summary,
                        weekStart: latest.weekStart,
                        weekEnd: latest.weekEnd,
                      ),
                      const SizedBox(height: 24),
                      _TrendAnalysisSection(
                        isDark: isDark,
                        series: series,
                        totalLogs: trend.symptomFrequency,
                      ),
                      const SizedBox(height: 24),
                      _PersonalizedFocusSection(
                        isDark: isDark,
                        recommendations: latest.recommendations,
                      ),
                      const SizedBox(height: 24),
                      _GenerateInsightsCta(isDark: isDark),
                      const SizedBox(height: 28),
                      // ── Existing per-week insight data list ──
                      // Preserved so users with multiple weeks of data can
                      // drill into the structured trend/summary/stats.
                      Text(
                        l10n.weeklyBreakdown,
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(isDark),
                          letterSpacing: -0.01,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: insights
                            .map((i) => _InsightDataCard(
                                  insight: i,
                                  isDark: isDark,
                                ))
                            .toList(),
                      ),
                      const MedicalDisclaimerBanner(compact: true),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build a symptom-frequency series (most recent week last).
  ///
  /// PREVIOUSLY this method padded the series with fabricated "synthetic"
  /// data points when fewer than 4 weeks of data existed — a user with only
  /// 1 week of real data saw a 4-week curve where 3 of the 4 points were
  /// fabricated, with no visual indication that those weeks were synthetic.
  ///
  /// NOW: returns only the real data points. The chart renders fewer bars
  /// (or a single bar) when there's less data, which is honest.
  List<_WeekPoint> _buildSymptomSeries(List<WeeklyInsight> insights) {
    // Sort ascending by weekStart so W1 = oldest, W4 = newest.
    final sorted = [...insights]
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
    final points = sorted.map((i) => i.trendAnalysis.symptomFrequency.toDouble()).toList();
    // Keep only the last 4 weeks (most recent 4 data points).
    final last4 = points.length > 4 ? points.sublist(points.length - 4) : points;
    // Use dynamic labels based on actual count (W1, W2, W3, W4) — but only
    // for the weeks we actually have data for.
    return last4.asMap().entries.map((e) {
      return _WeekPoint(label: 'W${e.key + 1}', value: e.value);
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. App bar
// ═══════════════════════════════════════════════════════════════════════════

class _InsightsAppBar extends StatelessWidget {
  final bool isDark;
  final WeeklyInsight latest;
  const _InsightsAppBar({required this.isDark, required this.latest});

  String _formatDateRange(DateTime start, DateTime end) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SliverAppBar(
      toolbarHeight: 72,
      pinned: true,
      backgroundColor: AppColors.surface(isDark).withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: AppColors.primary(isDark),
        onPressed: () => context.pop(),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'VitalSeker',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary(isDark),
              height: 1.2,
              letterSpacing: -0.01,
            ),
          ),
          Row(
            children: [
              Text(
                l10n.weeklyInsights,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(isDark),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.subtleBackground(isDark),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatDateRange(latest.weekStart, latest.weekEnd).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary(isDark),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. AI Summary hero card
// ═══════════════════════════════════════════════════════════════════════════

class _AiSummaryHeroCard extends StatelessWidget {
  final bool isDark;
  final int score;
  final int scoreChange;
  final String summary;
  final DateTime weekStart;
  final DateTime weekEnd;
  const _AiSummaryHeroCard({
    required this.isDark,
    required this.score,
    required this.scoreChange,
    required this.summary,
    required this.weekStart,
    required this.weekEnd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isUp = scoreChange >= 0;
    final trendColor = isUp ? AppColors.success(isDark) : AppColors.error(isDark);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradientFor(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary(isDark).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative AI glow (top-right)
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pro Analysis badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.proAnalysis,
                          style: TextStyle(
                            fontFamily: 'DMSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.more_horiz,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                l10n.yourHealthThisWeek,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                  letterSpacing: -0.01,
                ),
              ),
              const SizedBox(height: 12),
              // Big score + trend pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUp ? Icons.trending_up : Icons.trending_down,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isUp
                                ? '+${l10n.scoreChangePts(scoreChange)}'
                                : l10n.scoreChangePts(scoreChange),
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Avoid unused var lint by surfacing the trend color in a
                  // tiny indicator dot next to the pill — keeps the design
                  // legible while still encoding direction with color.
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: trendColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Summary paragraph
              Text(
                summary,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. Trend Analysis — line chart
// ═══════════════════════════════════════════════════════════════════════════

class _TrendAnalysisSection extends StatelessWidget {
  final bool isDark;
  final List<_WeekPoint> series;
  final int totalLogs;
  const _TrendAnalysisSection({
    required this.isDark,
    required this.series,
    required this.totalLogs,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.trendAnalysis,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(isDark),
            height: 1.2,
            letterSpacing: -0.01,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.symptomFrequency4w,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary(isDark),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.show_chart,
                    size: 18,
                    color: AppColors.textTertiary(isDark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: _SymptomLineChart(
                  series: series,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SymptomLineChart extends StatelessWidget {
  final bool isDark;
  final List<_WeekPoint> series;
  const _SymptomLineChart({required this.isDark, required this.series});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        // Y-axis labels
        SizedBox(
          width: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [l10n.chartHigh, l10n.chartAvg, l10n.chartLow].map((label) {
              return Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary(isDark),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 4),
        // Chart canvas + X-axis
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _LineChartPainter(
                    series: series,
                    color: AppColors.primary(isDark),
                    gridColor: AppColors.outlineVariant(isDark),
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: series.map((p) {
                  return Text(
                    p.label,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary(isDark),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<_WeekPoint> series;
  final Color color;
  final Color gridColor;
  final bool isDark;
  _LineChartPainter({
    required this.series,
    required this.color,
    required this.gridColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final padY = h * 0.1;

    // Normalize values into [0, 1] within the series' own range so the curve
    // always spans the visible area.
    final values = series.map((p) => p.value).toList();
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final span = (maxV - minV).clamp(0.001, double.infinity);

    final n = series.length;
    Offset pointAt(int i) {
      final x = (n == 1) ? w / 2 : (w * i) / (n - 1);
      final norm = (values[i] - minV) / span; // 0..1
      // Invert: high value = top of chart (low y).
      final y = padY + (1 - norm) * (h - 2 * padY);
      return Offset(x, y);
    }

    final points = List.generate(n, pointAt);

    // Midline grid (dashed)
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final dashPath = Path();
    final midY = h / 2;
    const dashW = 4.0;
    const gapW = 4.0;
    double x = 0;
    while (x < w) {
      dashPath.moveTo(x, midY);
      dashPath.lineTo(x + dashW, midY);
      x += dashW + gapW;
    }
    canvas.drawPath(dashPath, gridPaint);

    // Build a smooth cubic path through the points.
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // Gradient fill under the curve.
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    // Line stroke.
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Data point dots.
    final dotPaint = Paint()..color = color;
    final ringPaint = Paint()
      ..color = isDark ? const Color(0xFF0C1A16) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (final p in points) {
      canvas.drawCircle(p, 3.2, dotPaint);
      canvas.drawCircle(p, 3.2, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.series != series ||
      oldDelegate.color != color ||
      oldDelegate.isDark != isDark;
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. Personalized Focus — horizontal tip cards
// ═══════════════════════════════════════════════════════════════════════════

class _PersonalizedFocusSection extends StatelessWidget {
  final bool isDark;
  final List<String> recommendations;
  const _PersonalizedFocusSection({
    required this.isDark,
    required this.recommendations,
  });

  static List<_TipDef> _tipCatalog(AppLocalizations l10n) => <_TipDef>[
    _TipDef(
      icon: Icons.bedtime,
      title: l10n.tipSleepTitle,
      body: l10n.tipSleepBody,
    ),
    _TipDef(
      icon: Icons.water_drop,
      title: l10n.tipHydrationTitle,
      body: l10n.tipHydrationBody,
    ),
    _TipDef(
      icon: Icons.directions_run,
      title: l10n.tipActivityTitle,
      body: l10n.tipActivityBody,
    ),
  ];

  List<_TipDef> _buildTips(AppLocalizations l10n) {
    final catalog = _tipCatalog(l10n);
    // Use real recommendations when we have them, falling back to the catalog.
    if (recommendations.length >= 3) {
      return List.generate(3, (i) {
        final t = catalog[i % catalog.length];
        return _TipDef(
          icon: t.icon,
          title: _titleFromRecommendation(recommendations[i]) ?? t.title,
          body: recommendations[i],
        );
      });
    }
    // Pad recommendations into the catalog slots.
    return List.generate(3, (i) {
      if (i < recommendations.length) {
        final t = catalog[i];
        return _TipDef(
          icon: t.icon,
          title: _titleFromRecommendation(recommendations[i]) ?? t.title,
          body: recommendations[i],
        );
      }
      return catalog[i];
    });
  }

  String? _titleFromRecommendation(String r) {
    // Try to grab the leading short clause as a title; fall back to null.
    final match = RegExp(r'^([^.!?\n]{4,40})').firstMatch(r);
    return match?.group(1)?.trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tips = _buildTips(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.personalizedFocus,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(isDark),
            height: 1.2,
            letterSpacing: -0.01,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            physics: const BouncingScrollPhysics(),
            itemCount: tips.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _TipCard(
              tip: tips[i],
              isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _TipDef {
  final IconData icon;
  final String title;
  final String body;
  const _TipDef({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _TipCard extends StatelessWidget {
  final _TipDef tip;
  final bool isDark;
  const _TipCard({required this.tip, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // ~80% of viewport width on mobile, capped to 300px on tablets.
    final cardWidth = (screenWidth - 40 - 12).clamp(260.0, 300.0);
    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight(isDark)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary(isDark).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.subtleBackground(isDark),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tip.icon,
              color: AppColors.primary(isDark),
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tip.title,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
              height: 1.25,
              letterSpacing: -0.01,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              tip.body,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary(isDark),
                height: 1.55,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. Generate New Insights — full-width gradient CTA
// ═══════════════════════════════════════════════════════════════════════════

class _GenerateInsightsCta extends ConsumerWidget {
  final bool isDark;
  const _GenerateInsightsCta({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Actually refresh the insights provider. Previously this only
            // showed a snackbar and never called ref.invalidate — making the
            // "Generate New Insights" button a complete no-op.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n.refreshingAiInsights,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                ),
                backgroundColor: AppColors.primary(isDark),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
            // Attempt to invoke the weekly-insights edge function. Failures
            // are tolerated (the function may be CRON-only); we still refresh
            // the local provider so any newly-persisted rows surface.
            try {
              await EdgeFunctionService().generateWeeklyInsights();
            } catch (_) {
              // Expected — the function may be CRON-gated. Continue.
            }
            if (context.mounted) {
              ref.invalidate(weeklyInsightsProvider);
            }
          },
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppColors.brandGradientFor(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary(isDark).withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.generateNewInsights,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.01,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. Per-week insight data card (existing list, lightly restyled)
// ═══════════════════════════════════════════════════════════════════════════

class _InsightDataCard extends StatelessWidget {
  final WeeklyInsight insight;
  final bool isDark;
  const _InsightDataCard({required this.insight, required this.isDark});

  Color _trendColor(String direction) {
    switch (direction.toLowerCase()) {
      case 'improving':
        return AppColors.urgencyLow;
      case 'stable':
        return isDark ? AppColors.darkInfo : AppColors.lightInfo;
      case 'declining':
        return AppColors.urgencyHigh;
      default:
        return AppColors.grey400;
    }
  }

  IconData _trendIcon(String direction) {
    switch (direction.toLowerCase()) {
      case 'improving':
        return Icons.trending_up;
      case 'stable':
        return Icons.trending_flat;
      case 'declining':
        return Icons.trending_down;
      default:
        return Icons.remove;
    }
  }

  Color _severityColor(int severity) {
    if (severity <= 3) return AppColors.urgencyLow;
    if (severity <= 6) return AppColors.urgencyMedium;
    return AppColors.urgencyHigh;
  }

  String _formatDateRange(DateTime start, DateTime end) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${start.day} ${months[start.month - 1]} - ${end.day} ${months[end.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trend = insight.trendAnalysis;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _formatDateRange(insight.weekStart, insight.weekEnd),
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(isDark),
                  ),
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
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.summary,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(
                label: l10n.symptoms,
                value: '${trend.symptomFrequency}',
                color: AppColors.secondary(isDark),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: l10n.avgSeverity,
                value: trend.avgSeverity.toStringAsFixed(1),
                color: _severityColor(trend.avgSeverity.round()),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: l10n.scoreChange,
                value:
                    '${insight.vitalScoreChange > 0 ? '+' : ''}${insight.vitalScoreChange}',
                color: insight.vitalScoreChange >= 0
                    ? AppColors.urgencyLow
                    : AppColors.urgencyEmergency,
                isDark: isDark,
              ),
            ],
          ),
          if (insight.recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.recommendations,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            ...insight.recommendations.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: AppColors.primary(isDark)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
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
                color: color.withValues(alpha: isDark ? 0.85 : 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Pro + empty state — "No insights yet" with a "Generate Now" CTA.
//
// Shown when the signed-in user is on a Pro plan but no weekly insight rows
// have been persisted yet (e.g. the Monday cron has not run, or the user
// just upgraded). This is intentionally NOT an upgrade upsell — the user is
// already Pro, so we offer them a way to trigger generation themselves.
// ═══════════════════════════════════════════════════════════════════════════

class _ProEmptyState extends StatefulWidget {
  final bool isDark;
  final Future<void> Function() onGenerate;
  const _ProEmptyState({required this.isDark, required this.onGenerate});

  @override
  State<_ProEmptyState> createState() => _ProEmptyStateState();
}

class _ProEmptyStateState extends State<_ProEmptyState> {
  bool _generating = false;

  Future<void> _handleGenerate() async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      await widget.onGenerate();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.refreshingAiInsights,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
            ),
            backgroundColor: AppColors.primary(widget.isDark),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back button row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: AppColors.primary(widget.isDark),
                  onPressed: () => context.pop(),
                ),
                Text(
                  'VitalSeker',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary(widget.isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.secondary(widget.isDark).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.secondary(widget.isDark),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noInsightsYet,
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textPrimary(widget.isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.checkBackMondayOrGenerate,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary(widget.isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(widget.isDark),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _generating ? null : _handleGenerate,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 20),
                label: Text(
                  _generating ? l10n.generating : l10n.generateNow,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty / Pro upsell state (preserved)
// ═══════════════════════════════════════════════════════════════════════════

class _ProUpsellEmptyState extends StatelessWidget {
  final bool isDark;
  const _ProUpsellEmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back button row
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: AppColors.primary(isDark),
                  onPressed: () => context.pop(),
                ),
                Text(
                  'VitalSeker',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.secondary(isDark).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.insights, color: AppColors.secondary(isDark), size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.weeklyInsights,
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.upgradeProInsightsFull,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.push(AppConfig.subscription),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradientFor(isDark),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary(isDark).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.proPlanMonthly(AppConfig.proPriceMonthly),
                            style: AppTextStyles.subheading1.copyWith(color: Colors.white),
                          ),
                          Text(
                            l10n.weeklyInsightsUnlimitedTriage,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.push(AppConfig.subscription),
              child: Text(
                l10n.viewAllPlans,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error state (preserved)
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isDark;
  const _ErrorState({required this.onRetry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: AppColors.textTertiary(isDark)),
              const SizedBox(height: 16),
              Text(
                l10n.couldNotLoadInsights,
                style: AppTextStyles.subheading1.copyWith(
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

class _WeekPoint {
  final String label;
  final double value;
  const _WeekPoint({required this.label, required this.value});

  @override
  bool operator ==(Object other) =>
      other is _WeekPoint && other.label == label && other.value == value;

  @override
  int get hashCode => Object.hash(label, value);
}
