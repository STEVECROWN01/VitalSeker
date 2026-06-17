import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedLanguage = 'English';

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
                        // Account deleted — the auth.user row is gone, so sign
                        // out locally to clear the stale session and route to login.
                        try {
                          await ref.read(authServiceProvider).signOut();
                        } catch (_) {
                          // signOut may throw if the session was already invalidated; ignore.
                        }
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        AppSnackBar.success(context, 'Account deleted. Sorry to see you go.');
                        // Clear all cached profile state.
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // Appearance
            _SettingsSection(title: 'Appearance', children: [
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Theme', style: TextStyle(fontFamily: 'Inter')),
                subtitle: Text(
                  themeMode == ThemeMode.dark ? 'Dark' : themeMode == ThemeMode.light ? 'Light' : 'System',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                ),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (modes) {
                    ref.read(themeModeProvider.notifier).setTheme(modes.first);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('Language', style: TextStyle(fontFamily: 'Inter')),
                subtitle: Text(
                  _selectedLanguage,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                ),
                trailing: const Icon(Icons.chevron_right),
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
                          ...['English', 'French', 'Spanish', 'Arabic', 'Swahili'].map((lang) => ListTile(
                            title: Text(lang, style: const TextStyle(fontFamily: 'Inter')),
                            trailing: _selectedLanguage == lang
                                ? Icon(Icons.check, color: AppColors.primary(isDark))
                                : null,
                            onTap: () {
                              setState(() => _selectedLanguage = lang);
                              Navigator.pop(ctx);
                            },
                          )),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ]),

            // Notifications
            _SettingsSection(title: 'Notifications', children: [
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notification Settings', style: TextStyle(fontFamily: 'Inter')),
                subtitle: Text(
                  'Manage reminder preferences',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppConfig.notificationsSettings),
              ),
            ]),

            // Data & Privacy
            _SettingsSection(title: 'Data & Privacy', children: [
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Export Data', style: TextStyle(fontFamily: 'Inter')),
                subtitle: Text(
                  'Download your health data',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppConfig.exportScreen),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: AppColors.urgencyEmergency),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(fontFamily: 'Inter', color: AppColors.urgencyEmergency),
                ),
                subtitle: Text(
                  'Permanently remove your data',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.urgencyEmergency),
                onTap: _showDeleteAccountDialog,
              ),
            ]),

            // Account
            _SettingsSection(title: 'Account', children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email', style: TextStyle(fontFamily: 'Inter')),
                subtitle: Text(
                  profileAsync.maybeWhen(
                    data: (p) => p?.email ?? 'N/A',
                    orElse: () => 'Loading...',
                  ),
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                ),
                trailing: Icon(Icons.lock_outline, size: 16, color: AppColors.textHint(isDark)),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password', style: TextStyle(fontFamily: 'Inter')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePasswordDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.urgencyEmergency),
                title: const Text('Sign Out', style: TextStyle(fontFamily: 'Inter', color: AppColors.urgencyEmergency)),
                onTap: _signOut,
              ),
            ]),

            // About
            _SettingsSection(title: 'About', children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Version', style: TextStyle(fontFamily: 'Inter')),
                subtitle: Text(
                  AppConfig.version,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service', style: TextStyle(fontFamily: 'Inter')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppConfig.termsOfService),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy', style: TextStyle(fontFamily: 'Inter')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppConfig.privacyPolicy),
              ),
            ]),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint(isDark),
              letterSpacing: 1,
            ),
          ),
        ),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }
}
