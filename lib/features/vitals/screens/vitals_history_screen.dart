import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/vital.dart';
import '../../../core/providers/vitals_provider.dart';
import '../../../shared/theme/app_colors.dart';

class VitalsHistoryScreen extends ConsumerStatefulWidget {
  final VitalType? initialType;

  const VitalsHistoryScreen({this.initialType, super.key});

  @override
  ConsumerState<VitalsHistoryScreen> createState() => _VitalsHistoryScreenState();
}

class _VitalsHistoryScreenState extends ConsumerState<VitalsHistoryScreen> {
  late VitalType _selectedType;
  int _selectedRange = 1; // 0: 7D, 1: 1M, 2: 3M, 3: 6M, 4: 1Y

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
    final typeVitals = ref.watch(vitalsByTypeProvider(_selectedType));
    final filteredVitals = _filterByRange(typeVitals);

    return Scaffold(
      appBar: AppBar(title: const Text('Vitals History')),
      body: Column(
        children: [
          // Vital Type Dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2230) : AppColors.grey50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A2F3E) : AppColors.grey200,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<VitalType>(
                  value: _selectedType,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: isDark ? AppColors.grey400 : AppColors.grey500,
                  ),
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.lightOnBackground,
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
                              color: isDark ? AppColors.grey500 : AppColors.grey400,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (type) {
                    if (type != null) setState(() => _selectedType = type);
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
                    onTap: () => setState(() => _selectedRange = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _selectedType.color.withValues(alpha: 0.15)
                            : isDark
                                ? const Color(0xFF1E2230)
                                : AppColors.grey50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? _selectedType.color
                              : isDark
                                  ? const Color(0xFF2A2F3E)
                                  : AppColors.grey200,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        _rangeLabels[index],
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? _selectedType.color
                              : isDark
                                  ? AppColors.grey400
                                  : AppColors.grey500,
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
                ? _buildEmptyState(isDark)
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Line Chart
                        _VitalChart(
                          vitals: filteredVitals,
                          vitalType: _selectedType,
                          isDark: isDark,
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
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
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
            'No ${_selectedType.displayName} Data',
            style: TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightOnBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No readings found for the\nselected time period',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: isDark ? AppColors.grey400 : AppColors.grey500,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Line Chart ──────────────────────────────────────────────────────────────

class _VitalChart extends StatelessWidget {
  final List<Vital> vitals;
  final VitalType vitalType;
  final bool isDark;

  const _VitalChart({
    required this.vitals,
    required this.vitalType,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2F3E) : AppColors.grey100,
        ),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineChartPainter(
          vitals: vitals,
          color: vitalType.color,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<Vital> vitals;
  final Color color;
  final bool isDark;

  _LineChartPainter({
    required this.vitals,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (vitals.length < 2) {
      // Single point or no data
      final tp = TextPainter(
        text: TextSpan(
          text: vitals.isEmpty ? 'No data' : '1 reading',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: isDark ? AppColors.grey500 : AppColors.grey400,
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
      ..color = isDark ? const Color(0xFF1E2230) : Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(point, 4, dotBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.vitals != vitals || oldDelegate.color != color;
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

    final values = vitals.map((v) => v.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final latest = vitals.last.value;

    return Row(
      children: [
        _StatCard(
          label: 'Average',
          value: _formatValue(avg),
          unit: vitalType.unit,
          color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Min',
          value: _formatValue(min),
          unit: vitalType.unit,
          color: isDark ? AppColors.darkInfo : AppColors.lightInfo,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Max',
          value: _formatValue(max),
          unit: vitalType.unit,
          color: AppColors.urgencyMedium,
          isDark: isDark,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Latest',
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

  const _VitalsDataTable({
    required this.vitals,
    required this.vitalType,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2F3E) : AppColors.grey100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              'READINGS',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.grey500 : AppColors.grey400,
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
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
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
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Value',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Source',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...vitals.take(20).map((vital) => _DataRow(
                vital: vital,
                vitalType: vitalType,
                isDark: isDark,
              )),
          if (vitals.length > 20)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'Showing 20 of ${vitals.length} readings',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: isDark ? AppColors.grey500 : AppColors.grey400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final Vital vital;
  final VitalType vitalType;
  final bool isDark;

  const _DataRow({
    required this.vital,
    required this.vitalType,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                color: isDark ? AppColors.grey400 : AppColors.grey500,
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
                vital.source.substring(0, 1).toUpperCase(),
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
    );
  }

  Color get _sourceColor {
    switch (vital.source) {
      case 'manual':
        return isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
      case 'device':
        return isDark ? AppColors.darkInfo : AppColors.lightInfo;
      case 'import':
        return isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
      default:
        return AppColors.grey400;
    }
  }
}
