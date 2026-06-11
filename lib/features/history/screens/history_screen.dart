import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/symptom_log_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/urgency_badge.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsAsync = ref.watch(symptomLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Symptom History')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(symptomLogsProvider);
          await ref.read(symptomLogsProvider.future);
        },
        color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.urgencyEmergency),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load history',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.lightOnBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$e',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                    textAlign: TextAlign.center,
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
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: isDark ? AppColors.grey600 : AppColors.grey300),
                  const SizedBox(height: 16),
                  Text(
                    'No History Yet',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your symptom logs will appear here',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: isDark ? AppColors.grey500 : AppColors.grey400,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final triageResult = log.triageResult;
              final urgencyLevel = triageResult?.urgencyLevel ?? 'medium';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _severityColor(log.severity).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.healing, color: _severityColor(log.severity), size: 24),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.symptoms.take(3).join(', '),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      UrgencyBadge(urgencyLevel: urgencyLevel),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(
                          'Severity: ${log.severity}/10',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: isDark ? AppColors.grey400 : AppColors.grey500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(log.loggedAt),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11,
                            color: isDark ? AppColors.grey500 : AppColors.grey400,
                          ),
                        ),
                      ],
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
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.grey300 : AppColors.grey700),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: log.symptoms.map((s) => Chip(
                              label: Text(s, style: const TextStyle(fontSize: 11)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            )).toList(),
                          ),
                          if (log.bodyRegions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Body Regions: ${log.bodyRegions.join(', ')}',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? AppColors.grey400 : AppColors.grey500),
                            ),
                          ],
                          if (log.duration != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Duration: ${log.duration}',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? AppColors.grey400 : AppColors.grey500),
                            ),
                          ],
                          if (triageResult != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'AI Recommendation: ${triageResult.seekCare.replaceAll('-', ' ').toUpperCase()}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _urgencyColor(triageResult.urgencyLevel),
                              ),
                            ),
                            if (triageResult.recommendations.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ...triageResult.recommendations.take(3).map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('  • ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Expanded(child: Text(r, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey600))),
                                  ],
                                ),
                              )),
                            ],
                          ],
                          if (log.notes != null && log.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Notes: ${log.notes}',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey500 : AppColors.grey400, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }

  Color _severityColor(int severity) {
    if (severity <= 3) return AppColors.urgencyLow;
    if (severity <= 6) return AppColors.urgencyMedium;
    if (severity <= 8) return AppColors.urgencyHigh;
    return AppColors.urgencyEmergency;
  }

  Color _urgencyColor(String level) {
    switch (level) {
      case 'low': return AppColors.urgencyLow;
      case 'medium': return AppColors.urgencyMedium;
      case 'high': return AppColors.urgencyHigh;
      case 'emergency': return AppColors.urgencyEmergency;
      default: return AppColors.grey400;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
