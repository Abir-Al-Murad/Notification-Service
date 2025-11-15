import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';

// ==================== NOTIFICATION SERVICE ====================

class CompleteNotificationService {
  static final CompleteNotificationService _instance = CompleteNotificationService._internal();
  factory CompleteNotificationService() => _instance;
  CompleteNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  bool _isInitialized = false;
  String? _fcmToken;

  // Initialize everything
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    final String timeZoneName = tz.local.name;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Initialize FCM
    await _initializeFCM();
    
    // Create notification channels
    await _createNotificationChannels();
    
    _isInitialized = true;
    debugPrint("✅ Notification Service Initialized");
  }

  // ==================== LOCAL NOTIFICATIONS ====================

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onNotificationTapped,
    );

    // Request permissions (Android 13+)
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  // Handle notification tap
  @pragma('vm:entry-point')
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    debugPrint("🔔 Notification tapped: $payload");
    
    if (payload != null) {
      final data = jsonDecode(payload);
      // Navigate based on payload
      // navigatorKey.currentState?.pushNamed(data['route'], arguments: data);
    }
  }

  // Create notification channels
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // High priority channel (Tasks, Reminders)
    const highChannel = AndroidNotificationChannel(
      'high_importance',
      'High Priority',
      description: 'For important notifications like task deadlines',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // Medium priority channel (Messages, Updates)
    const mediumChannel = AndroidNotificationChannel(
      'medium_importance',
      'Medium Priority',
      description: 'For regular notifications',
      importance: Importance.defaultImportance,
      playSound: true,
      showBadge: true,
    );

    // Low priority channel (Information)
    const lowChannel = AndroidNotificationChannel(
      'low_importance',
      'Low Priority',
      description: 'For informational notifications',
      importance: Importance.low,
      playSound: false,
    );

    await androidPlugin.createNotificationChannel(highChannel);
    await androidPlugin.createNotificationChannel(mediumChannel);
    await androidPlugin.createNotificationChannel(lowChannel);
  }

  // ==================== SHOW NOTIFICATIONS ====================

  // Simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationPriority priority = NotificationPriority.high,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      _getNotificationDetails(priority),
      payload: payload,
    );
  }

  // Big text notification
  Future<void> showBigTextNotification({
    required int id,
    required String title,
    required String body,
    required String bigText,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance',
        'High Priority',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          bigText,
          contentTitle: title,
          summaryText: body,
        ),
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // Progress notification
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required int progress,
    required int maxProgress,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medium_importance',
        'Medium Priority',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        ongoing: progress < maxProgress,
        autoCancel: progress >= maxProgress,
      ),
    );

    await _localNotifications.show(
      id,
      title,
      '$progress/$maxProgress',
      details,
    );
  }

  // Notification with actions
  Future<void> showNotificationWithActions({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance',
        'High Priority',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          const AndroidNotificationAction(
            'accept',
            'Accept',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'reject',
            'Reject',
            cancelNotification: true,
          ),
        ],
      ),
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // ==================== SCHEDULED NOTIFICATIONS ====================

  // Schedule one-time notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      _getNotificationDetails(NotificationPriority.high),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    debugPrint("⏰ Scheduled notification for $tzScheduledTime");
  }

  // Schedule daily notification
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final scheduledTime = _nextInstanceOfTime(hour, minute);

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      _getNotificationDetails(NotificationPriority.high),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );

    debugPrint("📅 Scheduled daily notification at $hour:$minute");
  }

  // Schedule weekly notification
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final scheduledTime = _nextInstanceOfWeekday(weekday, hour, minute);

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      _getNotificationDetails(NotificationPriority.high),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );

    debugPrint("📅 Scheduled weekly notification on day $weekday at $hour:$minute");
  }

  // Helper: Next instance of time
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // Helper: Next instance of weekday
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    var scheduledDate = _nextInstanceOfTime(hour, minute);

    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // ==================== FCM (PUSH NOTIFICATIONS) ====================

  Future<void> _initializeFCM() async {
    // Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("✅ FCM permission granted");

      // Get FCM token
      _fcmToken = await _fcm.getToken();
      debugPrint("📱 FCM Token: $_fcmToken");

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint("🔄 FCM Token refreshed: $newToken");
        // Save to server
      });

      // Setup message handlers
      _setupFCMHandlers();
    }
  }

  void _setupFCMHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📨 Foreground FCM: ${message.notification?.title}");
      _handleForegroundMessage(message);
    });

    // Background message opened app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📱 FCM opened app");
      _handleMessageTap(message);
    });

    // Check if app opened from terminated state
    _fcm.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint("🚀 App launched from FCM");
        _handleMessageTap(message);
      }
    });
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await showNotification(
      id: notification.hashCode,
      title: notification.title ?? 'New Message',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    debugPrint("💬 Message data: $data");
    
    // Navigate based on data
    // if (data['type'] == 'chat') {
    //   navigatorKey.currentState?.pushNamed('/chat', arguments: data);
    // }
  }

  String? get fcmToken => _fcmToken;

  // ==================== UTILITY METHODS ====================

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
    debugPrint("❌ Cancelled notification $id");
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint("❌ Cancelled all notifications");
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  // Get active notifications
  Future<List<ActiveNotification>> getActiveNotifications() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    return await androidPlugin?.getActiveNotifications() ?? [];
  }

  // Helper: Get notification details based on priority
  NotificationDetails _getNotificationDetails(NotificationPriority priority) {
    String channelId;
    Importance importance;
    Priority androidPriority;

    switch (priority) {
      case NotificationPriority.high:
        channelId = 'high_importance';
        importance = Importance.high;
        androidPriority = Priority.high;
        break;
      case NotificationPriority.medium:
        channelId = 'medium_importance';
        importance = Importance.defaultImportance;
        androidPriority = Priority.defaultPriority;
        break;
      case NotificationPriority.low:
        channelId = 'low_importance';
        importance = Importance.low;
        androidPriority = Priority.low;
        break;
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId.replaceAll('_', ' ').toUpperCase(),
        importance: importance,
        priority: androidPriority,
        playSound: true,
        enableVibration: true,
        showWhen: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}

// ==================== ENUMS ====================

enum NotificationPriority {
  high,
  medium,
  low,
}

// ==================== BACKGROUND HANDLER ====================

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint("📬 Background FCM: ${message.notification?.title}");
}

