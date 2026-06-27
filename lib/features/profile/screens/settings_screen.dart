import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/family_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedLanguage = 'English (US)';

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
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        if (mounted) context.go(AppConfig.login);
      } catch (e) {
        if (mounted) AppSnackBar.errorFromException(context, l10n.failedToSignOut, e);
      }
    }
  }

  void _showChangePasswordDialog() {
    final l10n = AppLocalizations.of(context)!;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isChanging = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.changePassword, style: const TextStyle(fontFamily: 'ClashDisplay')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.currentPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.newPassword,
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.confirmNewPassword,
                  prefixIcon: const Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: isChanging ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.passwordsDoNotMatch)),
                  );
                  return;
                }
                if (newPasswordController.text.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.passwordMinLength)),
                  );
                  return;
                }
                setDialogState(() => isChanging = true);
                try {
                  final authService = ref.read(authServiceProvider);
                  await authService.updatePassword(newPasswordController.text);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.passwordUpdatedSuccessfully),
                        backgroundColor: AppColors.success(isDark),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) AppSnackBar.errorFromException(context, l10n.failedToUpdatePassword, e);
                  setDialogState(() => isChanging = false);
                }
              },
              child: isChanging
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.update),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final l10n = AppLocalizations.of(context)!;
    final email = ref.read(userProfileProvider).valueOrNull?.email ??
        ref.read(currentUserProvider)?.email ??
        '';
    final confirmController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: !isDeleting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.urgencyEmergency),
              const SizedBox(width: 8),
              Text(l10n.deleteAccount, style: const TextStyle(fontFamily: 'ClashDisplay')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deleteAccountIrreversible,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.typeEmailToConfirm,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(Theme.of(context).brightness == Brightness.dark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary(Theme.of(context).brightness == Brightness.dark),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !isDeleting,
                decoration: const InputDecoration(
                  hintText: 'your.email@example.com',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      final typed = confirmController.text.trim().toLowerCase();
                      if (typed.isEmpty || typed != email.toLowerCase()) {
                        AppSnackBar.error(context, l10n.emailDoesNotMatch);
                        return;
                      }
                      setDialogState(() => isDeleting = true);
                      try {
                        final edgeService = EdgeFunctionService();
                        await edgeService.deleteAccount(confirmEmail: typed);
                        // Sign out from all providers. Note: the previous
                        // comment claimed this "explicitly revokes the Google
                        // token" but signOut() only clears the local Supabase
                        // session — it does NOT call GoogleSignIn.disconnect()
                        // or revoke the OAuth grant. The user CAN silently
                        // re-login with the same Google account after deletion
                        // (the account itself is gone, but a new account could
                        // be created). For full token revocation, call
                        // GoogleSignIn().disconnect() before signOut().
                        try {
                          await GoogleSignIn().disconnect();
                        } catch (_) {
                          // Ignore if Google Sign-In was never used or
                          // is not configured for this platform.
                        }
                        try {
                          await ref.read(authServiceProvider).signOut();
                        } catch (_) {
                          // signOut may throw if the session was already
                          // invalidated by the edge function; ignore.
                        }
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        AppSnackBar.success(context, l10n.accountDeleted);
                        // Clear ALL cached state so the login screen shows fresh.
                        ref.invalidate(userProfileProvider);
                        ref.invalidate(authStateProvider);
                        if (mounted) context.go(AppConfig.login);
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => isDeleting = false);
                        AppSnackBar.errorFromException(
                          context,
                          l10n.failedToDeleteAccount,
                          e,
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.urgencyEmergency,
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.deletePermanently),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use the full 26-language list from locale_provider (matches the Profile
    // screen). Previously this only offered 6 languages — a confusing subset
    // that didn't include Portuguese, German, Chinese, etc.
    final langs = languageLocales.keys.toList();
    final currentLocale = ref.read(localeProvider);
    final currentLangName = localeToLanguageName(currentLocale);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.selectLanguage,
                  style: AppTextStyles.heading4.copyWith(color: AppColors.textPrimary(isDark)),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: langs.length,
                  itemBuilder: (ctx, i) {
                    final lang = langs[i];
                    return ListTile(
                      title: Text(lang, style: AppTextStyles.bodyMedium),
                      trailing: currentLangName == lang
                          ? Icon(Icons.check, color: AppColors.primary(isDark))
                          : null,
                      onTap: () {
                        // Actually call localeProvider so the locale changes
                        // immediately and persists to the DB (was previously
                        // a no-op that only updated a local field).
                        ref.read(localeProvider.notifier).setLocaleByLanguageName(lang);
                        setState(() => _selectedLanguage = lang);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Color _tint(Color base, bool isDark) {
    if (isDark) return base.withValues(alpha: 0.18);
    if (base == AppColors.primary(isDark) || base == AppColors.secondary(isDark)) {
      return base.withValues(alpha: 0.12);
    }
    if (base == AppColors.error(isDark)) return const Color(0xFFFFDAD6);
    return base.withValues(alpha: 0.25);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final isPro = ref.watch(isProUserProvider);
    final familyAsync = ref.watch(familyProfilesProvider);
    final familyCount = familyAsync.maybeWhen(data: (list) => list.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: AppTextStyles.heading3.copyWith(color: AppColors.primary(isDark)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // ── Appearance ──
            _SettingsSection(
              title: l10n.appearance,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  iconBg: _tint(AppColors.primary(isDark), isDark),
                  iconFg: AppColors.primary(isDark),
                  label: l10n.darkMode,
                  subtitle: _themeSubtitle(themeMode, l10n),
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
                _SettingsTile(
                  icon: Icons.language,
                  iconBg: _tint(AppColors.primaryContainer(isDark), isDark),
                  iconFg: isDark ? AppColors.darkOnSurface : AppColors.primary(isDark),
                  label: l10n.language,
                  // Reflect the current locale from localeProvider (was previously
                  // always hardcoded 'English (US)' — never updated).
                  subtitle: localeToLanguageName(ref.watch(localeProvider)),
                  onTap: _showLanguageSheet,
                ),
              ],
            ),

            // ── Account ──
            _SettingsSection(
              title: l10n.account,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.badge_outlined,
                  iconBg: _tint(AppColors.secondary(isDark), isDark),
                  iconFg: AppColors.secondary(isDark),
                  label: l10n.healthPassport,
                  subtitle: l10n.manageMedicalCredentials,
                  onTap: () => context.push(AppConfig.passport),
                ),
                _SettingsTile(
                  icon: Icons.family_restroom,
                  iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                  iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                  label: l10n.familyProfiles,
                  subtitle: l10n.connectedMembers(familyCount),
                  onTap: () => context.push(AppConfig.family),
                ),
                _SettingsTile(
                  icon: Icons.email_outlined,
                  iconBg: _tint(AppColors.primary(isDark), isDark),
                  iconFg: AppColors.primary(isDark),
                  label: l10n.email,
                  subtitle: profileAsync.maybeWhen(
                    data: (p) => p?.email ?? l10n.nA,
                    orElse: () => l10n.loading,
                  ),
                  trailing: Icon(Icons.lock_outline, size: 18, color: AppColors.textHint(isDark)),
                ),
                _SettingsTile(
                  icon: Icons.lock_outline,
                  iconBg: _tint(AppColors.secondary(isDark), isDark),
                  iconFg: AppColors.secondary(isDark),
                  label: l10n.changePassword,
                  subtitle: l10n.updateAccountCredentials,
                  onTap: _showChangePasswordDialog,
                ),
                if (isPro)
                  _SettingsTile(
                    icon: Icons.workspace_premium_outlined,
                    iconBg: _tint(const Color(0xFFFFB74D), isDark),
                    iconFg: const Color(0xFFFF9800),
                    label: l10n.vitalSekerPro,
                    subtitle: l10n.manageYourSubscription,
                    onTap: () => context.push(AppConfig.subscription),
                  ),
              ],
            ),

            // ── Privacy & Data ──
            _SettingsSection(
              title: l10n.privacyData,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  iconBg: _tint(AppColors.error(isDark), isDark),
                  iconFg: AppColors.error(isDark),
                  label: l10n.securityStorage,
                  subtitle: l10n.aes256EncryptionActive,
                  onTap: () => AppSnackBar.info(context, l10n.securitySettingsOnThisPage),
                ),
                _SettingsTile(
                  icon: Icons.download_outlined,
                  iconBg: _tint(AppColors.primary(isDark), isDark),
                  iconFg: AppColors.primary(isDark),
                  label: l10n.exportData,
                  subtitle: l10n.downloadYourHealthData,
                  onTap: () => context.push(AppConfig.exportScreen),
                ),
                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  iconBg: _tint(AppColors.urgencyEmergency, isDark),
                  iconFg: AppColors.urgencyEmergency,
                  label: l10n.deleteAccount,
                  subtitle: l10n.permanentlyRemoveYourData,
                  onTap: _showDeleteAccountDialog,
                ),
              ],
            ),

            // ── Support ──
            _SettingsSection(
              title: l10n.support,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.help_outline,
                  iconBg: _tint(AppColors.secondary(isDark), isDark),
                  iconFg: AppColors.secondary(isDark),
                  label: l10n.helpCenter,
                  subtitle: l10n.faqsDocumentation,
                  onTap: () => context.push(AppConfig.helpSupport),
                ),
                _SettingsTile(
                  icon: Icons.support_agent,
                  iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                  iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                  label: l10n.contactConcierge,
                  subtitle: l10n.priorityProSupport,
                  onTap: () => context.push(AppConfig.helpSupport),
                ),
                _SettingsTile(
                  icon: Icons.logout,
                  iconBg: _tint(AppColors.urgencyEmergency, isDark),
                  iconFg: AppColors.urgencyEmergency,
                  label: l10n.signOut,
                  subtitle: l10n.endYourCurrentSession,
                  onTap: _signOut,
                ),
              ],
            ),

            // ── About ──
            _SettingsSection(
              title: l10n.about,
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.info_outline,
                  iconBg: _tint(AppColors.primary(isDark), isDark),
                  iconFg: AppColors.primary(isDark),
                  label: l10n.aboutVitalSeker,
                  subtitle: l10n.aboutVitalSekerVersion(AppConfig.version),
                  onTap: () => context.push(AppConfig.about),
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                  iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                  label: l10n.termsOfService,
                  onTap: () => context.push(AppConfig.termsOfService),
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconBg: _tint(AppColors.secondary(isDark), isDark),
                  iconFg: AppColors.secondary(isDark),
                  label: l10n.privacyPolicy,
                  onTap: () => context.push(AppConfig.privacyPolicy),
                ),
              ],
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
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;

  const _SettingsSection({
    required this.title,
    required this.children,
    required this.isDark,
  });

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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
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
        (onTap != null
            ? Icon(Icons.chevron_right, size: 20, color: AppColors.outlineVariant(isDark))
            : null);

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
            if (chevron != null) chevron,
          ],
        ),
      ),
    );
  }
}
