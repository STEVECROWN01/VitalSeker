import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/symptom_log_provider.dart';
import '../../../core/models/symptom_log.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/urgency_badge.dart';

/// Symptom History Screen — redesigned to match the Google Stitch UI design.
///
/// Layout (top → bottom):
///   1. Header row — "History" title + "N THIS MONTH" pill badge.
///   2. Search bar — 52px tall, rounded-full, "Search logs..." placeholder.
///   3. Filter chips — All / Green / Yellow / Red (rounded-full with colored
///      dots). Tapping a chip filters the timeline by urgency level.
///   4. Timeline — dashed vertical connector line + colored dots with glow
///      (BoxShadow blurRadius=12). Each item shows:
///        - "TODAY • 08:42 AM" relative date stamp (JetBrainsMono)
///          instead of the old "DD/MM/YYYY" format.
///        - Symptom summary + UrgencyBadge.
///        - ExpansionTile with all symptoms, body regions, duration, AI
///          recommendation, "View Full Triage Result" button, notes.
///   5. "Export 30-day Report (Pro)" button — full-width, rounded-full,
///      bg-inverse-surface.
///
/// Preserved from the prior version: RefreshIndicator, ExpansionTile detail
/// view, "View Full Triage Result" navigation via go_router's `extra`.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  _Filter _activeFilter = _Filter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsAsync = ref.watch(symptomLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Symptom History')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(symptomLogsProvider);
          await ref.read(symptomLogsProvider.future);
        },
        color: AppColors.primary(isDark),
        // Always scrollable so pull-to-refresh works on empty / error states.
        child: logsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.4),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: AppColors.urgencyEmergency),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load history',
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(symptomLogsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                            size: 80, color: AppColors.textTertiary(isDark)),
                        const SizedBox(height: 16),
                        Text(
                          'No History Yet',
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary(isDark),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your symptom logs will appear here',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: AppColors.textHint(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final now = DateTime.now();
            final thisMonthCount = logs
                .where((l) =>
                    l.loggedAt.year == now.year &&
                    l.loggedAt.month == now.month)
                .length;

            // Apply search + filter to derive the visible logs.
            final searchQuery = _searchController.text.trim().toLowerCase();
            final visibleLogs = _applyFilter(logs, _activeFilter, searchQuery);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. Header row: title + "N THIS MONTH" badge ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'History',
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.02,
                                color: AppColors.textPrimary(isDark),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer(isDark),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$thisMonthCount THIS MONTH',
                                style: TextStyle(
                                  fontFamily: 'DMSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.05,
                                  color: AppColors.primary(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ── 2. Search bar ──
                        _SearchBar(
                          controller: _searchController,
                          isDark: isDark,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        // ── 3. Filter chips ──
                        _FilterChipsRow(
                          activeFilter: _activeFilter,
                          isDark: isDark,
                          onSelected: (f) => setState(() => _activeFilter = f),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                // ── 4. Timeline ──
                if (visibleLogs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 56,
                              color: AppColors.textTertiary(isDark)),
                          const SizedBox(height: 12),
                          Text(
                            'No logs match your filters',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary(isDark),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try a different search or filter.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textHint(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.builder(
                      itemCount: visibleLogs.length,
                      itemBuilder: (context, index) {
                        final log = visibleLogs[index];
                        final triageResult = log.triageResult;
                        final urgencyLevel =
                            triageResult?.urgencyLevel ?? 'medium';
                        return _TimelineItem(
                          log: log,
                          isDark: isDark,
                          isLast: index == visibleLogs.length - 1,
                          urgencyLevel: urgencyLevel,
                          triageResult: triageResult,
                        );
                      },
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(
                      children: [
                        // ── 5. Export 30-day Report (Pro) button ──
                        _ExportReportButton(isDark: isDark),
                        const SizedBox(height: 16),
                        Text(
                          'Powered by Keter Marketing',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            height: 1.5,
                            letterSpacing: 0.1,
                            color: AppColors.textTertiary(isDark),
                          ),
                        ),
                        const SizedBox(height: 80), // bottom-nav clearance
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Apply the active filter + search query to the full log list.
  List<SymptomLog> _applyFilter(
      List<SymptomLog> logs, _Filter filter, String search) {
    return logs.where((log) {
      final urgency = log.triageResult?.urgencyLevel.toLowerCase() ?? 'medium';
      switch (filter) {
        case _Filter.green:
          if (urgency != 'low') return false;
          break;
        case _Filter.yellow:
          if (urgency != 'medium') return false;
          break;
        case _Filter.red:
          if (urgency != 'high' && urgency != 'emergency') return false;
          break;
        case _Filter.all:
          break;
      }
      if (search.isNotEmpty) {
        final haystack = [
          ...log.symptoms,
          ...log.bodyRegions,
          if (log.notes != null && log.notes!.isNotEmpty) log.notes!,
          if (log.duration != null && log.duration!.isNotEmpty) log.duration!,
        ].join(' ').toLowerCase();
        if (!haystack.contains(search)) return false;
      }
      return true;
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Filter enum.
// ═══════════════════════════════════════════════════════════════════════════

enum _Filter { all, green, yellow, red }

// ═══════════════════════════════════════════════════════════════════════════
// Search bar (52px tall, rounded-full).
// ═══════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textPrimary(isDark),
        ),
        decoration: InputDecoration(
          hintText: 'Search logs...',
          hintStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.textHint(isDark),
          ),
          prefixIcon: Icon(Icons.search,
              size: 20, color: AppColors.textTertiary(isDark)),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.close,
                    size: 18, color: AppColors.textTertiary(isDark)),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                splashRadius: 16,
              );
            },
          ),
          filled: true,
          fillColor: AppColors.inputFill(isDark),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(26),
            borderSide: BorderSide(
                color: AppColors.primary(isDark).withValues(alpha: 0.4),
                width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Filter chips row — All / Green / Yellow / Red with colored dots.
// ═══════════════════════════════════════════════════════════════════════════

class _FilterChipsRow extends StatelessWidget {
  final _Filter activeFilter;
  final bool isDark;
  final ValueChanged<_Filter> onSelected;

  const _FilterChipsRow({
    required this.activeFilter,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: 'All',
          dotColor: AppColors.textTertiary(isDark),
          selected: activeFilter == _Filter.all,
          isDark: isDark,
          onTap: () => onSelected(_Filter.all),
        ),
        _FilterChip(
          label: 'Green',
          dotColor: AppColors.urgencyLow,
          selected: activeFilter == _Filter.green,
          isDark: isDark,
          onTap: () => onSelected(_Filter.green),
        ),
        _FilterChip(
          label: 'Yellow',
          dotColor: AppColors.urgencyMedium,
          selected: activeFilter == _Filter.yellow,
          isDark: isDark,
          onTap: () => onSelected(_Filter.yellow),
        ),
        _FilterChip(
          label: 'Red',
          dotColor: AppColors.urgencyHigh,
          selected: activeFilter == _Filter.red,
          isDark: isDark,
          onTap: () => onSelected(_Filter.red),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer(isDark)
              : AppColors.subtleBackground(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary(isDark).withValues(alpha: 0.4)
                : AppColors.borderLight(isDark),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.45),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.05,
                color: selected
                    ? AppColors.primary(isDark)
                    : AppColors.textSecondary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Timeline item — dashed connector + glowing dot + ExpansionTile card.
// ═══════════════════════════════════════════════════════════════════════════

class _TimelineItem extends StatelessWidget {
  final SymptomLog log;
  final bool isDark;
  final bool isLast;
  final String urgencyLevel;
  final TriageResult? triageResult;

  const _TimelineItem({
    required this.log,
    required this.isDark,
    required this.isLast,
    required this.urgencyLevel,
    required this.triageResult,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = _urgencyColor(urgencyLevel, isDark);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left timeline column (32px wide).
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 22),
                _GlowingDot(color: dotColor),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4, bottom: -10),
                      child: CustomPaint(
                        painter: _DashedLinePainter(
                          color: AppColors.border(isDark),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right card.
          Expanded(child: _buildCard(context)),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight(isDark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.textSecondary(isDark),
        collapsedIconColor: AppColors.textSecondary(isDark),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _severityColor(log.severity).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.healing,
              color: _severityColor(log.severity), size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Relative date stamp (JetBrainsMono).
            Text(
              _formatRelativeDate(log.loggedAt),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: AppColors.textTertiary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    log.symptoms.take(3).join(', '),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                UrgencyBadge(urgencyLevel: urgencyLevel),
              ],
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Severity: ${log.severity}/10',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.textSecondary(isDark),
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                // All symptoms
                Text(
                  'All Symptoms',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: log.symptoms
                      .map((s) => Chip(
                            label: Text(s, style: const TextStyle(fontSize: 11)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
                if (log.bodyRegions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Body Regions: ${log.bodyRegions.join(', ')}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
                if (log.duration != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Duration: ${log.duration}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                ],
                if (triageResult != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'AI Recommendation: ${triageResult!.seekCare.replaceAll('-', ' ').toUpperCase()}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _urgencyColor(triageResult!.urgencyLevel, isDark),
                    ),
                  ),
                  if (triageResult!.recommendations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...triageResult!.recommendations.take(3).map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('  • ',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: AppColors.textSecondary(isDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        context.push(
                          AppConfig.triageResult,
                          extra: triageResult!.toJson(),
                        );
                      },
                      icon: const Icon(Icons.read_more, size: 18),
                      label: const Text('View Full Triage Result'),
                    ),
                  ),
                ],
                if (log.notes != null && log.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notes: ${log.notes}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textHint(isDark),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Glowing dot — colored dot with soft outer glow (BoxShadow blurRadius=12).
// ═══════════════════════════════════════════════════════════════════════════

class _GlowingDot extends StatelessWidget {
  final Color color;
  const _GlowingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Dashed vertical line painter.
// ═══════════════════════════════════════════════════════════════════════════

class _DashedLinePainter extends CustomPainter {
  final Color color;

  // Tunable dash metrics — kept as private constants so the painter is easy
  // to tweak in one place without rippling API changes through call sites.
  static const double _strokeWidth = 1.5;
  static const double _dashHeight = 4;
  static const double _gapHeight = 4;

  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;

    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + _dashHeight),
        paint,
      );
      y += _dashHeight + _gapHeight;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════
// Export 30-day Report (Pro) button — full-width, rounded-full,
// bg-inverse-surface.
// ═══════════════════════════════════════════════════════════════════════════

class _ExportReportButton extends StatelessWidget {
  final bool isDark;
  const _ExportReportButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    // bg-inverse-surface: dark on light theme, light on dark theme.
    // text: opposite (white on dark button, dark on light button).
    final bg = AppColors.onBackground(isDark);
    final fg = AppColors.surface(isDark);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => context.push(AppConfig.exportScreen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 18, color: fg),
                const SizedBox(width: 8),
                Text(
                  'Export 30-day Report (Pro)',
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.05,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers — color, severity, relative-date formatting.
// ═══════════════════════════════════════════════════════════════════════════

Color _severityColor(int severity) {
  if (severity <= 3) return AppColors.urgencyLow;
  if (severity <= 6) return AppColors.urgencyMedium;
  if (severity <= 8) return AppColors.urgencyHigh;
  return AppColors.urgencyEmergency;
}

Color _urgencyColor(String level, bool isDark) {
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
      return AppColors.textSecondary(isDark);
  }
}

/// Format the log timestamp as a relative-date + time stamp using the
/// JetBrainsMono-style format: "TODAY • 08:42 AM", "YESTERDAY • 03:15 PM",
/// "MON • 11:30 AM" (this week), or "12 OCT • 09:00 AM" (older).
String _formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(date.year, date.month, date.day);
  final diff = today.difference(that).inDays;

  String dayLabel;
  if (diff == 0) {
    dayLabel = 'TODAY';
  } else if (diff == 1) {
    dayLabel = 'YESTERDAY';
  } else if (diff > 0 && diff < 7) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    dayLabel = days[date.weekday - 1];
  } else {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    dayLabel = '${date.day} ${months[date.month - 1]}';
  }

  final hour = date.hour > 12
      ? date.hour - 12
      : (date.hour == 0 ? 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  final ampm = date.hour >= 12 ? 'PM' : 'AM';
  final hourStr = hour.toString().padLeft(2, '0');
  return '$dayLabel • $hourStr:$minute $ampm';
}
