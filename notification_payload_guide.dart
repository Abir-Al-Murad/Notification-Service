import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ==================== PAYLOAD কী এবং কীভাবে কাজ করে ====================

/*
PAYLOAD কী?
- Notification এর সাথে pass করা extra data
- String format এ থাকে
- JSON encode করে complex data pass করা যায়
- Notification tap করলে এই data পাওয়া যায়

কেন ব্যবহার করবেন?
✅ Specific screen এ navigate করতে
✅ Data show করতে (task details, message, etc.)
✅ Action perform করতে (mark as read, delete, etc.)
✅ Deep linking এর জন্য
*/

// ==================== BASIC PAYLOAD EXAMPLE ====================

class PayloadExample {
  final FlutterLocalNotificationsPlugin _plugin = 
      FlutterLocalNotificationsPlugin();

  // 1️⃣ SIMPLE STRING PAYLOAD
  Future<void> showNotificationWithSimplePayload() async {
    await _plugin.show(
      1,
      'New Task',
      'You have a new task assigned',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id',
          'channel_name',
          importance: Importance.high,
        ),
      ),
      payload: 'task_123', // ✅ Simple task ID
    );
  }

  // 2️⃣ JSON PAYLOAD (RECOMMENDED)
  Future<void> showNotificationWithJsonPayload() async {
    // Complex data কে JSON এ convert করুন
    final payloadData = {
      'type': 'task',
      'id': 'task_123',
      'title': 'Complete Assignment',
      'priority': 'high',
      'screen': '/task-details',
    };

    await _plugin.show(
      2,
      'New Task',
      'Complete Assignment - Due Tomorrow',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id',
          'channel_name',
          importance: Importance.high,
        ),
      ),
      payload: jsonEncode(payloadData), // ✅ JSON string
    );
  }

  // 3️⃣ DIFFERENT TYPES OF NOTIFICATIONS
  
  // Task notification
  Future<void> showTaskNotification({
    required String taskId,
    required String title,
    required String description,
  }) async {
    final payload = jsonEncode({
      'type': 'task',
      'id': taskId,
      'title': title,
      'screen': '/task-details',
    });

    await _plugin.show(
      taskId.hashCode,
      '📋 New Task',
      title,
      _getNotificationDetails(),
      payload: payload,
    );
  }

  // Message notification
  Future<void> showMessageNotification({
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    final payload = jsonEncode({
      'type': 'message',
      'senderId': senderId,
      'senderName': senderName,
      'screen': '/chat',
    });

    await _plugin.show(
      senderId.hashCode,
      '💬 New Message from $senderName',
      message,
      _getNotificationDetails(),
      payload: payload,
    );
  }

  // Notice notification
  Future<void> showNoticeNotification({
    required String noticeId,
    required String title,
  }) async {
    final payload = jsonEncode({
      'type': 'notice',
      'id': noticeId,
      'screen': '/notice-details',
    });

    await _plugin.show(
      noticeId.hashCode,
      '📢 New Notice',
      title,
      _getNotificationDetails(),
      payload: payload,
    );
  }

  NotificationDetails _getNotificationDetails() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'app_notifications',
        'App Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
  }
}

// ==================== HANDLING PAYLOAD ====================

class NotificationHandler {
  static final GlobalKey<NavigatorState> navigatorKey = 
      GlobalKey<NavigatorState>();

  // Initialize notification handler
  static Future<void> initialize() async {
    final plugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await plugin.initialize(
      InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      // 🔑 Key part: Handle notification tap
      onDidReceiveNotificationResponse: handleNotificationTap,
      onDidReceiveBackgroundNotificationResponse: handleNotificationTap,
    );

    // Check if app was launched from notification
    final launchDetails = await plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (payload != null) {
        // App launched from notification
        _processPayload(payload);
      }
    }
  }

  // 🎯 Handle notification tap
  @pragma('vm:entry-point')
  static void handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    
    if (payload != null && payload.isNotEmpty) {
      debugPrint('🔔 Notification tapped with payload: $payload');
      _processPayload(payload);
    }
  }

  // 📦 Process payload and navigate
  static void _processPayload(String payload) {
    try {
      // Try to decode as JSON
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final screen = data['screen'] as String?;

      if (type == null || screen == null) {
        debugPrint('⚠️ Invalid payload structure');
        return;
      }

      // Navigate based on type
      switch (type) {
        case 'task':
          _navigateToTask(data);
          break;
        case 'message':
          _navigateToMessage(data);
          break;
        case 'notice':
          _navigateToNotice(data);
          break;
        default:
          debugPrint('⚠️ Unknown notification type: $type');
      }
    } catch (e) {
      // If not JSON, treat as simple string
      debugPrint('📝 Simple payload: $payload');
      _navigateToScreen('/home');
    }
  }

  // Navigate to task details
  static void _navigateToTask(Map<String, dynamic> data) {
    final taskId = data['id'] as String;
    final screen = data['screen'] as String;
    
    navigatorKey.currentState?.pushNamed(
      screen,
      arguments: {'taskId': taskId},
    );
  }

  // Navigate to message/chat
  static void _navigateToMessage(Map<String, dynamic> data) {
    final senderId = data['senderId'] as String;
    final screen = data['screen'] as String;
    
    navigatorKey.currentState?.pushNamed(
      screen,
      arguments: {'userId': senderId},
    );
  }

  // Navigate to notice details
  static void _navigateToNotice(Map<String, dynamic> data) {
    final noticeId = data['id'] as String;
    final screen = data['screen'] as String;
    
    navigatorKey.currentState?.pushNamed(
      screen,
      arguments: {'noticeId': noticeId},
    );
  }

  // Generic navigation
  static void _navigateToScreen(String route) {
    navigatorKey.currentState?.pushNamed(route);
  }
}

