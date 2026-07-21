import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/models/vital.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/vitals_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';
import '../../../shared/widgets/pro_feature_gate.dart';

class VitalsHistoryScreen extends ConsumerStatefulWidget {
  final VitalType? initialType;

  const VitalsHistoryScreen({this.initialType, super.key});

  @override
  ConsumerState<VitalsHistoryScreen> createState() => _VitalsHistoryScreenState();
}

class _VitalsHistoryScreenState extends ConsumerState<VitalsHistoryScreen> {
  late VitalType _selectedType;
  int _selectedRange = 1; // 0: 7D, 1: 1M, 2: 3M, 3: 6M, 4: 1Y

  // FIX (audit M-3): pagination for the data table. The previous code used
  // vitals.take(20) with no way to see more. We now show 20 rows initially
  // and offer a "Show more" button that loads 20 at a time.
  int _displayCount = 20;

  static const _rangeLabels = ['7D', '1M', '3M', '6M', '1Y'];
  static const _rangeDays = [7, 30, 90, 180, 365];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? VitalType.heartRate;
  }

  List<Vital> _filterByRange(List<Vital> vitals) {
    final cutoff = DateTime.now().subtract(Duration(days: _rangeDays[_selectedRange]));
    return vitals.where((v) => v.recordedAt.isAfter(cutoff)).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final typeVitals = ref.watch(vitalsByTypeProvider(_selectedType));
    final filteredVitals = _filterByRange(typeVitals);

    // ── Pro gate ──
    // Vitals history is a Pro-only feature. If a free user deep-links here
    // directly, show the ProFeatureGate upsell instead of the history chart.
    final isPro = ref.watch(isProUserProvider);
    if (!isPro) {
      return const ProFeatureGate(
        featureName: 'Vitals Tracking',
        featureDescription: 'Track heart rate, blood pressure, temperature, and more. Visualize trends over time and share with your doctor.',
        featureIcon: Icons.monitor_heart,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vitalsHistoryTitle)),
      body: Column(
        children: [
          // Vital Type Dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.inputFill(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border(isDark),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<VitalType>(
                  dropdownColor: AppColors.surface(isDark),
                  value: _selectedType,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary(isDark),
                  ),
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                  items: VitalType.values.map((type) {
                    return DropdownMenuItem<VitalType>(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, size: 20, color: type.color),
                          const SizedBox(width: 10),
                          Text(type.displayName),
                          const SizedBox(width: 8),
                          Text(
                            type.unit,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textHint(isDark),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (type) {
                    if (type != null) setState(() {
                      _selectedType = type;
                      _displayCount = 20; // reset pagination on type change
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Date Range Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(_rangeLabels.length, (index) {
                final isSelected = _selectedRange == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedRange = index;
                      _displayCount = 20; // reset pagination on range change
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _selectedType.color.withValues(alpha: 0.15)
                            : AppColors.subtleBackground(isDark),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? _selectedType.color
                              : AppColors.border(isDark),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        _rangeLabel(l10n, index),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? _selectedType.color
                              : AppColors.textSecondary(isDark),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: filteredVitals.isEmpty
                ? _buildEmptyState(isDark, l10n)
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Line Chart
                        _VitalChart(
                          vitals: filteredVitals,
                          vitalType: _selectedType,
                          isDark: isDark,
                          emptyText: l10n.noReadingsForPeriod,
                          singleReadingText: l10n.singleReading,
                        ),
                        const SizedBox(height: 20),

                        // Statistics
                        _StatisticsRow(
                          vitals: filteredVitals,
                          vitalType: _selectedType,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),

                        // Data Table
                        _VitalsDataTable(
                          vitals: filteredVitals.reversed.toList(),
                          vitalType: _selectedType,
                          isDark: isDark,
                          displayCount: _displayCount,
                          onShowMore: () => setState(() => _displayCount += 20),
                        ),
                        const SizedBox(height: 16),
                        const MedicalDisclaimerBanner(compact: true),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _selectedType.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(_selectedType.icon, color: _selectedType.color, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noVitalTypeData(_selectedType.displayName),
            style: TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noReadingsForPeriod,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.textSecondary(isDark),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _rangeLabel(AppLocalizations l10n, int index) {
    switch (index) {
      case 0:
        return l10n.range7Days;
      case 1:
        return l10n.range1Month;
      case 2:
        return l10n.range3Months;
      case 3:
        return l10n.range6Months;
      case 4:
        return l10n.range1Year;
      default:
        return _rangeLabels[index];
    }
  }
}

// ─── Line Chart ──────────────────────────────────────────────────────────────

class _VitalChart extends StatelessWidget {
  final List<Vital> vitals;
  final VitalType vitalType;
  final bool isDark;
  final String emptyText;
  final String singleReadingText;

  const _VitalChart({
    required this.vitals,
    required this.vitalType,
    required this.isDark,
    required this.emptyText,
    required this.singleReadingText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderLight(isDark),
        ),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineChartPainter(
          vitals: vitals,
          color: vitalType.color,
          isDark: isDark,
          emptyText: emptyText,
          singleReadingText: singleReadingText,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<Vital> vitals;
  final Color color;
  final bool isDark;
  final String emptyText;
  final String singleReadingText;

  _LineChartPainter({
    required this.vitals,
    required this.color,
    required this.isDark,
    required this.emptyText,
    required this.singleReadingText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (vitals.length < 2) {
      // Single point or no data
      final tp = TextPainter(
        text: TextSpan(
          text: vitals.isEmpty ? emptyText : singleReadingText,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.textHint(isDark),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    final values = vitals.map((v) => v.value).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = maxVal - minVal;
    final padding = range == 0 ? 1.0 : range * 0.15;
    final effectiveMin = minVal - padding;
    final effectiveMax = maxVal + padding;
    final effectiveRange = effectiveMax - effectiveMin;

    // Chart area
    const leftPadding = 0.0;
    const rightPadding = 0.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height;

    // Build points
    final points = <Offset>[];
    for (int i = 0; i < vitals.length; i++) {
      final x = leftPadding + (i / (vitals.length - 1)) * chartWidth;
      final normalizedValue = (vitals[i].value - effectiveMin) / effectiveRange;
      final y = chartHeight - (normalizedValue * chartHeight);
      points.add(Offset(x, y));
    }

    // Gradient fill
    final fillPath = Path()..moveTo(points.first.dx, chartHeight);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));

    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      // Smooth curve using quadratic bezier
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      linePath.quadraticBezierTo(prev.dx, prev.dy, midX, (prev.dy + curr.dy) / 2);
    }
    linePath.lineTo(points.last.dx, points.last.dy);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotPaint = Paint()..color = color;
    final dotBorderPaint = Paint()
      ..color = AppColors.cardBackground(isDark)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(point, 4, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    // Compare the data that actually affects the chart rendering:
    // list length, color, theme, and each vital's id + value + recordedAt.
    // The Vital class doesn't override ==, so we compare by field values
    // to avoid repainting when the provider rebuilds with identical data.
    if (oldDelegate.vitals.length != vitals.length) return true;
    if (oldDelegate.color != color) return true;
    if (oldDelegate.isDark != isDark) return true;
    for (int i = 0; i < vitals.length; i++) {
      final old = oldDelegate.vitals[i];
      final cur = vitals[i];
      if (old.id != cur.id ||
          old.value != cur.value ||
          old.recordedAt != cur.recordedAt) {
        return true;
      }
    }
    return false;
  }
}

// ─── Statistics Row ──────────────────────────────────────────────────────────

class _StatisticsRow extends StatelessWidget {
  final List<Vital> vitals;
  final VitalType vitalType;
  final bool isDark;

  const _StatisticsRow({
    required this.vitals,
    required this.vitalType,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (vitals.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    final values = vitals.map((v) => v.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final latest = vitals.last.value;

    return Row(
      children: [
        _StatCard(
          label: l10n.average,
          value: _formatValue(avg),
          unit: vitalType.unit,
          color: AppColors.primary(isDark),
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: l10n.min,
          value: _formatValue(min),
          unit: vitalType.unit,
          color: isDark ? AppColors.darkInfo : AppColors.lightInfo,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: l10n.max,
          value: _formatValue(max),
          unit: vitalType.unit,
          color: AppColors.urgencyMedium,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: l10n.latest,
          value: _formatValue(latest),
          unit: vitalType.unit,
          color: vitalType.color,
          isDark: isDark,
        ),
      ],
    );
  }

  String _formatValue(double v) {
    return vitalType == VitalType.temperature ? v.toStringAsFixed(1) : v.round().toString();
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data Table ──────────────────────────────────────────────────────────────

class _VitalsDataTable extends StatelessWidget {
  final List<Vital> vitals;
  final VitalType vitalType;
  final bool isDark;
  final int displayCount;
  final VoidCallback onShowMore;

  const _VitalsDataTable({
    required this.vitals,
    required this.vitalType,
    required this.isDark,
    required this.displayCount,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderLight(isDark),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              l10n.readingsLabel,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint(isDark),
                letterSpacing: 1,
              ),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252A3A) : AppColors.grey50,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Time',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    l10n.value,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint(isDark),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    l10n.source,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint(isDark),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...vitals.take(displayCount).map((vital) => _DataRow(
                vital: vital,
                vitalType: vitalType,
                isDark: isDark,
              )),
          if (vitals.length > displayCount)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      l10n.showingReadingsCount(vitals.length),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textHint(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // FIX (audit M-3): "Show more" button to load 20 more rows.
                    TextButton.icon(
                      onPressed: onShowMore,
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: const Text('Show more'),
                    ),
                  ],
                ),
              ),
            )
          else if (vitals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  l10n.showingReadingsCount(vitals.length),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textHint(isDark),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends ConsumerWidget {
  final Vital vital;
  final VitalType vitalType;
  final bool isDark;

  const _DataRow({
    required this.vital,
    required this.vitalType,
    required this.isDark,
  });

  Future<bool> _deleteVital(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(vitalsProvider.notifier).deleteVital(vital.id);
      if (context.mounted) {
        AppSnackBar.success(context, l10n.vitalDeleted);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.errorFromException(context, l10n.failedToDeleteVital, e);
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Dismissible(
      key: ValueKey(vital.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.urgencyEmergency,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      // FIX: move the delete call INTO confirmDismiss so the row only
      // disappears if the delete actually succeeds. Previously, the
      // Dismissible removed the row visually BEFORE the network call,
      // and if the delete failed, the row was gone from the UI but
      // still in the DB — reappearing only on next refresh.
      confirmDismiss: (direction) async {
        // Confirm before deleting — prevents accidental data loss.
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.deleteVitalTitle),
            content: Text(l10n.deleteVitalConfirm(vital.displayWithUnit)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.urgencyEmergency,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed != true) return false;
        // Perform the actual delete — only dismiss if it succeeds.
        return _deleteVital(context, ref);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                '${vital.recordedAt.day.toString().padLeft(2, '0')}/${vital.recordedAt.month.toString().padLeft(2, '0')}/${vital.recordedAt.year}',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: isDark ? AppColors.grey300 : AppColors.grey700,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${vital.recordedAt.hour.toString().padLeft(2, '0')}:${vital.recordedAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: AppColors.textSecondary(isDark),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                vital.displayWithUnit,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: vitalType.color,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _sourceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (vital.source.isEmpty ? '?' : vital.source.substring(0, 1)).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _sourceColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIX (audit 3.5): normalize source to lowercase before matching to
  // handle case-sensitive storage (e.g. 'Manual' vs 'manual').
  Color get _sourceColor {
    switch (vital.source.toLowerCase()) {
      case 'manual':
        return AppColors.primary(isDark);
      case 'device':
        return isDark ? AppColors.darkInfo : AppColors.lightInfo;
      case 'import':
        return AppColors.secondary(isDark);
      default:
        return AppColors.grey400;
    }
  }
}
