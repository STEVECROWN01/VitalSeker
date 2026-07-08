import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
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
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.areYouSureSignOut),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.urgencyEmergency),
            child: Text(l10n.signOut),
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
        if (mounted) AppSnackBar.errorFromException(context, l10n.failedToSignOut, e);
      } finally {
        if (mounted) setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(userProfileProvider);
    final isPro = ref.watch(isProUserProvider);
    final familyAsync = ref.watch(familyProfilesProvider);
    final familyCount = familyAsync.maybeWhen(data: (list) => list.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.profile,
          style: AppTextStyles.heading3.copyWith(color: AppColors.primary(isDark)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => context.push(AppConfig.settings),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: l10n.notifications,
            onPressed: () => context.push(AppConfig.notificationsSettings),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('Profile load error: $e');
          return Center(child: Text(l10n.somethingWentWrong));
        },
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
                                l10n.vitalSekerPro,
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
                                  l10n.upgradeToPro,
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
                          label: l10n.vitalsLogged,
                          value: '$vitalsCount',
                          isDark: isDark),
                      const SizedBox(width: 12),
                      _StatCard(
                          label: l10n.triageSessions,
                          value: '$triageCount',
                          isDark: isDark),
                      const SizedBox(width: 12),
                      _StatCard(
                          label: l10n.daysActive,
                          value: '$daysActive',
                          isDark: isDark),
                    ],
                  );
                }),
                const SizedBox(height: 24),

                // ── Health Features (profile-specific) ──
                _MenuSection(
                  title: l10n.health,
                  isDark: isDark,
                  children: [
                    _MenuItem(
                      icon: Icons.badge_outlined,
                      iconBg: _tint(AppColors.secondary(isDark), isDark),
                      iconFg: AppColors.secondary(isDark),
                      label: l10n.healthPassport,
                      subtitle: l10n.manageMedicalCredentials,
                      onTap: () => context.push(AppConfig.passport),
                    ),
                    _MenuItem(
                      icon: Icons.folder_outlined,
                      iconBg: _tint(AppColors.secondary(isDark), isDark),
                      iconFg: AppColors.secondary(isDark),
                      label: l10n.medicalRecords,
                      subtitle: l10n.documentsImaging,
                      onTap: () => context.push(AppConfig.medicalRecords),
                    ),
                    _MenuItem(
                      icon: Icons.badge_outlined,
                      iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                      iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                      label: l10n.medicalID,
                      subtitle: l10n.emergencyMedicalCard,
                      onTap: () => context.push(AppConfig.medicalId),
                    ),
                    _MenuItem(
                      icon: Icons.translate,
                      iconBg: _tint(AppColors.primaryContainer(isDark), isDark),
                      iconFg: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.primary(isDark),
                      label: l10n.medicalTranslation,
                      subtitle: l10n.translateMedicalTermsSubtitle,
                      onTap: () => context.push(AppConfig.translation),
                    ),
                  ],
                ),

                // ── Family ──
                _MenuSection(
                  title: l10n.family,
                  isDark: isDark,
                  children: [
                    _MenuItem(
                      icon: Icons.family_restroom,
                      iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                      iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                      label: l10n.familyProfiles,
                      subtitle: l10n.connectedMembers(familyCount),
                      onTap: () => context.push(AppConfig.family),
                    ),
                  ],
                ),

                // ── About & Legal ──
                _MenuSection(
                  title: l10n.about,
                  isDark: isDark,
                  children: [
                    _MenuItem(
                      icon: Icons.info_outline,
                      iconBg: _tint(AppColors.primary(isDark), isDark),
                      iconFg: AppColors.primary(isDark),
                      label: l10n.aboutVitalSeker,
                      subtitle: l10n.aboutVitalSekerVersion(AppConfig.version),
                      onTap: () => context.push(AppConfig.about),
                    ),
                    _MenuItem(
                      icon: Icons.description_outlined,
                      iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                      iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                      label: l10n.termsOfService,
                      onTap: () => context.push(AppConfig.termsOfService),
                    ),
                    _MenuItem(
                      icon: Icons.privacy_tip_outlined,
                      iconBg: _tint(AppColors.secondary(isDark), isDark),
                      iconFg: AppColors.secondary(isDark),
                      label: l10n.privacyPolicy,
                      onTap: () => context.push(AppConfig.privacyPolicy),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Settings ──
                _MenuSection(
                  title: l10n.settings,
                  isDark: isDark,
                  children: [
                    _MenuItem(
                      icon: Icons.settings_outlined,
                      iconBg: _tint(AppColors.primary(isDark), isDark),
                      iconFg: AppColors.primary(isDark),
                      label: l10n.settings,
                      subtitle: l10n.themePasswordAccount,
                      onTap: () => context.push(AppConfig.settings),
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
                      _isSigningOut ? l10n.signingOut : l10n.signOut,
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
                  l10n.poweredBy,
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

  String _themeSubtitle(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.dark:
        return l10n.dark;
      case ThemeMode.light:
        return l10n.light;
      default:
        return l10n.systemDefault;
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
              ? CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  fit: BoxFit.cover,
                  width: 104,
                  height: 104,
                  
                  progressIndicatorBuilder: (context, url, downloadProgress) {
                    if (downloadProgress == null) return const SizedBox.shrink();
                    return initialsWidget;
                  },
                  errorWidget: (context, error, stackTrace) =>
                      initialsWidget,
                )
              : initialsWidget,
        ),
      ),
    );
  }
}
