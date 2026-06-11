import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/database_service.dart';
import '../../../shared/theme/app_colors.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends ConsumerState<NotificationsSettingsScreen> {
  bool _triageReminders = true;
  bool _medicationReminders = true;
  bool _appointmentReminders = true;
  bool _vitalsLoggingReminders = true;
  bool _healthTips = true;
  bool _weeklyReport = true;
  bool _isLoaded = false;

  String _triageSchedule = 'Daily at 9:00 AM';
  String _medicationSchedule = 'Per prescription schedule';
  String _appointmentSchedule = '1 day before';
  String _vitalsSchedule = 'Daily at 8:00 AM';
  String _healthTipsSchedule = '3 times per week';
  String _weeklyReportSchedule = 'Every Monday at 10:00 AM';

  void _loadSettings() {
    if (_isLoaded) return;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null) {
      // Notification preferences are stored in the user's metadata
      // For now we use defaults; in production this would come from the profile
      _isLoaded = true;
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = DatabaseService();
      await db.updateUserProfile(user.id, {
        'notification_prefs': {
          'triage_reminders': _triageReminders,
          'medication_reminders': _medicationReminders,
          'appointment_reminders': _appointmentReminders,
          'vitals_logging_reminders': _vitalsLoggingReminders,
          'health_tips': _healthTips,
          'weekly_report': _weeklyReport,
        },
      });
    } catch (_) {
      // Silently fail - settings still work in current session
    }
  }

  void _onChanged(void Function() setter, String key, bool value) {
    setState(setter);
    _saveSetting(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _loadSettings();

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reminders Section
            _SectionLabel(label: 'Reminders'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.healing_outlined, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 20),
                    ),
                    title: const Text('Triage Reminders', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _triageSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    value: _triageReminders,
                    activeColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    onChanged: (v) => _onChanged(() => _triageReminders = v, 'triage_reminders', v),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.lightInfo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.medication_outlined, color: AppColors.lightInfo, size: 20),
                    ),
                    title: const Text('Medication Reminders', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _medicationSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    value: _medicationReminders,
                    activeColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    onChanged: (v) => _onChanged(() => _medicationReminders = v, 'medication_reminders', v),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkSecondary : AppColors.lightSecondary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_today_outlined, color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary, size: 20),
                    ),
                    title: const Text('Appointment Reminders', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _appointmentSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    value: _appointmentReminders,
                    activeColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    onChanged: (v) => _onChanged(() => _appointmentReminders = v, 'appointment_reminders', v),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.lightWarning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.monitor_heart_outlined, color: AppColors.lightWarning, size: 20),
                    ),
                    title: const Text('Vitals Logging Reminders', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _vitalsSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    value: _vitalsLoggingReminders,
                    activeColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    onChanged: (v) => _onChanged(() => _vitalsLoggingReminders = v, 'vitals_logging_reminders', v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Insights Section
            _SectionLabel(label: 'Insights & Tips'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.lightSuccess.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lightbulb_outline, color: AppColors.lightSuccess, size: 20),
                    ),
                    title: const Text('Health Tips', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _healthTipsSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    value: _healthTips,
                    activeColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    onChanged: (v) => _onChanged(() => _healthTips = v, 'health_tips', v),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.summarize_outlined, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary, size: 20),
                    ),
                    title: const Text('Weekly Report', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _weeklyReportSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    value: _weeklyReport,
                    activeColor: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                    onChanged: (v) => _onChanged(() => _weeklyReport = v, 'weekly_report', v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Info note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightInfo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightInfo.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: isDark ? AppColors.darkInfo : AppColors.lightInfo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your notification preferences are saved to your account. Schedule customization will be available in a future update.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isDark ? AppColors.grey400 : AppColors.grey500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.grey500 : AppColors.grey400,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
