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
  String _selectedSound = 'notification';
  String? _playingSound; // raw name of the sound currently being previewed
  final _notificationService = NotificationService();

  // Schedule customization — now editable per the user's request.
  String _triageSchedule = 'Daily at 9:00 AM';
  String _medicationSchedule = 'Per prescription schedule';
  String _appointmentSchedule = '1 day before';
  String _vitalsSchedule = 'Daily at 8:00 AM';
  String _healthTipsSchedule = '3 times per week';
  String _weeklyReportSchedule = 'Every Monday at 10:00 AM';


  @override
  void initState() {
    super.initState();
    _notificationService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  @override
  void dispose() {
    // Stop any playing preview and release the audio player when the
    // screen is disposed.
    _notificationService.stopPreview();
    super.dispose();
  }

  /// Toggle sound preview playback. If the sound is currently playing,
  /// stop it. If it's not playing (or a different sound is playing),
  /// start playing it.
  Future<void> _togglePreview(String rawName) async {
    // If this sound is already playing, stop it
    if (_playingSound == rawName) {
      await _notificationService.stopPreview();
      if (mounted) setState(() => _playingSound = null);
      return;
    }
    // Stop any previously-playing sound, then play the new one
    await _notificationService.stopPreview();
    final started = await _notificationService.previewSound(rawName);
    if (mounted) {
      setState(() => _playingSound = started ? rawName : null);
      // Clear the playing state when the sound finishes naturally
      if (started) {
        // audioplayers doesn't have a reliable onComplete callback for
        // asset sources on all platforms, so we use a 2-second timeout
        // to reset the UI state (all our sounds are ≤1.5s).
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _playingSound == rawName) {
            setState(() => _playingSound = null);
          }
        });
      }
    }
  }

  /// Select a sound as the notification sound for all channels.
  /// Saves it to SharedPreferences, recreates all channels with the new
  /// sound, and fires a test notification so the user can hear it in
  /// context.
  Future<void> _selectSound(String rawName, String displayName) async {
    // Stop any playing preview
    await _notificationService.stopPreview();
    if (mounted) setState(() => _playingSound = null);

    setState(() => _selectedSound = rawName);

    // Apply the sound to ALL notification channels so every reminder
    // type (triage, medication, vitals, tips, weekly, appointments)
    // uses the selected sound.
    await _notificationService.setCustomSound('vitalseker_reminders', rawName);
    await _notificationService.setCustomSound('vitalseker_medications', rawName);
    await _notificationService.setCustomSound('vitalseker_insights', rawName);
    await _notificationService.setCustomSound('vitalseker_appointments', rawName);
    await _notificationService.setCustomSound('vitalseker_vitals', rawName);

    // Fire a test notification so the user can hear the sound in a
    // real notification context.
    await _notificationService.showNotification(
      title: 'Sound Changed',
      body: 'Notification sound set to $displayName',
      sound: rawName,
    );

    if (mounted) {
      AppSnackBar.success(context, 'Sound set to $displayName. Check your notification.');
    }
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
      NotificationPrefs Function(NotificationPrefs, bool) updater, bool value,
      {String reminderType = 'triage'}) async {
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

    // Schedule or cancel the correct notification based on reminderType
    try {
      if (value) {
        switch (reminderType) {
          case 'triage':
            final sched = _parseSchedule(_triageSchedule);
            await _notificationService.scheduleTriageReminder(
              hour: sched.hour, minute: sched.minute,
            );
            if (mounted) AppSnackBar.success(context, 'Triage reminder scheduled: ${_triageSchedule}');
            break;
          case 'medication':
            // Default to 4-hourly if "Per prescription schedule", otherwise parse
            final sched = _parseSchedule(_medicationSchedule);
            await _notificationService.scheduleMedicationReminder(
              hour: sched.hour, minute: sched.minute,
            );
            if (mounted) AppSnackBar.success(context, 'Medication reminder scheduled: ${_medicationSchedule}');
            break;
          case 'appointment':
            // Appointment reminders are scheduled per-appointment when the
            // user creates an appointment (via scheduleAppointmentReminder).
            // Toggling this ON just enables the preference; no daily schedule.
            if (mounted) AppSnackBar.success(context, 'Appointment reminders enabled');
            break;
          case 'vitals':
            final sched = _parseSchedule(_vitalsSchedule);
            await _notificationService.scheduleVitalsReminder(
              hour: sched.hour, minute: sched.minute,
            );
            if (mounted) AppSnackBar.success(context, 'Vitals reminder scheduled: ${_vitalsSchedule}');
            break;
          case 'tips':
            final sched = _parseSchedule(_healthTipsSchedule);
            await _notificationService.scheduleHealthTipsReminder(
              hour: sched.hour, minute: sched.minute,
            );
            if (mounted) AppSnackBar.success(context, 'Health tips scheduled: ${_healthTipsSchedule}');
            break;
          case 'weekly':
            // Parse weekday + time from _weeklyReportSchedule
            // Default: Monday at 10:00 AM
            int weekday = 1; // Monday
            final sched = _parseSchedule(_weeklyReportSchedule);
            if (_weeklyReportSchedule.contains('Sunday')) weekday = 7;
            if (_weeklyReportSchedule.contains('Monday')) weekday = 1;
            await _notificationService.scheduleWeeklyReportReminder(
              weekday: weekday, hour: sched.hour, minute: sched.minute,
            );
            if (mounted) AppSnackBar.success(context, 'Weekly report scheduled: ${_weeklyReportSchedule}');
            break;
        }
      } else {
        // Cancel the notification for this reminder type
        final cancelIds = {
          'triage': 0, 'medication': 1, 'vitals': 2, 'tips': 3, 'weekly': 4,
        };
        final id = cancelIds[reminderType];
        if (id != null) {
          await _notificationService.cancelNotification(id);
        }
        if (mounted) AppSnackBar.info(context, 'Reminder cancelled');
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
                      reminderType: 'triage',
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
                      reminderType: 'medication',
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
                      reminderType: 'appointment',
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
                      reminderType: 'vitals',
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
                      reminderType: 'tips',
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
                      reminderType: 'weekly',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Sound selector (10 sounds with play/stop preview) ──
            _SectionLabel(label: 'Notification Sound'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight(isDark)),
              ),
              child: Column(
                children: NotificationService.availableSounds.entries.map((entry) {
                  final displayName = entry.key;
                  final rawName = entry.value;
                  final isSelected = _selectedSound == rawName;
                  final isPlaying = _playingSound == rawName;
                  return _SoundTile(
                    displayName: displayName,
                    rawName: rawName,
                    isSelected: isSelected,
                    isPlaying: isPlaying,
                    isDark: isDark,
                    onPlayTap: () => _togglePreview(rawName),
                    onSelect: () => _selectSound(rawName, displayName),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap ▶ to preview a sound (tap again to stop). Tap the row to select it for all notifications.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary(isDark)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single sound option row in the sound selector.
///
/// Layout: [radio icon] [sound name] ...... [play/stop button]
///
/// - Tapping the row (anywhere except the play button) selects the sound.
/// - Tapping the play button toggles preview playback (play → stop).
/// - The selected sound has a filled radio circle + primary tint background.
/// - The playing sound has a stop icon (Icons.stop_rounded).
class _SoundTile extends StatelessWidget {
  final String displayName;
  final String rawName;
  final bool isSelected;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onPlayTap;
  final VoidCallback onSelect;

  const _SoundTile({
    required this.displayName,
    required this.rawName,
    required this.isSelected,
    required this.isPlaying,
    required this.isDark,
    required this.onPlayTap,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary(isDark).withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppColors.borderLight(isDark).withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Radio indicator (left side)
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected
                  ? AppColors.primary(isDark)
                  : AppColors.textHint(isDark),
            ),
            const SizedBox(width: 12),
            // Sound name (left side, expanded)
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary(isDark)
                      : AppColors.textPrimary(isDark),
                ),
              ),
            ),
            // Play/Stop button (right side, fully right)
            GestureDetector(
              onTap: onPlayTap,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? AppColors.urgencyEmergency.withValues(alpha: 0.12)
                      : AppColors.primary(isDark).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: isPlaying
                      ? AppColors.urgencyEmergency
                      : AppColors.primary(isDark),
                ),
              ),
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