// ==================== APP SETUP ====================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification handler
  await NotificationHandler.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 🔑 Important: Use navigatorKey
      navigatorKey: NotificationHandler.navigatorKey,
      initialRoute: '/home',
      routes: {
        '/home': (context) => HomeScreen(),
        '/task-details': (context) => TaskDetailsScreen(),
        '/chat': (context) => ChatScreen(),
        '/notice-details': (context) => NoticeDetailsScreen(),
      },
    );
  }
}

// ==================== EXAMPLE SCREENS ====================

class HomeScreen extends StatelessWidget {
  final PayloadExample notificationService = PayloadExample();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Send task notification
                notificationService.showTaskNotification(
                  taskId: 'task_001',
                  title: 'Complete Assignment',
                  description: 'Due tomorrow',
                );
              },
              child: Text('Send Task Notification'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Send message notification
                notificationService.showMessageNotification(
                  senderId: 'user_123',
                  senderName: 'John Doe',
                  message: 'Hey, how are you?',
                );
              },
              child: Text('Send Message Notification'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Send notice notification
                notificationService.showNoticeNotification(
                  noticeId: 'notice_001',
                  title: 'Important Announcement',
                );
              },
              child: Text('Send Notice Notification'),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskDetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get arguments from payload
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final taskId = args?['taskId'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: Text('Task Details')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Task ID: $taskId', style: TextStyle(fontSize: 20)),
            SizedBox(height: 16),
            Text('This screen was opened from notification!'),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final userId = args?['userId'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('User ID: $userId', style: TextStyle(fontSize: 20)),
            SizedBox(height: 16),
            Text('Chat with this user'),
          ],
        ),
      ),
    );
  }
}

class NoticeDetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final noticeId = args?['noticeId'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: Text('Notice Details')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Notice ID: $noticeId', style: TextStyle(fontSize: 20)),
            SizedBox(height: 16),
            Text('Notice details here'),
          ],
        ),
      ),
    );
  }
}

// ==================== REAL WORLD EXAMPLE ====================

class TaskNotificationManager {
  final FlutterLocalNotificationsPlugin _plugin = 
      FlutterLocalNotificationsPlugin();

  // Task deadline notification with payload
  Future<void> scheduleTaskDeadlineNotification({
    required String taskId,
    required String title,
    required String description,
    required DateTime deadline,
  }) async {
    // Create payload
    final payload = jsonEncode({
      'type': 'task_deadline',
      'taskId': taskId,
      'title': title,
      'screen': '/task-details',
      'action': 'view_task',
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Schedule notification 1 day before
    final notificationTime = deadline.subtract(Duration(days: 1));
    
    await _plugin.zonedSchedule(
      taskId.hashCode,
      '⏰ Task Reminder',
      '$title - Due tomorrow!',
      TZDateTime.from(notificationTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'view',
              'View Task',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'snooze',
              'Remind Later',
            ),
          ],
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('📅 Task notification scheduled with payload: $payload');
  }

  // Handle notification action response
  @pragma('vm:entry-point')
  static void handleActionResponse(NotificationResponse response) {
    final action = response.actionId;
    final payload = response.payload;

    if (payload == null) return;

    final data = jsonDecode(payload);
    final taskId = data['taskId'] as String;

    switch (action) {
      case 'view':
        // Navigate to task details
        NotificationHandler.navigatorKey.currentState?.pushNamed(
          '/task-details',
          arguments: {'taskId': taskId},
        );
        break;
      case 'snooze':
        // Reschedule notification for 1 hour later
        _snoozeNotification(taskId);
        break;
    }
  }

  static void _snoozeNotification(String taskId) {
    // Logic to reschedule
    debugPrint('Snoozed notification for task: $taskId');
  }
}

// ==================== KEY POINTS ====================

/*
✅ PAYLOAD BEST PRACTICES:

1. Always use JSON for complex data
   ❌ Bad:  payload: 'task_123'
   ✅ Good: payload: jsonEncode({'type': 'task', 'id': 'task_123'})

2. Include necessary information
   - Type (task, message, notice)
   - ID (to fetch full data)
   - Screen (where to navigate)
   - Action (what to do)

3. Keep payload small
   - Don't send entire objects
   - Send only IDs and fetch data when needed

4. Handle errors gracefully
   - Check if payload is null
   - Try-catch when parsing JSON
   - Fallback to home screen

5. Use navigatorKey for navigation
   - Can't use Navigator.of(context) in callback
   - Must use GlobalKey<NavigatorState>

📋 PAYLOAD STRUCTURE EXAMPLE:
{
  "type": "task",              // Notification type
  "id": "task_123",            // Entity ID
  "title": "Complete",         // Display data
  "screen": "/task-details",   // Target screen
  "action": "view",            // Default action
  "priority": "high",          // Extra metadata
  "timestamp": "2024-01-01"    // When created
}

🎯 FLOW:
1. Create notification with payload
2. User taps notification
3. onDidReceiveNotificationResponse called
4. Parse payload
5. Navigate to screen with data
6. Fetch full data using ID from payload
*/