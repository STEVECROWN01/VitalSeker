import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/vital.dart';
import '../../../core/providers/vitals_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/medical_disclaimer_banner.dart';

class VitalsScreen extends ConsumerStatefulWidget {
  const VitalsScreen({super.key});

  @override
  ConsumerState<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends ConsumerState<VitalsScreen> {
  int _selectedSegment = 0; // 0: Day, 1: Week, 2: Month

  Future<void> _handleRefresh() async {
    ref.invalidate(vitalsProvider);
    // Wait for the provider to resolve
    await ref.read(vitalsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vitalsAsync = ref.watch(vitalsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vitals)),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primary(isDark),
        child: vitalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.urgencyEmergency),
                const SizedBox(height: 16),
                Text(
                  l10n.failedToLoadVitals,
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textSecondary(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          data: (vitals) {
            if (vitals.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: (AppColors.primary(isDark)).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.monitor_heart_outlined,
                            color: AppColors.primary(isDark),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noVitalsYet,
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.startLoggingVitalsPrompt,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: AppColors.textSecondary(isDark),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push(AppConfig.addVital),
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(
                            l10n.logFirstVital,
                            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(isDark),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                // Segmented Control
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.subtleBackground(isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _SegmentButton(
                          label: l10n.day,
                          isSelected: _selectedSegment == 0,
                          onTap: () => setState(() => _selectedSegment = 0),
                        ),
                        _SegmentButton(
                          label: l10n.week,
                          isSelected: _selectedSegment == 1,
                          onTap: () => setState(() => _selectedSegment = 1),
                        ),
                        _SegmentButton(
                          label: l10n.month,
                          isSelected: _selectedSegment == 2,
                          onTap: () => setState(() => _selectedSegment = 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Vital Type Cards
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    itemCount: VitalType.values.length + 1,
                    itemBuilder: (context, index) {
                      if (index == VitalType.values.length) {
                        // Medical disclaimer as the last item in the vitals
                        // list, per Cahier des Charges Section 7. The extra
                        // bottom padding clears the FAB.
                        return const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 80),
                          child: MedicalDisclaimerBanner(),
                        );
                      }
                      final type = VitalType.values[index];
                      return _VitalTypeCard(
                        vitalType: type,
                        isDark: isDark,
                        vitals: vitals,
                        selectedSegment: _selectedSegment,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_vital_fab',
        onPressed: () => context.push(AppConfig.addVital),
        backgroundColor: AppColors.primary(isDark),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (AppColors.primary(isDark))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : AppColors.textSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _VitalTypeCard extends ConsumerWidget {
  final VitalType vitalType;
  final bool isDark;
  final List<Vital> vitals;
  /// 0 = Day (24h), 1 = Week (7d), 2 = Month (30d). Used to filter the
  /// trend computation window so the segment control on the parent screen
  /// actually affects what the user sees.
  final int selectedSegment;

  const _VitalTypeCard({
    required this.vitalType,
    required this.isDark,
    required this.vitals,
    required this.selectedSegment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final latestVital = ref.watch(latestVitalProvider(vitalType));
    final typeVitals = ref.watch(vitalsByTypeProvider(vitalType));

    // Apply the segment window to the trend computation. The latest value
    // shown is still the most recent reading regardless of window; the trend
    // arrow reflects only readings inside the selected window.
    final windowDuration = selectedSegment == 0
        ? const Duration(days: 1)
        : selectedSegment == 1
            ? const Duration(days: 7)
            : const Duration(days: 30);
    final windowStart = DateTime.now().subtract(windowDuration);
    final windowedVitals = typeVitals.where((v) => v.recordedAt.isAfter(windowStart)).toList();

    String trend = 'stable';
    if (windowedVitals.length >= 2) {
      final sorted = List<Vital>.from(windowedVitals)
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      final latest = sorted.first.value;
      final previous = sorted[1].value;
      if (latest > previous) {
        trend = 'up';
      } else if (latest < previous) {
        trend = 'down';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => context.push(
          '${AppConfig.vitalsHistory}?type=${vitalType.name}',
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.borderLight(isDark),
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: vitalType.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(vitalType.icon, color: vitalType.color, size: 24),
              ),
              const SizedBox(width: 14),

              // Name and timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vitalType.displayName,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (latestVital != null)
                      Text(
                        _formatTimestamp(latestVital.recordedAt, l10n),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textHint(isDark),
                        ),
                      )
                    else
                      Text(
                        l10n.noData,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textTertiary(isDark),
                        ),
                      ),
                  ],
                ),
              ),

              // Value and trend
              if (latestVital != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          latestVital.displayValue,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: vitalType.color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vitalType.unit,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textHint(isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _TrendBadge(trend: trend, color: vitalType.color),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.grey200.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '--',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 16,
                      color: AppColors.textTertiary(isDark),
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _TrendBadge extends StatelessWidget {
  final String trend;
  final Color color;

  const _TrendBadge({required this.trend, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    IconData icon;
    Color badgeColor;
    String label;

    switch (trend) {
      case 'up':
        icon = Icons.trending_up;
        badgeColor = AppColors.urgencyMedium;
        label = l10n.trendUp;
        break;
      case 'down':
        icon = Icons.trending_down;
        badgeColor = isDark ? AppColors.darkInfo : AppColors.lightInfo;
        label = l10n.trendDown;
        break;
      default:
        icon = Icons.trending_flat;
        badgeColor = AppColors.urgencyLow;
        label = l10n.trendStable;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
