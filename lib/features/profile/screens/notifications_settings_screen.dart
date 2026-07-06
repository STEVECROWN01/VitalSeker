import 'package:flutter/material.dart';
import 'package:vitalseker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_profile_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_snack_bar.dart';

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
  String _selectedSound = 'default';
  final _notificationService = NotificationService();

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

  static const List<String> _soundOptions = [
    'default', 'chime', 'alert', 'bell', 'soft',
  ];

  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  void _loadSettings() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;
    final prefs = profile.notificationPrefs;
    _triageReminders ??= prefs?.triageReminders ?? true;
    _medicationReminders ??= prefs?.medicationReminders ?? true;
    _appointmentReminders ??= prefs?.appointmentReminders ?? true;
    _vitalsLoggingReminders ??= prefs?.vitalsLoggingReminders ?? true;
    _healthTips ??= prefs?.healthTips ?? true;
    _weeklyReport ??= prefs?.weeklyReport ?? true;
    if (mounted) setState(() {});
  }

  /// Parse a schedule string like "Daily at 9:00 AM" into hour and minute.
  ({int hour, int minute}) _parseSchedule(String schedule) {
    final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)').firstMatch(schedule);
    if (match == null) return (hour: 9, minute: 0);
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return (hour: hour, minute: minute);
  }

  Future<void> _onChanged(bool Function(NotificationPrefs) getter,
      NotificationPrefs Function(NotificationPrefs, bool) updater, bool value) async {
    setState(() {
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

    // Schedule or cancel the actual notification
    try {
      if (value) {
        // Schedule the notification based on the schedule string
        final sched = _parseSchedule(_triageSchedule);
        await _notificationService.scheduleDailyReminder(
          hour: sched.hour,
          minute: sched.minute,
          title: 'VitalSeker Health Check',
          body: 'Time for your daily health check. Tap to start a triage.',
          channelId: 'vitalseker_reminders',
          id: 0,
        );
        if (mounted) {
          AppSnackBar.success(context, 'Reminder scheduled for ${_triageSchedule}');
        }
      } else {
        await _notificationService.cancelNotification(0);
        if (mounted) {
          AppSnackBar.info(context, 'Reminder cancelled');
        }
      }
    } catch (e) {
      debugPrint('Notification scheduling error: $e');
    }

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

            // ── Ringtone selector ──
            _SectionLabel(label: 'Notification Sound'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inputFill(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight(isDark)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSound,
                  isExpanded: true,
                  dropdownColor: AppColors.surface(isDark),
                  style: TextStyle(color: AppColors.textPrimary(isDark), fontFamily: 'Inter', fontSize: 14),
                  items: _soundOptions.map((sound) => DropdownMenuItem(
                    value: sound,
                    child: Text(sound[0].toUpperCase() + sound.substring(1)),
                  )).toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _selectedSound = value);
                    await _notificationService.setCustomSound('vitalseker_reminders', value);
                    // Test the sound immediately
                    await _notificationService.showNotification(
                      title: 'Sound Changed',
                      body: 'Notification sound set to $value',
                      sound: value,
                    );
                    if (mounted) {
                      AppSnackBar.success(context, 'Sound set to $value. Check your notification.');
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap a sound to preview it. The selected sound will play for all scheduled notifications.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary(isDark)),
            ),
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