// ==================== USAGE EXAMPLE ====================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  // await Firebase.initializeApp();
  
  // Set background handler
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  
  // Initialize notifications
  await CompleteNotificationService().initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: NotificationDemo(),
    );
  }
}

class NotificationDemo extends StatelessWidget {
  final notificationService = CompleteNotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notification Demo')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () {
              notificationService.showNotification(
                id: 1,
                title: 'Simple Notification',
                body: 'This is a simple notification',
              );
            },
            child: Text('Show Simple Notification'),
          ),
          ElevatedButton(
            onPressed: () {
              notificationService.showBigTextNotification(
                id: 2,
                title: 'Big Text',
                body: 'Short preview',
                bigText: 'This is a very long text that will be expanded '
                    'when the user expands the notification.',
              );
            },
            child: Text('Show Big Text Notification'),
          ),
          ElevatedButton(
            onPressed: () {
              notificationService.scheduleNotification(
                id: 3,
                title: 'Scheduled Notification',
                body: 'This appears in 10 seconds',
                scheduledTime: DateTime.now().add(Duration(seconds: 10)),
              );
            },
            child: Text('Schedule Notification (10s)'),
          ),
          ElevatedButton(
            onPressed: () {
              notificationService.scheduleDailyNotification(
                id: 4,
                title: 'Daily Reminder',
                body: 'This appears daily at 9:00 AM',
                hour: 9,
                minute: 0,
              );
            },
            child: Text('Schedule Daily (9 AM)'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pending = await notificationService.getPendingNotifications();
              debugPrint('Pending: ${pending.length}');
              for (var n in pending) {
                debugPrint('  - ${n.id}: ${n.title}');
              }
            },
            child: Text('Show Pending Notifications'),
          ),
          ElevatedButton(
            onPressed: () {
              notificationService.cancelAllNotifications();
            },
            child: Text('Cancel All Notifications'),
          ),
        ],
      ),
    );
  }
}