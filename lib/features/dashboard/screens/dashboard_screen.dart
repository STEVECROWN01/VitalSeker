import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/symptom_log.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/health_passport_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/symptom_log_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/vitals_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/vital_score_ring.dart';

/// VitalSeker dashboard — redesigned to match the Google Stitch UI audit.
///
/// Layout (top → bottom):
///   1. Compact ~72px app bar (white/translucent) — avatar + greeting +
///      theme-toggle pill + notifications bell.
///   2. Health Score hero card (brandGradient) — prominent "84"/100 number,
///      "Good condition ✨" badge, 7-bar MON–SUN mini chart, "Tap for weekly
///      insights" CTA, and the existing [VitalScoreRing] wrapped inside.
///   3. Quick Actions bento grid — large "Check Symptoms Now" (col-span-2,
///      secondary-container) + "Health Passport" + "My History".
///   4. Full-width Emergency SOS button (red gradient, uppercase tracking).
///   5. Recent Checks — up to 3 items with circular icons + colored severity
///      dots (primary-container / yellow-500 / error).
///   6. Footer — "Powered by Keter Marketing"
///
/// The widget stays a [ConsumerStatefulWidget] so the AI-health-tip fetcher
/// (previously surfaced as a card on the dashboard) keeps its state
/// management. The tip itself is no longer rendered here — the card was
/// removed per the design audit — but `_loadAiTip`/`_aiTip`/`_tipFetchedAt`
/// remain so a future surface (e.g. the insights screen) can read the cached
/// tip without a refetch. The data providers
/// (userProfileProvider, healthPassportProvider, symptomLogsProvider,
/// subscriptionProvider, vitalsProvider) are all still watched/read.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // ── AI health-tip state (preserved for state-management continuity) ──
  //
  // The tip is no longer rendered on the redesigned dashboard (the AI Health
  // Tip card was removed per the design audit). The fetcher + cache remain
  // so future surfaces can read `_aiTip` without paying for a second edge
  // function call.
  String? _aiTip;
  bool _isLoadingTip = false;
  DateTime? _tipFetchedAt;

  @override
  void initState() {
    super.initState();
    // Note: the previous implementation called _loadAiTip() here, which
    // misused the triage edge function (a $0.003/consultation call) to
    // generate a "wellness tip" that was never rendered after the dashboard
    // redesign. The dead code has been removed to avoid wasting AI calls
    // on every dashboard mount. If AI-generated tips are needed in the
    // future, implement a dedicated edge function.
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
      if (profile?.bloodType != null) {
        contextParts.add('blood type: ${profile!.bloodType}');
      }
      if (profile?.allergies.isNotEmpty == true) {
        contextParts.add('allergies: ${profile!.allergies.join(', ')}');
      }
      if (profile?.chronicConditions.isNotEmpty == true) {
        contextParts.add('conditions: ${profile!.chronicConditions.join(', ')}');
      }
      if (passport != null) {
        contextParts.add('vital score: ${passport.vitalScore}/100');
      }
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

  /// Time-of-day-aware greeting ("Good morning/afternoon/evening/night").
  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h < 12) return l10n.goodMorning;
    if (h < 17) return l10n.goodAfternoon;
    if (h < 22) return l10n.goodEvening;
    return l10n.goodNight;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(userProfileProvider);
    final passportAsync = ref.watch(healthPassportProvider);
    final logsAsync = ref.watch(symptomLogsProvider);
    // Watched for state-management continuity — the subscription banner was
    // removed from the redesigned UI per the design audit, but the provider
    // stays warm so a future surface (e.g. paywall) can read it instantly.
    ref.watch(subscriptionProvider);

    final vitalScore = passportAsync.maybeWhen(
      data: (p) => p?.vitalScore ?? 0,
      orElse: () => 0,
    );
    final firstName = profileAsync.maybeWhen(
      data: (p) {
        final full = p?.fullName;
        if (full == null || full.isEmpty) return l10n.userFallback;
        final parts = full.split(RegExp(r'\s+'));
        return parts.isNotEmpty && parts.first.isNotEmpty
            ? parts.first
            : l10n.userFallback;
      },
      orElse: () => l10n.userFallback,
    );

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: CustomScrollView(
        slivers: [
          // ── 1. Compact ~72px app bar (white/translucent) ──
          SliverAppBar(
            toolbarHeight: 72,
            pinned: true,
            backgroundColor: AppColors.surface(isDark).withValues(alpha: 0.96),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 20,
            title: Row(
              children: [
                _Avatar(profileAsync: profileAsync),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_greeting(l10n)},',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary(isDark),
                          height: 1.2,
                        ),
                      ),
                      Text(
                        '$firstName 👋',
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(isDark),
                          height: 1.2,
                          letterSpacing: -0.01,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                _ThemeTogglePill(
                  isDark: isDark,
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setTheme(
                          isDark ? ThemeMode.light : ThemeMode.dark,
                        );
                  },
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => context.push(AppConfig.notificationsSettings),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.subtleBackground(isDark),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight(isDark)),
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textPrimary(isDark),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 2–6. Main scrollable content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Health Score hero card
                  _HealthScoreHeroCard(score: vitalScore)
                      .animate()
                      .slideY(duration: 500.ms, begin: 0.15)
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),

                  // 3. Quick Actions (bento grid)
                  _SectionHeader(title: l10n.quickActions),
                  const SizedBox(height: 12),
                  _BentoQuickActions(isDark: isDark)
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms),
                  const SizedBox(height: 24),

                  // 4. Emergency SOS
                  _EmergencySosButton(
                    isDark: isDark,
                    onTap: () => context.push(AppConfig.sos),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms),
                  const SizedBox(height: 28),

                  // 5. Recent Checks
                  _SectionHeader(
                    title: l10n.recentChecks,
                    actionText: l10n.viewAll,
                    onAction: () => context.go(AppConfig.history),
                  ),
                  const SizedBox(height: 12),
                  logsAsync.maybeWhen(
                    data: (logs) {
                      if (logs.isEmpty) {
                        // Make the empty-state card itself tappable — tapping
                        // it deep-links straight into triage so the user can
                        // log their first symptom and seed the "Recent
                        // Checks" list.
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.go(AppConfig.triage),
                          child: _EmptyStateCard(
                            icon: Icons.history,
                            message: l10n.noSymptomsLogs,
                            subtitle:
                                l10n.startTriage,
                          ),
                        );
                      }
                      return Column(
                        children: logs.take(3).map((log) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecentCheckItem(log: log),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, __) => _EmptyStateCard(
                      icon: Icons.error_outline,
                      message: l10n.failedLoadRecentChecks,
                      subtitle: l10n.pullDownRetry,
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 28),

                  // 6. Footer
                  Center(
                    child: Text(
                      l10n.poweredBy,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textTertiary(isDark),
                        height: 1.5,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // Bottom-nav clearance
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// App-bar pieces
// ═══════════════════════════════════════════════════════════════════════════

/// 40px circular avatar — tappable to open the profile screen.
///
/// Renders the uploaded profile picture when `avatarUrl` is set, falling
/// back to a colored circle with the user's initial. Uses [Image.network]
/// with explicit loading + error builders so a slow / failing network image
/// degrades gracefully to the initials placeholder instead of showing a
/// blank circle (the previous `BoxDecoration.image` approach had no error
/// fallback, which is why uploaded avatars sometimes appeared missing).
class _Avatar extends StatelessWidget {
  final AsyncValue<UserProfile?> profileAsync;
  const _Avatar({required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final profile = profileAsync.valueOrNull;
    final avatarUrl = profile?.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final name = profile?.fullName ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    final initialsWidget = Center(
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'ClashDisplay',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primary(isDark),
        ),
      ),
    );

    return GestureDetector(
      onTap: () => context.push(AppConfig.profile),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryContainer(isDark),
          border: Border.all(
            color: AppColors.borderLight(isDark),
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: hasAvatar
              ? Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  width: 40,
                  height: 40,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return initialsWidget;
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      initialsWidget,
                )
              : initialsWidget,
        ),
      ),
    );
  }
}

/// Pill-shaped theme toggle — tapping flips light ↔ dark via [themeModeProvider].
class _ThemeTogglePill extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _ThemeTogglePill({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.subtleBackground(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight(isDark)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 14,
              color: AppColors.textSecondary(isDark),
            ),
            const SizedBox(width: 4),
            Text(
              isDark ? l10n.light : l10n.dark,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(isDark),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section header
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'ClashDisplay',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(isDark),
            height: 1.2,
            letterSpacing: -0.01,
          ),
        ),
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionText!,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary(isDark),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. Health Score hero card (gradient bg, prominent "84", weekly mini chart,
//    CTA, and the existing VitalScoreRing wrapped inside).
// ═══════════════════════════════════════════════════════════════════════════

class _HealthScoreHeroCard extends StatelessWidget {
  final int score;
  const _HealthScoreHeroCard({required this.score});

  String _conditionLabel(AppLocalizations l10n) {
    if (score >= 80) return l10n.goodCondition;
    if (score >= 60) return l10n.fairCondition;
    if (score >= 40) return l10n.needsAttention;
    if (score >= 20) return l10n.poorCondition;
    return l10n.critical;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradientFor(isDark),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary(isDark).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: label + condition badge
          Row(
            children: [
              Text(
                l10n.healthScore.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.32),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_conditionLabel(l10n)} ✨',
                  style: const TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Score row: prominent "84" + "/100" (left) and the VitalScoreRing
          // wrapped inside the hero card (right, decorative arc).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 56,
                            fontWeight: FontWeight.w800, // ExtraBold
                            color: Colors.white,
                            height: 1.0,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '/100',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.overallHealthIndicator,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // VitalScoreRing wrapped in a translucent white circle so the
              // ring's track + arc stay legible against the green gradient.
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: VitalScoreRing(
                  score: score,
                  size: 80,
                  showLabel: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          // 7-bar weekly mini chart (MON–SUN)
          _WeeklyMiniChart(score: score),
          const SizedBox(height: 16),
          // CTA
          GestureDetector(
            onTap: () => context.go(AppConfig.insights),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.tapForWeeklyInsights,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 7-bar mini chart (MON–SUN).
///
/// PREVIOUSLY this widget fabricated deterministic data (_variations = [-6, 3,
/// 7, -3, 9, 4, 0]) to make the chart look populated. That was misleading —
/// users thought the app was showing real historical scores.
///
/// NOW: only today's bar shows the actual vital score; the other 6 bars are
/// rendered as small "no data" stubs. When real history is available (e.g.
/// via a future vitals_score_history table), this widget should be updated
/// to plot real values for each day.
class _WeeklyMiniChart extends StatelessWidget {
  final int score;
  const _WeeklyMiniChart({required this.score});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    // DateTime.weekday: 1=Mon … 7=Sun → 0-based for our array.
    final today = (DateTime.now().weekday - 1) % 7;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final isToday = i == today;
        // Today's bar shows the real score (scaled to 8-40px).
        // Other bars are 4px stubs indicating "no historical data yet".
        final barHeight = isToday ? (8 + (score / 100) * 32) : 4.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 22,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _days[i],
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 10,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. Quick Actions — 2-col bento grid
// ═══════════════════════════════════════════════════════════════════════════

class _BentoQuickActions extends StatelessWidget {
  final bool isDark;
  const _BentoQuickActions({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Row 1: large "Check Symptoms Now" — col-span-2, secondary-container bg
        _LargeBentoCard(
          isDark: isDark,
          icon: Icons.healing,
          title: l10n.checkSymptomsNow,
          subtitle: l10n.aiTriageIn90Seconds,
          onTap: () => context.go(AppConfig.triage),
        ),
        const SizedBox(height: 12),
        // Row 2: two smaller cards side-by-side
        Row(
          children: [
            Expanded(
              child: _SmallBentoCard(
                isDark: isDark,
                icon: Icons.shield_outlined,
                title: l10n.healthPassport,
                subtitle: l10n.qrAndMedicalInfo,
                onTap: () => context.go(AppConfig.passport),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallBentoCard(
                isDark: isDark,
                icon: Icons.history,
                title: l10n.myHistory,
                subtitle: l10n.pastChecksAndVitals,
                onTap: () => context.go(AppConfig.history),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Large full-width bento card — secondary-container background.
class _LargeBentoCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LargeBentoCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // secondary-container: light = Clean Mint #D1FADF, dark = #0B7A5B
    final bg = AppColors.secondaryContainer(isDark);
    final titleColor = isDark ? Colors.white : AppColors.lightSecondary;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.lightSecondary.withValues(alpha: 0.7);
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.lightSecondary.withValues(alpha: 0.12);
    final iconColor = isDark ? Colors.white : AppColors.lightSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.lightSecondary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      height: 1.2,
                      letterSpacing: -0.01,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: subtitleColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Smaller bento card — half-width, surface bg, primary-tinted icon.
class _SmallBentoCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SmallBentoCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary(isDark);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(isDark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primary, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(isDark),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textSecondary(isDark),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. Emergency SOS button — full-width, red gradient, uppercase tracking.
// ═══════════════════════════════════════════════════════════════════════════

class _EmergencySosButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _EmergencySosButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          gradient: AppColors.sosGradient, // #BA1A1A → #93000A
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.error(isDark).withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emergency,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              l10n.emergencySOS,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4, // tracking-widest
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. Recent Checks — 3 items with circular icons + colored severity dots.
// ═══════════════════════════════════════════════════════════════════════════

class _RecentCheckItem extends StatelessWidget {
  final SymptomLog log;
  const _RecentCheckItem({required this.log});

  /// Maps the audit palette (primary-container / yellow-500 / error) to the
  /// log's 0–10 severity.
  Color _severityColor(bool isDark) {
    if (log.severity <= 3) return AppColors.primaryContainer(isDark);
    if (log.severity <= 7) return const Color(0xFFFFC107); // yellow-500 / amber
    return AppColors.error(isDark);
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 1) return l10n.justNow;
    if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays == 0) return l10n.todayLabel;
    if (diff.inDays == 1) return l10n.yesterdayLabel;
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final l10n = AppLocalizations.of(context)!;
    final color = _severityColor(isDark);
    final title = log.symptoms.take(2).join(', ');
    final displayTitle = title.isEmpty ? l10n.symptomCheck : title;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight(isDark)),
      ),
      child: Row(
        children: [
          // Circular icon with severity-tinted backdrop
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.healing, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          // Symptom name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayTitle,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(isDark),
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.severity} ${log.severity}/10 · ${_formatDate(log.loggedAt, l10n)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textSecondary(isDark),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Severity dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty-state card (for when the user has no recent checks yet).
// ═══════════════════════════════════════════════════════════════════════════

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
    final isDark = context.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight(isDark)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textTertiary(isDark)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textTertiary(isDark),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
