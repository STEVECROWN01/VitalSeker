import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/symptom_log_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/vitals_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../core/models/vital.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/vital_score_ring.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _aiTip;
  bool _isLoadingTip = false;
  DateTime? _tipFetchedAt;

  @override
  void initState() {
    super.initState();
    // Defer to first frame so providers have a chance to resolve.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAiTip());
  }

  /// Fetch a real AI-generated health tip via the triage edge function.
  ///
  /// The triage function already wraps Anthropic Claude with our system prompt,
  /// so we reuse it with a "general health tip" framing instead of paying for
  /// a separate function. The result is cached for the lifetime of the
  /// dashboard widget — refreshing requires pull-to-refresh on the dashboard
  /// (or restarting the app).
  ///
  /// Falls back to a curated set of static tips on any error.
  Future<void> _loadAiTip() async {
    if (_isLoadingTip) return;
    // Don't refetch if we already have a tip from the last 6 hours.
    if (_aiTip != null && _tipFetchedAt != null &&
        DateTime.now().difference(_tipFetchedAt!) < const Duration(hours: 6)) {
      return;
    }

    setState(() => _isLoadingTip = true);
    try {
      final profile = ref.read(userProfileProvider).valueOrNull;
      final passport = ref.read(healthPassportProvider).valueOrNull;
      final vitalsAsync = ref.read(vitalsProvider).valueOrNull;

      // Build a brief context string for the AI to base its tip on.
      final contextParts = <String>[];
      if (profile?.bloodType != null) contextParts.add('blood type: ${profile!.bloodType}');
      if (profile?.allergies.isNotEmpty == true) {
        contextParts.add('allergies: ${profile!.allergies.join(', ')}');
      }
      if (profile?.chronicConditions.isNotEmpty == true) {
        contextParts.add('conditions: ${profile!.chronicConditions.join(', ')}');
      }
      if (passport != null) contextParts.add('vital score: ${passport.vitalScore}/100');
      if (vitalsAsync != null && vitalsAsync.isNotEmpty) {
        final latest = vitalsAsync.first;
        contextParts.add('latest vital: ${latest.type.name}=${latest.value}');
      }
      final context = contextParts.isEmpty
          ? 'No specific health data available yet.'
          : contextParts.join('; ');

      final edgeService = EdgeFunctionService();
      final result = await edgeService.runTriage(
        symptoms: ['general wellness check'],
        severity: 1,
        notes: 'Please provide ONE short (1-2 sentence) actionable health tip '
            'tailored to this user. Context: $context. Reply with the tip '
            'directly in the recommendations field — do not perform triage.',
      );

      final triage = result['triage'] as Map<String, dynamic>?;
      final recommendations = triage?['recommendations'] as List?;
      if (recommendations != null && recommendations.isNotEmpty) {
        final tip = recommendations.first.toString();
        if (tip.isNotEmpty) {
          setState(() {
            _aiTip = tip;
            _tipFetchedAt = DateTime.now();
            _isLoadingTip = false;
          });
          return;
        }
      }
      // Fallback if AI didn't return a usable tip.
      setState(() {
        _aiTip = _fallbackTip();
        _tipFetchedAt = DateTime.now();
        _isLoadingTip = false;
      });
    } catch (_) {
      // Network / edge function error — use a fallback tip.
      setState(() {
        _aiTip = _fallbackTip();
        _tipFetchedAt = DateTime.now();
        _isLoadingTip = false;
      });
    }
  }

  static String _fallbackTip() {
    const tips = [
      'Stay hydrated! Drinking 8 glasses of water daily helps maintain healthy blood pressure and improves circulation.',
      'Aim for 7-9 hours of sleep per night to support immune function and recovery.',
      'Even 15 minutes of brisk walking daily can improve cardiovascular health over time.',
      'Practice deep breathing for 5 minutes a day to help manage stress and reduce blood pressure.',
      'Keep a consistent meal schedule to help stabilize blood sugar levels.',
    ];
    return tips[DateTime.now().millisecond % tips.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);
    final passportAsync = ref.watch(healthPassportProvider);
    final logsAsync = ref.watch(symptomLogsProvider);
    final subAsync = ref.watch(subscriptionProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient and user info
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0A2E22) : const Color(0xFF0B7A5B),
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
                        // Header row with greeting and avatar/notification
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
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
                                  const SizedBox(height: 2),
                                  Text(
                                    profileAsync.maybeWhen(
                                      data: (p) => p?.fullName ?? 'User',
                                      orElse: () => 'User',
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'ClashDisplay',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // User avatar — tap to open profile
                            GestureDetector(
                              onTap: () => context.push(AppConfig.profile),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  image: profileAsync.maybeWhen(
                                    data: (p) => p?.avatarUrl != null && p!.avatarUrl!.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(p.avatarUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    orElse: () => null,
                                  ),
                                ),
                                child: profileAsync.maybeWhen(
                                  data: (p) {
                                    final hasAvatar = p?.avatarUrl != null && p!.avatarUrl!.isNotEmpty;
                                    if (hasAvatar) return const SizedBox.shrink();
                                    final name = p?.fullName ?? 'U';
                                    return Center(
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: const TextStyle(
                                          fontFamily: 'ClashDisplay',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                  orElse: () => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Notification bell — tap to open notification settings
                            GestureDetector(
                              onTap: () => context.push(AppConfig.notificationsSettings),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.notifications_outlined, color: Colors.white),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms),
                        const SizedBox(height: 16),
                        // Subtitle / health summary
                        profileAsync.maybeWhen(
                          data: (p) {
                            final bloodType = p?.bloodType;
                            final allergies = p?.allergies ?? [];
                            if (bloodType != null || allergies.isNotEmpty) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    if (bloodType != null) ...[
                                      Icon(Icons.bloodtype, color: Colors.white.withValues(alpha: 0.8), size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        bloodType,
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                                      ),
                                      if (allergies.isNotEmpty) const SizedBox(width: 12),
                                    ],
                                    if (allergies.isNotEmpty) ...[
                                      Icon(Icons.warning_amber, color: isDark ? AppColors.darkWarning : AppColors.lightWarning, size: 16),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${allergies.length} allerg${allergies.length == 1 ? 'y' : 'ies'}',
                                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content with proper spacing below the app bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _QuickActionCard(
                        icon: Icons.monitor_heart,
                        label: 'Log Vitals',
                        color: AppColors.primary(isDark),
                        onTap: () => context.push(AppConfig.addVital),
                      ),
                      const SizedBox(width: 12),
                      _QuickActionCard(
                        icon: Icons.healing,
                        label: 'Start Triage',
                        color: AppColors.secondary(isDark),
                        onTap: () => context.push(AppConfig.triage),
                      ),
                      const SizedBox(width: 12),
                      _QuickActionCard(
                        icon: Icons.emergency,
                        label: 'Emergency',
                        color: AppColors.urgencyEmergency,
                        onTap: () => context.push(AppConfig.sos),
                      ),
                      const SizedBox(width: 12),
                      _QuickActionCard(
                        icon: Icons.medication,
                        label: 'Medications',
                        color: AppColors.urgencyMedium,
                        onTap: () => context.push(AppConfig.medications),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                  const SizedBox(height: 28),

                  // Recent Vitals
                  Consumer(builder: (context, ref, _) {
                    final vitalsAsync = ref.watch(vitalsProvider);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Vitals',
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(isDark),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push(AppConfig.vitals),
                              child: Text(
                                'View All',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: vitalsAsync.maybeWhen(
                            data: (vitals) {
                              if (vitals.isEmpty) {
                                return _EmptyStateCard(
                                  icon: Icons.monitor_heart,
                                  message: 'No vitals logged yet',
                                  subtitle: 'Tap "Log Vitals" to start tracking',
                                );
                              }
                              // Show latest value for each vital type
                              final latestByType = <VitalType, Vital>{};
                              for (final v in vitals) {
                                if (!latestByType.containsKey(v.type) ||
                                    v.recordedAt.isAfter(latestByType[v.type]!.recordedAt)) {
                                  latestByType[v.type] = v;
                                }
                              }
                              final displayTypes = [
                                VitalType.heartRate,
                                VitalType.bloodPressure,
                                VitalType.spO2,
                                VitalType.temperature,
                              ];
                              return ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: displayTypes.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final type = displayTypes[index];
                                  final vital = latestByType[type];
                                  return _VitalSummaryCard(
                                    vitalType: type,
                                    vital: vital,
                                  );
                                },
                              );
                            },
                            orElse: () => const Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 28),

                  // AI Health Tip
                  GestureDetector(
                    onTap: _isLoadingTip ? null : _loadAiTip,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF0A2E22), const Color(0xFF151925)]
                              : [const Color(0xFFE0F2F1), const Color(0xFFE8E5FF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.borderLight(isDark),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary(isDark).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _isLoadingTip
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(Icons.tips_and_updates, color: AppColors.primary(isDark), size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'AI Health Tip',
                                      style: TextStyle(
                                        fontFamily: 'ClashDisplay',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary(isDark),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.refresh,
                                      size: 12,
                                      color: AppColors.textHint(isDark),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _aiTip ?? 'Loading your personalized tip...',
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
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                  const SizedBox(height: 28),

                  // Recent Activity
                  Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(isDark),
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
                                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                              ),
                              trailing: Text(
                                _formatDate(log.loggedAt),
                                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textHint(isDark)),
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
                                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                                    foregroundColor: AppColors.primary(isDark),
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
      shadowColor: AppColors.primary(isDark).withValues(alpha: 0.2),
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
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your overall health indicator',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary(isDark).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium, size: 14, color: AppColors.primary(isDark)),
                          SizedBox(width: 4),
                          Text(
                            'PRO',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary(isDark),
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
            color: AppColors.cardBackground(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight(isDark)),
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
            Icon(icon, size: 48, color: AppColors.textTertiary(isDark)),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(isDark),
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textTertiary(isDark),
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

class _VitalSummaryCard extends StatelessWidget {
  final VitalType vitalType;
  final Vital? vital;

  const _VitalSummaryCard({
    required this.vitalType,
    this.vital,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: vitalType.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(vitalType.icon, color: vitalType.color, size: 16),
              ),
              const Spacer(),
              if (vital != null)
                Icon(
                  Icons.trending_up,
                  size: 14,
                  color: AppColors.urgencyLow,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            vital != null ? vital!.displayValue : '--',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            vitalType.displayName,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.textHint(isDark),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
