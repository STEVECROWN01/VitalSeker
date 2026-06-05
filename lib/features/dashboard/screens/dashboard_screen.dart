import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/symptom_log_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/vital_score_ring.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);
    final passportAsync = ref.watch(healthPassportProvider);
    final logsAsync = ref.watch(symptomLogsProvider);
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0A2E22), Color(0xFF0A0E17)],
                        )
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0B7A5B), Color(0xFF0B9E70)],
                        ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello,',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                Text(
                                  profileAsync.maybeWhen(
                                    data: (p) => p?.fullName?.split(' ').first ?? 'User',
                                    orElse: () => 'User',
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'ClashDisplay',
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.notifications_outlined, color: Colors.white),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Vital Score Card
                    _VitalScoreCard(
                      vitalScore: passportAsync.maybeWhen(
                        data: (p) => p?.vitalScore ?? 0,
                        orElse: () => 0,
                      ),
                      isPro: subAsync.maybeWhen(
                        data: (s) => s?.isPro ?? false,
                        orElse: () => false,
                      ),
                    ).animate().slideY(duration: 500.ms, begin: 0.2),
                    const SizedBox(height: 20),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _QuickActionCard(
                          icon: Icons.healing,
                          label: 'Triage',
                          color: AppColors.lightSecondary,
                          onTap: () => context.push(AppConfig.triage),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionCard(
                          icon: Icons.badge,
                          label: 'Passport',
                          color: AppColors.lightPrimary,
                          onTap: () => context.push(AppConfig.passport),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionCard(
                          icon: Icons.insights,
                          label: 'Insights',
                          color: AppColors.urgencyMedium,
                          onTap: () => context.push(AppConfig.insights),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionCard(
                          icon: Icons.family_restroom,
                          label: 'Family',
                          color: AppColors.urgencyLow,
                          onTap: () => context.push(AppConfig.family),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    const SizedBox(height: 28),

                    // Recent Activity
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.lightOnBackground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    logsAsync.maybeWhen(
                      data: (logs) {
                        if (logs.isEmpty) {
                          return _EmptyStateCard(
                            icon: Icons.history,
                            message: 'No symptom logs yet',
                            subtitle: 'Start your first triage to see activity here',
                          );
                        }
                        return Column(
                          children: logs.take(5).map((log) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _severityColor(log.severity).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.healing, color: _severityColor(log.severity), size: 20),
                                ),
                                title: Text(
                                  log.symptoms.take(2).join(', '),
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  'Severity: ${log.severity}/10',
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                                ),
                                trailing: Text(
                                  _formatDate(log.loggedAt),
                                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? AppColors.grey500 : AppColors.grey400),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => _EmptyStateCard(icon: Icons.error, message: 'Failed to load logs', subtitle: ''),
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),

                    // Subscription Banner
                    subAsync.maybeWhen(
                      data: (sub) {
                        if (sub?.isPro != true) {
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Upgrade to Pro',
                                          style: TextStyle(
                                            fontFamily: 'ClashDisplay',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$6.99/mo - Weekly insights, unlimited triage',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            color: Colors.white.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => context.push(AppConfig.subscription),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.lightPrimary,
                                    ),
                                    child: const Text('Upgrade', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().slideY(duration: 500.ms, begin: 0.1, delay: 300.ms);
                        }
                        return const SizedBox.shrink();
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 100), // Bottom nav space
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(int severity) {
    if (severity <= 3) return AppColors.urgencyLow;
    if (severity <= 6) return AppColors.urgencyMedium;
    if (severity <= 8) return AppColors.urgencyHigh;
    return AppColors.urgencyEmergency;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }
}

class _VitalScoreCard extends StatelessWidget {
  final int vitalScore;
  final bool isPro;

  const _VitalScoreCard({required this.vitalScore, required this.isPro});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shadowColor: AppColors.lightPrimary.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            VitalScoreRing(score: vitalScore, size: 100),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vital Score',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.lightOnBackground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your overall health indicator',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lightPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium, size: 14, color: AppColors.lightPrimary),
                          SizedBox(width: 4),
                          Text(
                            'PRO',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2A2F3E) : AppColors.grey100),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.grey400 : AppColors.grey600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: isDark ? AppColors.grey600 : AppColors.grey300),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.grey400 : AppColors.grey500,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: isDark ? AppColors.grey600 : AppColors.grey400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
