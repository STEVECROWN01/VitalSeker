import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/family_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/symptom_log_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/vitals_provider.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.urgencyEmergency),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSigningOut = true);
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        if (mounted) context.go(AppConfig.login);
      } catch (e) {
        if (mounted) AppSnackBar.errorFromException(context, 'Failed to sign out. Please try again.', e);
      } finally {
        if (mounted) setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);
    final isPro = ref.watch(isProUserProvider);
    final familyAsync = ref.watch(familyProfilesProvider);
    final familyCount = familyAsync.maybeWhen(data: (list) => list.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppTextStyles.heading3.copyWith(color: AppColors.primary(isDark)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.push(AppConfig.notificationsSettings),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          final name = profile?.fullName ?? 'User';
          final email = profile?.email ?? '';
          final initials = (name.isNotEmpty ? name : 'U')
              .trim()
              .split(RegExp(r'\s+'))
              .map((w) => w[0].toUpperCase())
              .take(2)
              .join();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                // ── Hero ──
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          _ProfileAvatar(
                            avatarUrl: profile?.avatarUrl,
                            initials: initials,
                            isDark: isDark,
                            onTap: () => context.push(AppConfig.editProfile),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => context.push(AppConfig.editProfile),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary(isDark),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surface(isDark),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(Icons.edit, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: AppTextStyles.heading3.copyWith(
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                      if (isPro) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer(isDark),
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: AppColors.secondary(isDark).withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  size: 16,
                                  color: isDark
                                      ? AppColors.darkOnSurface
                                      : const Color(0xFF326F59)),
                              const SizedBox(width: 6),
                              Text(
                                'VitalSeker Pro',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: isDark
                                      ? AppColors.darkOnSurface
                                      : const Color(0xFF326F59),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => context.push(AppConfig.subscription),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer(isDark).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(
                                color: AppColors.primary(isDark).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_outline,
                                    size: 16, color: AppColors.primary(isDark)),
                                const SizedBox(width: 6),
                                Text(
                                  'Upgrade to Pro',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.primary(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Stats row ──
                Builder(builder: (context) {
                  final vitalsCount =
                      ref.watch(vitalsProvider).valueOrNull?.length ?? 0;
                  final triageCount =
                      ref.watch(symptomLogsProvider).valueOrNull?.length ?? 0;
                  final daysActive = profile != null
                      ? DateTime.now().difference(profile.createdAt).inDays
                      : 0;
                  return Row(
                    children: [
                      _StatCard(
                          label: 'Vitals Logged',
                          value: '$vitalsCount',
                          isDark: isDark),
                      const SizedBox(width: 12),
                      _StatCard(
                          label: 'Triage Sessions',
                          value: '$triageCount',
                          isDark: isDark),
                      const SizedBox(width: 12),
                      _StatCard(
                          label: 'Days Active',
                          value: '$daysActive',
                          isDark: isDark),
                    ],
                  );
                }),
                const SizedBox(height: 24),

                // ── Appearance ──
                _MenuSection(
                  title: 'Appearance',
                  isDark: isDark,
                  children: [
                    _MenuItem(
                      icon: Icons.dark_mode_outlined,
                      iconBg: _tint(AppColors.primary(isDark), isDark),
                      iconFg: AppColors.primary(isDark),
                      label: 'Dark Mode',
                      subtitle: _themeSubtitle(ref.read(themeModeProvider)),
                      trailing: Switch(
                        value: Theme.of(context).brightness == Brightness.dark,
                        onChanged: (v) => ref
                            .read(themeModeProvider.notifier)
                            .setTheme(v ? ThemeMode.dark : ThemeMode.light),
                        activeTrackColor: AppColors.primary(isDark),
                        thumbColor: WidgetStateProperty.all(Colors.white),
                      ),
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setTheme(isDark ? ThemeMode.light : ThemeMode.dark),
                    ),
                  ],
                ),

                // ── Account ──
                _MenuSection(
                  title: 'Account',
                  isDark: isDark,
                  children: [
                    _MenuItem(
                      icon: Icons.badge_outlined,
                      iconBg: _tint(AppColors.secondary(isDark), isDark),
                      iconFg: AppColors.secondary(isDark),
                      label: 'Health Passport',
                      subtitle: 'Manage medical credentials',
                      onTap: () => context.push(AppConfig.passport),
                    ),
                    _MenuItem(
                      icon: Icons.family_restroom,
                      iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                      iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                      label: 'Family Profiles',
                      subtitle: '$familyCount connected member${familyCount == 1 ? '' : 's'}',
                      onTap: () => context.push(AppConfig.family),
                    ),
                    _MenuItem(
                      icon: Icons.language,
                      iconBg: _tint(AppColors.primaryContainer(isDark), isDark),
                      iconFg: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.primary(isDark),
                      label: 'Language',
                      subtitle: 'English (US)',
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Select Language',
                                    style: TextStyle(
                                      fontFamily: 'ClashDisplay',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary(isDark),
                                    ),
                                  ),
                                ),
                                ...['English (US)', 'English (UK)', 'French', 'Spanish', 'Portuguese', 'German', 'Italian', 'Dutch', 'Arabic', 'Swahili', 'Hausa', 'Yoruba', 'Igbo', 'Chinese', 'Japanese', 'Korean', 'Hindi', 'Bengali', 'Urdu', 'Turkish', 'Russian', 'Polish', 'Vietnamese', 'Thai', 'Indonesian', 'Tagalog'].map((lang) => ListTile(
                                  title: Text(lang, style: const TextStyle(fontFamily: 'Inter')),
                                  trailing: ref.watch(localeProvider).languageCode == (languageLocales[lang]?.languageCode ?? 'en')
                                      ? Icon(Icons.check, color: AppColors.primary(isDark))
                                      : null,
                                  onTap: () {
                                    ref.read(localeProvider.notifier).setLocaleByLanguageName(lang);
                                    Navigator.pop(ctx);
                                  },
                                )),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    _MenuItem(
                      icon: Icons.notifications_active_outlined,
                      iconBg: _tint(AppColors.primary(isDark), isDark),
                      iconFg: AppColors.primary(isDark),
                      label: 'Notifications',
                      subtitle: 'Alerts & smart reminders',
                      onTap: () => context.push(AppConfig.notificationsSettings),
                    ),
                    _MenuItem(
                      icon: Icons.folder_outlined,
                      iconBg: _tint(AppColors.secondary(isDark), isDark),
                      iconFg: AppColors.secondary(isDark),
                      label: 'Medical Records',
                      subtitle: 'Documents & imaging',
                      onTap: () => context.push(AppConfig.medicalRecords),
                    ),
                    _MenuItem(
                      icon: Icons.translate,
                      iconBg: _tint(AppColors.primaryContainer(isDark), isDark),
                      iconFg: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.primary(isDark),
                      label: 'Medical Translation',
                      subtitle: 'Translate medical terms',
                      onTap: () => context.push(AppConfig.translation),
                    ),
                    _MenuItem(
                      icon: Icons.badge_outlined,
                      iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                      iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                      label: 'Medical ID',
                      subtitle: 'Emergency medical card',
                      onTap: () => context.push(AppConfig.medicalId),
                    ),
                  ],
                ),

                // ── Privacy & Data ──
                _MenuSection(
                  title: 'Privacy & Data',
                  isDark: isDark,
                  children: [
                    _MenuItem(
                      icon: Icons.shield_outlined,
                      iconBg: _tint(AppColors.error(isDark), isDark),
                      iconFg: AppColors.error(isDark),
                      label: 'Security & Storage',
                      subtitle: 'AES-256 encryption active',
                      // Points to the Settings screen (where data-management
                      // + security toggles live) — NOT the Privacy Policy page.
                      onTap: () => context.push(AppConfig.settings),
                    ),
                    _MenuItem(
                      icon: Icons.download_outlined,
                      iconBg: _tint(AppColors.primary(isDark), isDark),
                      iconFg: AppColors.primary(isDark),
                      label: 'Export Data',
                      subtitle: 'Download your health data',
                      onTap: () => context.push(AppConfig.exportScreen),
                    ),
                  ],
                ),

                // ── Support ──
                _MenuSection(
                  title: 'Support',
                  isDark: isDark,
                  children: [
                    _MenuItem(
                      icon: Icons.settings_outlined,
                      iconBg: _tint(AppColors.primary(isDark), isDark),
                      iconFg: AppColors.primary(isDark),
                      label: 'Settings',
                      subtitle: 'Theme, password, account',
                      onTap: () => context.push(AppConfig.settings),
                    ),
                    _MenuItem(
                      icon: Icons.help_outline,
                      iconBg: _tint(AppColors.secondary(isDark), isDark),
                      iconFg: AppColors.secondary(isDark),
                      label: 'Help Center',
                      subtitle: 'FAQs & documentation',
                      onTap: () => context.push(AppConfig.helpSupport),
                    ),
                    _MenuItem(
                      icon: Icons.support_agent,
                      iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                      iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                      label: 'Contact Concierge',
                      subtitle: 'Priority Pro support',
                      onTap: () => context.push(AppConfig.helpSupport),
                    ),
                  ],
                ),

                // ── About ──
                _MenuSection(
                  title: 'About',
                  isDark: isDark,
                  children: [
                    _MenuItem(
                      icon: Icons.info_outline,
                      iconBg: _tint(AppColors.primary(isDark), isDark),
                      iconFg: AppColors.primary(isDark),
                      label: 'About VitalSeker',
                      subtitle: 'Version ${AppConfig.version}',
                      onTap: () => context.push(AppConfig.about),
                    ),
                    _MenuItem(
                      icon: Icons.description_outlined,
                      iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                      iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                      label: 'Terms of Service',
                      onTap: () => context.push(AppConfig.termsOfService),
                    ),
                    _MenuItem(
                      icon: Icons.privacy_tip_outlined,
                      iconBg: _tint(AppColors.secondary(isDark), isDark),
                      iconFg: AppColors.secondary(isDark),
                      label: 'Privacy Policy',
                      onTap: () => context.push(AppConfig.privacyPolicy),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Sign out ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isSigningOut ? null : _signOut,
                    icon: _isSigningOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.logout, color: AppColors.urgencyEmergency),
                    label: Text(
                      _isSigningOut ? 'Signing out...' : 'Sign Out',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.urgencyEmergency,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.urgencyEmergency.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                  ),
                ),

                // ── Footer ──
                const SizedBox(height: 24),
                Text(
                  'Powered by Keter Marketing',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary(isDark).withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  String _themeSubtitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      default:
        return 'System default';
    }
  }

  /// Build a soft tinted background square (40×40, radius 10) for menu icons.
  Color _tint(Color base, bool isDark) {
    if (isDark) {
      return base.withValues(alpha: 0.18);
    }
    // For light surfaces, primary/secondary green can be too saturated at full
    // strength — soften the background while keeping the icon vibrant.
    if (base == AppColors.primary(isDark) || base == AppColors.secondary(isDark)) {
      return base.withValues(alpha: 0.12);
    }
    if (base == AppColors.error(isDark)) {
      return const Color(0xFFFFDAD6); // matches design error-container
    }
    return base.withValues(alpha: 0.25);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _StatCard({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.subtleBackground(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight(isDark)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.monoRegular.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint(isDark),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;

  const _MenuSection({required this.title, required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary(isDark).withValues(alpha: 0.85),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? AppColors.darkOutlineVariant
                  : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: _withDividers(children, isDark)),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> items, bool isDark) {
    if (items.length <= 1) return items;
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(Divider(
          height: 1,
          thickness: 1,
          indent: 72,
          color: isDark
              ? AppColors.darkOutlineVariant
              : Colors.black.withValues(alpha: 0.05),
        ));
      }
    }
    return result;
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chevron = trailing ??
        Icon(Icons.chevron_right, size: 20, color: AppColors.outlineVariant(isDark));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconFg, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.subheading2.copyWith(
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            chevron,
          ],
        ),
      ),
    );
  }
}

/// Profile header avatar — renders the uploaded profile picture when
/// `avatarUrl` is set, falling back to a colored circle with the user's
/// initials. The initials color is theme-aware so it stays readable on the
/// `primaryContainer` background in both light and dark mode (previously the
/// light-mode avatar used `Colors.white` on a light-mint container, which was
/// unreadable).
///
/// Uses [Image.network] with explicit loading + error builders so a slow or
/// failing network image degrades gracefully to the initials placeholder
/// instead of showing a blank circle.
class _ProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final bool isDark;
  final VoidCallback? onTap;

  const _ProfileAvatar({
    required this.avatarUrl,
    required this.initials,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    final initialsWidget = Center(
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'ClashDisplay',
          fontSize: 36,
          fontWeight: FontWeight.w800,
          // In dark mode the container is Deep Forest (#050F0B) — light mint
          // text reads well. In light mode the container is Clean Mint
          // (#E9FEF6) — we use the dark primary green so the initials stay
          // legible instead of the previous `Colors.white` which was
          // unreadable on the light-mint surface.
          color: isDark
              ? AppColors.lightPrimaryContainer
              : AppColors.primary(isDark),
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104, // radius 52 → diameter 104
        height: 104,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryContainer(isDark),
        ),
        child: ClipOval(
          child: hasAvatar
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  width: 104,
                  height: 104,
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
