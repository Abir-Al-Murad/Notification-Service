import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart';

import '../../features/task/data/model/task_model.dart';


class NotificationService {
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initNotification() async {
    if (_isInitialized) return;
    initializeTimeZones();
    final String currentTimeZone = local.name;
    setLocalLocation(getLocation(currentTimeZone));

    const initSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettingsIOS = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await notificationPlugin.initialize(initSettings);
    _isInitialized = true;

    final androidPlugin = notificationPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestNotificationsPermission();
  }

  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'study_hub_id',
        'study_hub',
        channelDescription: 'Daily Notification Channel',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        ticker: 'ticker',
      ),
      iOS: DarwinNotificationDetails(
        presentSound: true,
        presentBadge: true,
        presentAlert: true,
      ),
    );
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    return notificationPlugin.show(id, title, body, notificationDetails());
  }

  Future<void> scheduleTaskDeadlineNotification({
    required String taskId,
    required String title,
    required String body,
    required Timestamp deadline,
  }) async {
    try {
      final andriodImplementation = notificationPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (andriodImplementation == null) {
        debugPrint("Android Implementation not found");
        return;
      }

      DateTime deadlineDate = deadline.toDate();

      final pending = await notificationPlugin.pendingNotificationRequests();
      final existingId = pending.map((n)=>n.id).toSet();
      int beforeId = '${taskId}_before'.hashCode;
      int deadlineId = '${taskId}_deadline'.hashCode;

      if(existingId.contains(beforeId)){
        await _scheduleOneDayBeforeNotification(taskId: taskId, title: title, body: body, deadlineDate: deadlineDate);

      }
      if(existingId.contains(deadlineId)){
        await _scheduleDeadlineDayNotification(taskId: taskId, title: title, body: body, deadlineDate: deadlineDate);
      }
      debugPrint("✅ Scheduled notifications for task: $title");
    } catch (e) {
      debugPrint("❌ Error scheduling notifications: $e");
    }
  }

  Future<void> _scheduleOneDayBeforeNotification({
    required String taskId,
    required String title,
    required String body,
    required DateTime deadlineDate,
  }) async {
    try {
      DateTime oneDayBefore = deadlineDate.subtract(Duration(days: 1));
      DateTime notificationTime = DateTime(
        oneDayBefore.year,
        oneDayBefore.month,
        oneDayBefore.day,
        9,
        0,
      );
      if (notificationTime.isBefore(DateTime.now())) {
        debugPrint(
          "⚠️ One day before notification time is in the past, skipping",
        );
        return;
      }
      TZDateTime scheduledDate = TZDateTime.from(notificationTime, local);

      int notificationId = '${taskId}_before'.hashCode;
      await notificationPlugin.zonedSchedule(
        notificationId,
        '🔔 ⏰ Task Reminder: $title',
        'Deadline tomorrow! $body',
        scheduledDate,
        notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint("✅ Scheduled 1-day-before notification: $scheduledDate");
    } catch (e) {
      debugPrint("❌ Error scheduling 1-day-before notification: $e");
    }
  }
  Future<void> _scheduleDeadlineDayNotification({
    required String taskId,
    required String title,
    required String body,
    required DateTime deadlineDate,
  }) async {
    try {
      DateTime notificationTime = DateTime(
        deadlineDate.year,
        deadlineDate.month,
        deadlineDate.day,
        9,
        0,
      );
      if (notificationTime.isBefore(DateTime.now())) {
        debugPrint(
          "⚠️ One day before notification time is in the past, skipping",
        );
        return;
      }
      TZDateTime scheduledDate = TZDateTime.from(notificationTime, local);

      int notificationId = '${taskId}_deadline'.hashCode;
      await notificationPlugin.zonedSchedule(
        notificationId,
        '🔔 Task Due Today: $title',
        'Due today! $body',
        scheduledDate,
        notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint("✅ Scheduled deadline-day notification: $scheduledDate");
    } catch (e) {
      debugPrint("❌ Error scheduling deadline-day notification: $e");
    }
  }

  Future<void> scheduleMultipleTaskNotifications(
      List<TaskModel> model ) async {
    for (var task in model) {
      await scheduleTaskDeadlineNotification(
        taskId: task.id!,
        title: task.title,
        body: task.description,
        deadline: task.deadline,
      );
    }
    debugPrint("✅ Scheduled notifications for ${model.length} tasks");
  }


  //cancel a specific notification
  Future<void> cancelTaskNotifications(String taskId)async{
    try{
      int beforeNotificationId = '${taskId}_before'.hashCode;
      int deadlineNotificationId = '${taskId}_deadline'.hashCode;

      await notificationPlugin.cancel(beforeNotificationId);
      await notificationPlugin.cancel(deadlineNotificationId);
      debugPrint("✅ Cancelled notifications for task: $taskId");
    }catch(e){
      debugPrint("❌ Error cancelling notifications: $e");
    }
  }

  //Get all pending notification(For debugging)
  Future<void> getPendingNotifications() async {
    try {
      final pending = await notificationPlugin.pendingNotificationRequests();
      debugPrint("📋 Pending notifications: ${pending.length}");
      for (var notification in pending) {
        debugPrint("  - ID: ${notification.id}, Title: ${notification.title}");
      }
    } catch (e) {
      debugPrint("❌ Error getting pending notifications: $e");
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await notificationPlugin.cancelAll();
      debugPrint("✅ Cancelled all notifications");
    } catch (e) {
      debugPrint("❌ Error cancelling all notifications: $e");
    }
  }
}
