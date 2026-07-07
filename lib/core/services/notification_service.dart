import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Notification service for scheduling and displaying local notifications
/// with custom sounds. Per Cahier des Charges Section 3: "Notifications —
/// OneSignal — Push notifications, rappels, alertes santé".
///
/// This service handles:
/// - Daily triage reminders (e.g., 9:00 AM)
/// - Medication reminders
/// - Weekly insights notifications
/// - Custom ringtone selection per notification type
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Notification channel IDs
  static const String _channelReminders = 'vitalseker_reminders';
  static const String _channelInsights = 'vitalseker_insights';
  static const String _channelMedications = 'vitalseker_medications';

  /// Available notification sounds (raw resources in android/app/src/main/res/raw/)
  /// For now we use the default sound — custom sounds can be added by placing
  /// .mp3 files in android/app/src/main/res/raw/ and referencing them here.
  static const Map<String, String> availableSounds = {
    'default': 'notification',
    'chime': 'chime',
    'alert': 'alert',
    'bell': 'bell',
    'soft': 'soft',
  };

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data for scheduled notifications
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[Notifications] Tapped: ${response.payload}');
      },
    );

    // Create notification channels with custom sounds
    await _createChannels();

    _initialized = true;
    debugPrint('[Notifications] Initialized');
  }

  Future<void> _createChannels() async {
    // Reminders channel (daily triage reminders)
    const remindersChannel = AndroidNotificationChannel(
      _channelReminders,
      'Health Reminders',
      description: 'Daily health check reminders',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    // Insights channel (weekly insights)
    const insightsChannel = AndroidNotificationChannel(
      _channelInsights,
      'Weekly Insights',
      description: 'Weekly AI health insights',
      importance: Importance.defaultImportance,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    // Medications channel (medication reminders)
    const medicationsChannel = AndroidNotificationChannel(
      _channelMedications,
      'Medication Reminders',
      description: 'Medication schedule reminders',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(remindersChannel);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(insightsChannel);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(medicationsChannel);
  }

  /// Show an immediate notification.
  Future<void> showNotification({
    required String title,
    required String body,
    String channelId = _channelReminders,
    String? sound,
    int id = 0,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _channelReminders ? 'Health Reminders' : 'Notifications',
      importance: Importance.high,
      priority: Priority.high,
      sound: sound != null
          ? RawResourceAndroidNotificationSound(sound)
          : const RawResourceAndroidNotificationSound('notification'),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(id, title, body, details);
  }

  /// Schedule a daily notification at a specific hour.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    String channelId = _channelReminders,
    int id = 0,
  }) async {
    if (!_initialized) await initialize();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Scheduled Notifications',
      importance: Importance.high,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('notification'),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Save the schedule preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_reminder_enabled', true);
    await prefs.setInt('notif_reminder_hour', hour);
    await prefs.setInt('notif_reminder_minute', minute);
  }

  /// Cancel a scheduled notification by ID.
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    final prefs = await SharedPreferences.getInstance();
    if (id == 0) await prefs.setBool('notif_reminder_enabled', false);
    if (id == 1) await prefs.setBool('notif_insights_enabled', false);
    if (id == 2) await prefs.setBool('notif_medications_enabled', false);
  }

  /// Cancel all notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_reminder_enabled', false);
    await prefs.setBool('notif_insights_enabled', false);
    await prefs.setBool('notif_medications_enabled', false);
  }

  /// Set a custom sound for a notification channel.
  Future<void> setCustomSound(String channelId, String soundName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_sound_$channelId', soundName);

    // Recreate the channel with the new sound
    final channel = AndroidNotificationChannel(
      channelId,
      _channelName(channelId),
      description: 'Custom sound: $soundName',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound(soundName),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  String _channelName(String id) {
    switch (id) {
      case _channelReminders:
        return 'Health Reminders';
      case _channelInsights:
        return 'Weekly Insights';
      case _channelMedications:
        return 'Medication Reminders';
      default:
        return 'Notifications';
    }
  }
}
