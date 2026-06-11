import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/user_profile_provider.dart';
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

  String _triageSchedule = 'Daily at 9:00 AM';
  String _medicationSchedule = 'Per prescription schedule';
  String _appointmentSchedule = '1 day before';
  String _vitalsSchedule = 'Daily at 8:00 AM';
  String _healthTipsSchedule = '3 times per week';
  String _weeklyReportSchedule = 'Every Monday at 10:00 AM';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        color: AppColors.lightPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.healing_outlined, color: AppColors.lightPrimary, size: 20),
                    ),
                    title: const Text('Triage Reminders', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _triageSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    value: _triageReminders,
                    activeColor: AppColors.lightPrimary,
                    onChanged: (v) => setState(() => _triageReminders = v),
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
                    activeColor: AppColors.lightPrimary,
                    onChanged: (v) => setState(() => _medicationReminders = v),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.lightSecondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_outlined, color: AppColors.lightSecondary, size: 20),
                    ),
                    title: const Text('Appointment Reminders', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _appointmentSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    value: _appointmentReminders,
                    activeColor: AppColors.lightPrimary,
                    onChanged: (v) => setState(() => _appointmentReminders = v),
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
                    activeColor: AppColors.lightPrimary,
                    onChanged: (v) => setState(() => _vitalsLoggingReminders = v),
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
                    activeColor: AppColors.lightPrimary,
                    onChanged: (v) => setState(() => _healthTips = v),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.lightPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.summarize_outlined, color: AppColors.lightPrimary, size: 20),
                    ),
                    title: const Text('Weekly Report', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _weeklyReportSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500),
                    ),
                    value: _weeklyReport,
                    activeColor: AppColors.lightPrimary,
                    onChanged: (v) => setState(() => _weeklyReport = v),
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
                      'Notification schedules can be customized further in a future update. Your preferences are saved locally.',
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
