import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../shared/theme/app_colors.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends ConsumerState<NotificationsSettingsScreen> {
  bool? _triageReminders;
  bool? _medicationReminders;
  bool? _appointmentReminders;
  bool? _vitalsLoggingReminders;
  bool? _healthTips;
  bool? _weeklyReport;

  // Schedule customization — now editable per the user's request.
  String _triageSchedule = 'Daily at 9:00 AM';
  String _medicationSchedule = 'Per prescription schedule';
  String _appointmentSchedule = '1 day before';
  String _vitalsSchedule = 'Daily at 8:00 AM';
  String _healthTipsSchedule = '3 times per week';
  String _weeklyReportSchedule = 'Every Monday at 10:00 AM';

  static const List<String> _triageScheduleOptions = [
    'Daily at 9:00 AM', 'Daily at 12:00 PM', 'Daily at 6:00 PM', 'Every 2 days', 'Weekly',
  ];
  static const List<String> _medicationScheduleOptions = [
    'Per prescription schedule', 'Every 4 hours', 'Every 8 hours', 'Twice daily',
  ];
  static const List<String> _appointmentScheduleOptions = [
    '1 day before', '2 hours before', '1 hour before', 'At appointment time',
  ];
  static const List<String> _vitalsScheduleOptions = [
    'Daily at 8:00 AM', 'Daily at 12:00 PM', 'Twice daily', 'Every 2 days',
  ];
  static const List<String> _healthTipsScheduleOptions = [
    '3 times per week', 'Daily', 'Once a week',
  ];
  static const List<String> _weeklyReportScheduleOptions = [
    'Every Monday at 10:00 AM', 'Every Monday at 8:00 AM', 'Every Sunday at 6:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    // Load asynchronously after first frame so the provider has had a chance
    // to resolve. We use listenSelf-style via post-frame callback.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  void _loadSettings() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;
    final prefs = profile.notificationPrefs;
    // Only set if currently null (avoid clobbering in-flight user toggles).
    _triageReminders ??= prefs?.triageReminders ?? true;
    _medicationReminders ??= prefs?.medicationReminders ?? true;
    _appointmentReminders ??= prefs?.appointmentReminders ?? true;
    _vitalsLoggingReminders ??= prefs?.vitalsLoggingReminders ?? true;
    _healthTips ??= prefs?.healthTips ?? true;
    _weeklyReport ??= prefs?.weeklyReport ?? true;
    if (mounted) setState(() {});
  }

  Future<void> _onChanged(bool Function(NotificationPrefs) getter,
      NotificationPrefs Function(NotificationPrefs, bool) updater, bool value) async {
    // Optimistic UI update.
    setState(() {
      // Use the updater to compute new prefs and stash into the matching field.
      final current = NotificationPrefs(
        triageReminders: _triageReminders ?? true,
        medicationReminders: _medicationReminders ?? true,
        appointmentReminders: _appointmentReminders ?? true,
        vitalsLoggingReminders: _vitalsLoggingReminders ?? true,
        healthTips: _healthTips ?? true,
        weeklyReport: _weeklyReport ?? true,
      );
      final next = updater(current, value);
      _triageReminders = next.triageReminders;
      _medicationReminders = next.medicationReminders;
      _appointmentReminders = next.appointmentReminders;
      _vitalsLoggingReminders = next.vitalsLoggingReminders;
      _healthTips = next.healthTips;
      _weeklyReport = next.weeklyReport;
    });

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = ref.read(databaseServiceProvider);
      await db.updateUserProfile(user.id, {
        'notification_prefs': {
          'triage_reminders': _triageReminders ?? true,
          'medication_reminders': _medicationReminders ?? true,
          'appointment_reminders': _appointmentReminders ?? true,
          'vitals_logging_reminders': _vitalsLoggingReminders ?? true,
          'health_tips': _healthTips ?? true,
          'weekly_report': _weeklyReport ?? true,
        },
      });
      // Refresh the cached profile so other screens see the new value.
      ref.invalidate(userProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedToSaveNotificationSetting),
            backgroundColor: AppColors.urgencyEmergency,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    // Read profile reactively so we re-load if it changes upstream.
    ref.watch(userProfileProvider);

    // If prefs haven't been loaded yet, fall back to true while loading.
    final triage = _triageReminders ?? true;
    final meds = _medicationReminders ?? true;
    final appts = _appointmentReminders ?? true;
    final vitals = _vitalsLoggingReminders ?? true;
    final tips = _healthTips ?? true;
    final weekly = _weeklyReport ?? true;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reminders Section
            _SectionLabel(label: l10n.reminders),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (AppColors.primary(isDark)).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.healing_outlined, color: AppColors.primary(isDark), size: 20),
                    ),
                    title: Text(l10n.triageReminders, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _triageSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                    ),
                    value: triage,
                    activeColor: AppColors.primary(isDark),
                    onChanged: (v) => _onChanged(
                      (p) => p.triageReminders,
                      (p, val) => p.copyWith(triageReminders: val),
                      v,
                    ),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkInfo : AppColors.lightInfo).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.medication_outlined, color: isDark ? AppColors.darkInfo : AppColors.lightInfo, size: 20),
                    ),
                    title: Text(l10n.medicationReminders, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _medicationSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                    ),
                    value: meds,
                    activeColor: AppColors.primary(isDark),
                    onChanged: (v) => _onChanged(
                      (p) => p.medicationReminders,
                      (p, val) => p.copyWith(medicationReminders: val),
                      v,
                    ),
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
                    title: Text(l10n.appointmentReminders, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _appointmentSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                    ),
                    value: appts,
                    activeColor: AppColors.primary(isDark),
                    onChanged: (v) => _onChanged(
                      (p) => p.appointmentReminders,
                      (p, val) => p.copyWith(appointmentReminders: val),
                      v,
                    ),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkWarning : AppColors.lightWarning).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.monitor_heart_outlined, color: isDark ? AppColors.darkWarning : AppColors.lightWarning, size: 20),
                    ),
                    title: Text(l10n.vitalsLoggingReminders, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _vitalsSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                    ),
                    value: vitals,
                    activeColor: AppColors.primary(isDark),
                    onChanged: (v) => _onChanged(
                      (p) => p.vitalsLoggingReminders,
                      (p, val) => p.copyWith(vitalsLoggingReminders: val),
                      v,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Insights Section
            _SectionLabel(label: l10n.insightsTips),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.darkSuccess : AppColors.lightSuccess).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.lightbulb_outline, color: isDark ? AppColors.darkSuccess : AppColors.lightSuccess, size: 20),
                    ),
                    title: Text(l10n.healthTips, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _healthTipsSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                    ),
                    value: tips,
                    activeColor: AppColors.primary(isDark),
                    onChanged: (v) => _onChanged(
                      (p) => p.healthTips,
                      (p, val) => p.copyWith(healthTips: val),
                      v,
                    ),
                  ),
                  SwitchListTile(
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (AppColors.primary(isDark)).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.summarize_outlined, color: AppColors.primary(isDark), size: 20),
                    ),
                    title: Text(l10n.weeklyReport, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _weeklyReportSchedule,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary(isDark)),
                    ),
                    value: weekly,
                    activeColor: AppColors.primary(isDark),
                    onChanged: (v) => _onChanged(
                      (p) => p.weeklyReport,
                      (p, val) => p.copyWith(weeklyReport: val),
                      v,
                    ),
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
                color: (isDark ? AppColors.darkInfo : AppColors.lightInfo).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (isDark ? AppColors.darkInfo : AppColors.lightInfo).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: isDark ? AppColors.darkInfo : AppColors.lightInfo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.notificationPreferences,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textSecondary(isDark),
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
          color: AppColors.textHint(isDark),
          letterSpacing: 1,
        ),
      ),
    );
  }
}
