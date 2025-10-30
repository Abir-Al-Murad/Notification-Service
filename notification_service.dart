import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // INITIALIZE
  Future<void> initNotification() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    final String currentTimeZone = tz.local.name;
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await notificationsPlugin.initialize(initSettings);
    _isInitialized = true;

    // Permission requests
    final androidPlugin = notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  // Notification details
  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notification',
        channelDescription: "Daily Notification Channel",
        // sound: RawResourceAndroidNotificationSound('notification'),
        ongoing: false,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // Show instant notification
  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    return notificationsPlugin.show(id, title, body, notificationDetails());
  }

  // Schedule notification at specific hour & minute
  Future<void> scheduleNotification({
    int id = 1,
    required String title,
    required String body,
    // required int hour,
    // required int minute,
  }) async {
    try {
      print('Starting schedule notification...');

      final androidImplementation = notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation == null) {
        print('Android implementation not found');
        return;
      }

      tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      print('Current time: $now');
      tz.TZDateTime scheduledDate = now.add(Duration(seconds:2));

      // tz.TZDateTime scheduledDate = tz.TZDateTime(
      //   tz.local,
      //   now.year,
      //   now.month,
      //   now.day,
      //   hour,
      //   minute,
      // );

      print('Original scheduled date: $scheduledDate');

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
        print('Adjusted scheduled date: $scheduledDate');
      }

      // ExactAllowWhileIdle এর পরিবর্তে exactUse করছি
      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exact, // পরিবর্তন করুন
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'scheduled_notification_$id', // payload যোগ করুন
      );

      print('✅ Notification successfully scheduled for: $scheduledDate');

    } catch (e) {
      print('❌ Error scheduling notification: $e');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotification() async {
    await notificationsPlugin.cancelAll();
  }
}
