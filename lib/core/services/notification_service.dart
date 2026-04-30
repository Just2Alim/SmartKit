import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Almaty'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(settings);

    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    final androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();

    await macImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    print('NOW: $now');
    print('SCHEDULED: $scheduledDate');

    const androidDetails = AndroidNotificationDetails(
      'smartkit_reminders',
      'SmartKit Reminders',
      channelDescription: 'Напоминания о приёме лекарств',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  int reminderIdFromString(String value) {
    return value.hashCode.abs() % 2147483647;
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'smartkit_reminders',
      'SmartKit Reminders',
      channelDescription: 'Тестовые уведомления',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await flutterLocalNotificationsPlugin.show(id, title, body, details);
  }
}
