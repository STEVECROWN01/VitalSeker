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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign out failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                // Avatar and user info
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: (AppColors.primary(isDark)).withValues(alpha: 0.12),
                        child: Text(
                          (profile?.fullName ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary(isDark),
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
                          color: AppColors.textPrimary(isDark),
                        ),
                      ),
                      Text(
                        profile?.email ?? '',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.textSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    _StatCard(
                      label: 'Vitals Logged',
                      value: '--',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Triage Sessions',
                      value: '--',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Days Active',
                      value: '--',
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Menu items
                _MenuSection(title: 'Profile', children: [
                  _MenuItem(
                    icon: Icons.edit_outlined,
                    label: 'Edit Profile',
                    onTap: () => context.push(AppConfig.editProfile),
                  ),
                  _MenuItem(
                    icon: Icons.folder_outlined,
                    label: 'Medical Records',
                    onTap: () => context.push(AppConfig.medicalRecords),
                  ),
                  _MenuItem(
                    icon: Icons.badge_outlined,
                    label: 'Medical ID',
                    onTap: () => context.push(AppConfig.medicalId),
                  ),
                ], isDark: isDark),

                _MenuSection(title: 'Health', children: [
                  _MenuItem(
                    icon: Icons.medication_outlined,
                    label: 'Medications',
                    onTap: () => context.push(AppConfig.medications),
                  ),
                  _MenuItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Appointments',
                    onTap: () => context.push(AppConfig.appointments),
                  ),
                  _MenuItem(
                    icon: Icons.translate,
                    label: 'Medical Translation',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon')),
                      );
                    },
                  ),
                ], isDark: isDark),

                _MenuSection(title: 'Support', children: [
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.push(AppConfig.settings),
                  ),
                  _MenuItem(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    onTap: () => context.push(AppConfig.helpSupport),
                  ),
                  _MenuItem(
                    icon: Icons.info_outline,
                    label: 'About VitalSeker',
                    onTap: () => context.push(AppConfig.about),
                  ),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => context.push(AppConfig.privacyPolicy),
                  ),
                ], isDark: isDark),

                const SizedBox(height: 16),

                // Sign out button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isSigningOut ? null : _signOut,
                    icon: _isSigningOut
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.logout, color: AppColors.urgencyEmergency),
                    label: Text(
                      _isSigningOut ? 'Signing out...' : 'Sign Out',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                        color: AppColors.urgencyEmergency,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.urgencyEmergency),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
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
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: AppColors.textHint(isDark),
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

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
