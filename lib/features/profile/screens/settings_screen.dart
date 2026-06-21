import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/family_provider.dart';
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
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        if (mounted) context.go(AppConfig.login);
      } catch (e) {
        if (mounted) AppSnackBar.errorFromException(context, 'Failed to sign out. Please try again.', e);
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isChanging = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Password', style: TextStyle(fontFamily: 'ClashDisplay')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isChanging ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
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
                        content: const Text('Password updated successfully'),
                        backgroundColor: AppColors.success(isDark),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) AppSnackBar.errorFromException(context, 'Failed to update password. Please try again.', e);
                  setDialogState(() => isChanging = false);
                }
              },
              child: isChanging
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
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
              const Text('Delete Account', style: TextStyle(fontFamily: 'ClashDisplay')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is irreversible. All your data — vitals, medications, appointments, symptom logs, family profiles, and health passport — will be permanently deleted.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                'Type your email to confirm:',
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      final typed = confirmController.text.trim().toLowerCase();
                      if (typed.isEmpty || typed != email.toLowerCase()) {
                        AppSnackBar.error(context, 'Email does not match.');
                        return;
                      }
                      setDialogState(() => isDeleting = true);
                      try {
                        final edgeService = EdgeFunctionService();
                        await edgeService.deleteAccount(confirmEmail: typed);
                        try {
                          await ref.read(authServiceProvider).signOut();
                        } catch (_) {
                          // signOut may throw if the session was already invalidated; ignore.
                        }
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        AppSnackBar.success(context, 'Account deleted. Sorry to see you go.');
                        ref.invalidate(userProfileProvider);
                        if (mounted) context.go(AppConfig.login);
                      } catch (e) {
                        if (!mounted) return;
                        setDialogState(() => isDeleting = false);
                        AppSnackBar.errorFromException(
                          context,
                          'Failed to delete account. Please try again or contact support.',
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
                  : const Text('Delete Permanently'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langs = ['English (US)', 'English (UK)', 'French', 'Spanish', 'Arabic', 'Swahili'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Language',
                style: AppTextStyles.heading4.copyWith(color: AppColors.textPrimary(isDark)),
              ),
            ),
            ...langs.map((lang) => ListTile(
              title: Text(lang, style: AppTextStyles.bodyMedium),
              trailing: _selectedLanguage == lang
                  ? Icon(Icons.check, color: AppColors.primary(isDark))
                  : null,
              onTap: () {
                setState(() => _selectedLanguage = lang);
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 8),
          ],
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
    final themeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final isPro = ref.watch(isProUserProvider);
    final familyAsync = ref.watch(familyProfilesProvider);
    final familyCount = familyAsync.maybeWhen(data: (list) => list.length, orElse: () => 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTextStyles.heading3.copyWith(color: AppColors.primary(isDark)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // ── Appearance ──
            _SettingsSection(
              title: 'Appearance',
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  iconBg: _tint(AppColors.primary(isDark), isDark),
                  iconFg: AppColors.primary(isDark),
                  label: 'Dark Mode',
                  subtitle: _themeSubtitle(themeMode),
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
                  label: 'Language',
                  subtitle: _selectedLanguage,
                  onTap: _showLanguageSheet,
                ),
              ],
            ),

            // ── Account ──
            _SettingsSection(
              title: 'Account',
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.badge_outlined,
                  iconBg: _tint(AppColors.secondary(isDark), isDark),
                  iconFg: AppColors.secondary(isDark),
                  label: 'Health Passport',
                  subtitle: 'Manage medical credentials',
                  onTap: () => context.push(AppConfig.passport),
                ),
                _SettingsTile(
                  icon: Icons.family_restroom,
                  iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                  iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                  label: 'Family Profiles',
                  subtitle: '$familyCount connected member${familyCount == 1 ? '' : 's'}',
                  onTap: () => context.push(AppConfig.family),
                ),
                _SettingsTile(
                  icon: Icons.email_outlined,
                  iconBg: _tint(AppColors.primary(isDark), isDark),
                  iconFg: AppColors.primary(isDark),
                  label: 'Email',
                  subtitle: profileAsync.maybeWhen(
                    data: (p) => p?.email ?? 'N/A',
                    orElse: () => 'Loading...',
                  ),
                  trailing: Icon(Icons.lock_outline, size: 18, color: AppColors.textHint(isDark)),
                ),
                _SettingsTile(
                  icon: Icons.lock_outline,
                  iconBg: _tint(AppColors.secondary(isDark), isDark),
                  iconFg: AppColors.secondary(isDark),
                  label: 'Change Password',
                  subtitle: 'Update your account credentials',
                  onTap: _showChangePasswordDialog,
                ),
                if (isPro)
                  _SettingsTile(
                    icon: Icons.workspace_premium_outlined,
                    iconBg: _tint(const Color(0xFFFFB74D), isDark),
                    iconFg: const Color(0xFFFF9800),
                    label: 'VitalSeker Pro',
                    subtitle: 'Manage your subscription',
                    onTap: () => context.push(AppConfig.subscription),
                  ),
              ],
            ),

            // ── Privacy & Data ──
            _SettingsSection(
              title: 'Privacy & Data',
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  iconBg: _tint(AppColors.error(isDark), isDark),
                  iconFg: AppColors.error(isDark),
                  label: 'Security & Storage',
                  subtitle: 'AES-256 encryption active',
                  onTap: () => context.push(AppConfig.privacyPolicy),
                ),
                _SettingsTile(
                  icon: Icons.download_outlined,
                  iconBg: _tint(AppColors.primary(isDark), isDark),
                  iconFg: AppColors.primary(isDark),
                  label: 'Export Data',
                  subtitle: 'Download your health data',
                  onTap: () => context.push(AppConfig.exportScreen),
                ),
                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  iconBg: _tint(AppColors.urgencyEmergency, isDark),
                  iconFg: AppColors.urgencyEmergency,
                  label: 'Delete Account',
                  subtitle: 'Permanently remove your data',
                  onTap: _showDeleteAccountDialog,
                ),
              ],
            ),

            // ── Support ──
            _SettingsSection(
              title: 'Support',
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.help_outline,
                  iconBg: _tint(AppColors.secondary(isDark), isDark),
                  iconFg: AppColors.secondary(isDark),
                  label: 'Help Center',
                  subtitle: 'FAQs & documentation',
                  onTap: () => context.push(AppConfig.helpSupport),
                ),
                _SettingsTile(
                  icon: Icons.support_agent,
                  iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                  iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                  label: 'Contact Concierge',
                  subtitle: 'Priority Pro support',
                  onTap: () => context.push(AppConfig.helpSupport),
                ),
                _SettingsTile(
                  icon: Icons.logout,
                  iconBg: _tint(AppColors.urgencyEmergency, isDark),
                  iconFg: AppColors.urgencyEmergency,
                  label: 'Sign Out',
                  subtitle: 'End your current session',
                  onTap: _signOut,
                ),
              ],
            ),

            // ── About ──
            _SettingsSection(
              title: 'About',
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.info_outline,
                  iconBg: _tint(AppColors.primary(isDark), isDark),
                  iconFg: AppColors.primary(isDark),
                  label: 'About VitalSeker',
                  subtitle: 'Version ${AppConfig.version}',
                  onTap: () => context.push(AppConfig.about),
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  iconBg: _tint(const Color(0xFF5B6F6A), isDark),
                  iconFg: isDark ? const Color(0xFFB6CBC5) : const Color(0xFF3E4944),
                  label: 'Terms of Service',
                  onTap: () => context.push(AppConfig.termsOfService),
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconBg: _tint(AppColors.secondary(isDark), isDark),
                  iconFg: AppColors.secondary(isDark),
                  label: 'Privacy Policy',
                  onTap: () => context.push(AppConfig.privacyPolicy),
                ),
              ],
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
