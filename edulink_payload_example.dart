import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ==================== YOUR EDULINK APP NOTIFICATION SERVICE ====================

class EduLinkNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = 
      GlobalKey<NavigatorState>();
  
  final FlutterLocalNotificationsPlugin _plugin = 
      FlutterLocalNotificationsPlugin();

  // Initialize with payload handling
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _handleNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _handleNotificationTap,
    );
  }

  // 🎯 Handle notification tap
  @pragma('vm:entry-point')
  static void _handleNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    
    if (payload == null || payload.isEmpty) {
      debugPrint('⚠️ No payload received');
      return;
    }

    debugPrint('🔔 Notification tapped: $payload');
    
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'task_deadline':
          _navigateToTaskDetails(data);
          break;
        case 'task_reminder':
          _navigateToTaskDetails(data);
          break;
        case 'new_notice':
          _navigateToNoticeDetails(data);
          break;
        case 'new_task':
          _navigateToHome();
          break;
        case 'class_update':
          _navigateToClassroom(data);
          break;
        default:
          _navigateToHome();
      }
    } catch (e) {
      debugPrint('❌ Error handling payload: $e');
      _navigateToHome();
    }
  }

  // Navigate to task details
  static void _navigateToTaskDetails(Map<String, dynamic> data) {
    final taskId = data['taskId'] as String?;
    final classId = data['classId'] as String?;
    
    if (taskId == null || classId == null) {
      _navigateToHome();
      return;
    }

    navigatorKey.currentState?.pushNamed(
      '/task-details',
      arguments: {
        'taskId': taskId,
        'classId': classId,
      },
    );
  }

  // Navigate to notice details
  static void _navigateToNoticeDetails(Map<String, dynamic> data) {
    final noticeId = data['noticeId'] as String?;
    
    if (noticeId == null) {
      _navigateToHome();
      return;
    }

    navigatorKey.currentState?.pushNamed(
      '/notice-details',
      arguments: {'noticeId': noticeId},
    );
  }

  // Navigate to classroom
  static void _navigateToClassroom(Map<String, dynamic> data) {
    final classId = data['classId'] as String?;
    
    if (classId == null) {
      _navigateToHome();
      return;
    }

    navigatorKey.currentState?.pushNamed(
      '/classroom',
      arguments: {'classId': classId},
    );
  }

  // Navigate to home
  static void _navigateToHome() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }

  // ==================== NOTIFICATION METHODS ====================

  // 1️⃣ Task Deadline Notification (1 day before)
  Future<void> scheduleTaskDeadlineNotification({
    required String taskId,
    required String classId,
    required String title,
    required String description,
    required DateTime deadline,
  }) async {
    final payload = jsonEncode({
      'type': 'task_deadline',
      'taskId': taskId,
      'classId': classId,
      'title': title,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Schedule 1 day before at 9 AM
    final notificationTime = DateTime(
      deadline.year,
      deadline.month,
      deadline.day - 1,
      9,
      0,
    );

    if (notificationTime.isBefore(DateTime.now())) {
      debugPrint('⚠️ Notification time in past, skipping');
      return;
    }

    final notificationId = '${taskId}_before'.hashCode;

    await _plugin.zonedSchedule(
      notificationId,
      '⏰ Task Reminder',
      '$title - Due tomorrow!',
      TZDateTime.from(notificationTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Reminders for upcoming task deadlines',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'view_task',
              'View Task',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'dismiss',
              'Dismiss',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('✅ Task deadline notification scheduled');
  }

  // 2️⃣ New Notice Notification
  Future<void> sendNewNoticeNotification({
    required String noticeId,
    required String classId,
    required String title,
    required String description,
  }) async {
    final payload = jsonEncode({
      'type': 'new_notice',
      'noticeId': noticeId,
      'classId': classId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _plugin.show(
      noticeId.hashCode,
      '📢 New Notice Posted',
      title,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'notices',
          'Notices',
          channelDescription: 'Important class notices',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            description,
            contentTitle: '📢 New Notice Posted',
            summaryText: title,
          ),
        ),
      ),
      payload: payload,
    );

    debugPrint('✅ Notice notification sent');
  }

  // 3️⃣ New Task Assigned Notification
  Future<void> sendNewTaskNotification({
    required String taskId,
    required String classId,
    required String title,
    required String description,
    required DateTime deadline,
  }) async {
    final payload = jsonEncode({
      'type': 'new_task',
      'taskId': taskId,
      'classId': classId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Format deadline
    final deadlineStr = '${deadline.day}/${deadline.month}/${deadline.year}';

    await _plugin.show(
      taskId.hashCode,
      '📋 New Task Assigned',
      '$title - Due: $deadlineStr',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks',
          'Tasks',
          channelDescription: 'New task assignments',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            description,
            contentTitle: '📋 New Task Assigned',
            summaryText: 'Due: $deadlineStr',
          ),
          actions: [
            AndroidNotificationAction(
              'view_task',
              'View Task',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      payload: payload,
    );

    debugPrint('✅ New task notification sent');
  }

  // 4️⃣ Class Update Notification
  Future<void> sendClassUpdateNotification({
    required String classId,
    required String className,
    required String message,
  }) async {
    final payload = jsonEncode({
      'type': 'class_update',
      'classId': classId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await _plugin.show(
      classId.hashCode,
      '🎓 Update from $className',
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'class_updates',
          'Class Updates',
          channelDescription: 'Updates from your classes',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: payload,
    );
  }

  // Cancel task notifications when completed
  Future<void> cancelTaskNotifications(String taskId) async {
    final beforeId = '${taskId}_before'.hashCode;
    final deadlineId = '${taskId}_deadline'.hashCode;
    
    await _plugin.cancel(beforeId);
    await _plugin.cancel(deadlineId);
    
    debugPrint('✅ Cancelled notifications for task: $taskId');
  }
}

// ==================== APP SETUP WITH PAYLOAD HANDLING ====================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final notificationService = EduLinkNotificationService();
  await notificationService.initialize();
  
  runApp(EduLinkApp());
}

class EduLinkApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 🔑 IMPORTANT: Use navigatorKey
      navigatorKey: EduLinkNotificationService.navigatorKey,
      initialRoute: '/home',
      routes: {
        '/home': (context) => HomeScreen(),
        '/task-details': (context) => TaskDetailsScreen(),
        '/notice-details': (context) => NoticeDetailsScreen(),
        '/classroom': (context) => ClassroomScreen(),
      },
    );
  }
}

// ==================== EXAMPLE SCREENS ====================

class HomeScreen extends StatelessWidget {
  final notificationService = EduLinkNotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('EduLink Home')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () {
              // Test: Schedule task deadline notification
              notificationService.scheduleTaskDeadlineNotification(
                taskId: 'task_001',
                classId: 'class_001',
                title: 'Complete Assignment',
                description: 'Chapter 5 exercises',
                deadline: DateTime.now().add(Duration(days: 2)),
              );
            },
            child: Text('Test Task Deadline Notification'),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Test: Send notice notification
              notificationService.sendNewNoticeNotification(
                noticeId: 'notice_001',
                classId: 'class_001',
                title: 'Exam Schedule Published',
                description: 'Mid-term exams will start from next week',
              );
            },
            child: Text('Test Notice Notification'),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Test: Send new task notification
              notificationService.sendNewTaskNotification(
                taskId: 'task_002',
                classId: 'class_001',
                title: 'Lab Report Submission',
                description: 'Submit lab report for experiment 3',
                deadline: DateTime.now().add(Duration(days: 3)),
              );
            },
            child: Text('Test New Task Notification'),
          ),
        ],
      ),
    );
  }
}

class TaskDetailsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 🎯 Get data from payload
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final taskId = args?['taskId'] ?? 'Unknown';
    final classId = args?['classId'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: Text('Task Details')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Opened from Notification!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 24),
            Text('Task ID: $taskId', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Class ID: $classId', style: TextStyle(fontSize: 16)),
            SizedBox(height: 24),
            Text(
              'Here you would fetch full task details from Firestore using the taskId',
              style: TextStyle(color: Colors.grey),
            ),
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
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notice ID: $noticeId',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Fetch notice details from Firestore using noticeId'),
          ],
        ),
      ),
    );
  }
}

class ClassroomScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final classId = args?['classId'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(title: Text('Classroom')),
      body: Center(
        child: Text('Class ID: $classId', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}

// ==================== USAGE IN YOUR EXISTING CODE ====================

/*
YOUR HOME SCREEN এ এভাবে use করবেন:

Future<void> _scheduleNotificationsForUncompletedTasks(
    List<TaskModel> tasks) async {
  try {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final notificationService = EduLinkNotificationService();

    final uncompletedTasks = tasks.where((task) {
      return !task.completedBy.contains(userId) &&
          task.deadline.toDate().isAfter(DateTime.now());
    }).toList();

    for (var task in uncompletedTasks) {
      await notificationService.scheduleTaskDeadlineNotification(
        taskId: task.id!,
        classId: AuthController.classDocId!,
        title: task.title,
        description: task.description,
        deadline: task.deadline.toDate(),
      );
    }
  } catch (e) {
    debugPrint("❌ Error scheduling notifications: $e");
  }
}

// When task is completed
Future<void> onTaskCompleted(String taskId) async {
  final notificationService = EduLinkNotificationService();
  await notificationService.cancelTaskNotifications(taskId);
}
*/