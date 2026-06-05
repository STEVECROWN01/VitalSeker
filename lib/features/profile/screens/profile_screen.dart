import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../shared/theme/app_colors.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final db = DatabaseService();
      await db.updateUserProfile(user.id, {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      ref.invalidate(userProfileProvider);
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                final profile = ref.read(userProfileProvider).valueOrNull;
                _nameController.text = profile?.fullName ?? '';
                _phoneController.text = profile?.phone ?? '';
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                // Avatar
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.lightPrimary.withValues(alpha: 0.12),
                        child: Text(
                          (profile?.fullName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppColors.lightPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile?.fullName ?? 'User',
                        style: TextStyle(
                          fontFamily: 'ClashDisplay',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.lightOnBackground,
                        ),
                      ),
                      Text(
                        profile?.email ?? '',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: isDark ? AppColors.grey400 : AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Edit fields
                if (_isEditing) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isSaving)
                    const Center(child: CircularProgressIndicator()),
                ],

                // Settings
                const SizedBox(height: 16),
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
                ]),

                _SettingsSection(title: 'Health', children: [
                  ListTile(
                    leading: const Icon(Icons.bloodtype_outlined),
                    title: const Text('Blood Type', style: TextStyle(fontFamily: 'Inter')),
                    subtitle: Text(
                      profile?.bloodType ?? 'Not set',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: const Text('Allergies', style: TextStyle(fontFamily: 'Inter')),
                    subtitle: Text(
                      profile?.allergies.isEmpty ?? true ? 'None' : profile!.allergies.join(', '),
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    leading: const Icon(Icons.contact_phone_outlined),
                    title: const Text('Emergency Contacts', style: TextStyle(fontFamily: 'Inter')),
                    subtitle: Text(
                      '${profile?.emergencyContacts.length ?? 0} contacts',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ]),

                _SettingsSection(title: 'Account', children: [
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('Subscription', style: TextStyle(fontFamily: 'Inter')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppConfig.subscription),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About VitalSeker', style: TextStyle(fontFamily: 'Inter')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppConfig.about),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.urgencyEmergency),
                    title: const Text('Sign Out', style: TextStyle(fontFamily: 'Inter', color: AppColors.urgencyEmergency)),
                    onTap: _signOut,
                  ),
                ]),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
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
