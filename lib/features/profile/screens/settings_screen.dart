import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/theme/app_colors.dart';

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign out failed: $e')),
          );
        }
      }
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(fontFamily: 'ClashDisplay')),
        content: const Text(
          'This action is irreversible. All your data will be permanently deleted. Are you sure?',
          style: TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion coming soon')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.urgencyEmergency),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
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
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
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
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
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
                                color: isDark ? Colors.white : AppColors.lightOnBackground,
                              ),
                            ),
                          ),
                          ...['English', 'French', 'Spanish', 'Arabic', 'Swahili'].map((lang) => ListTile(
                            title: Text(lang, style: const TextStyle(fontFamily: 'Inter')),
                            trailing: _selectedLanguage == lang
                                ? const Icon(Icons.check, color: AppColors.lightPrimary)
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
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
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
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data export coming soon!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: AppColors.urgencyEmergency),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(fontFamily: 'Inter', color: AppColors.urgencyEmergency),
                ),
                subtitle: Text(
                  'Permanently remove your data',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
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
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                ),
                trailing: Icon(Icons.lock_outline, size: 16, color: isDark ? AppColors.grey500 : AppColors.grey400),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change Password', style: TextStyle(fontFamily: 'Inter')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password change coming soon!')),
                  );
                },
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
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service', style: TextStyle(fontFamily: 'Inter')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Terms page coming soon!')),
                  );
                },
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
              color: isDark ? AppColors.grey500 : AppColors.grey400,
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
