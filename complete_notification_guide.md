# Complete Guide to Notifications in Flutter

## Table of Contents
1. [Types of Notifications](#types-of-notifications)
2. [Local Notifications](#local-notifications)
3. [Push Notifications (FCM)](#push-notifications)
4. [Scheduled Notifications](#scheduled-notifications)
5. [Notification Channels](#notification-channels)
6. [Advanced Features](#advanced-features)
7. [Best Practices](#best-practices)

---

## 1. Types of Notifications

### A. **Local Notifications**
- Generated and displayed **within the app** itself
- Don't require internet or server
- Used for: reminders, alarms, task deadlines
- Package: `flutter_local_notifications`

### B. **Push Notifications (Remote)**
- Sent from a **server** (Firebase, OneSignal, etc.)
- Require internet connection
- Used for: messages, updates, news
- Package: `firebase_messaging`

### C. **Scheduled Notifications**
- Local notifications that appear at a **specific time**
- Can be one-time or recurring
- Requires timezone handling

---

## 2. Local Notifications Deep Dive

### Installation
```yaml
dependencies:
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.0  # For scheduled notifications
```

### Platform Setup

#### Android (android/app/src/main/AndroidManifest.xml)
```xml
<manifest>
    <!-- Permissions -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    
    <application>
        <!-- Notification Icon (Optional) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
        
        <!-- Boot Receiver -->
        <receiver 
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

#### iOS (ios/Runner/Info.plist)
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### Basic Implementation

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = 
      FlutterLocalNotificationsPlugin();
  
  // Initialize
  Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();
    
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // Initialize with callback
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    // Request permissions (Android 13+)
    await _requestPermissions();
  }
  
  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    print("Notification tapped with payload: $payload");
    
    // Navigate to specific screen based on payload
    // navigatorKey.currentState?.pushNamed('/details', arguments: payload);
  }
  
  // Request permissions
  Future<void> _requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }
}
```

---

## 3. Notification Components

### A. Notification Details

```dart
NotificationDetails _createNotificationDetails() {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      'channel_id',           // Channel ID
      'channel_name',         // Channel Name
      channelDescription: 'Channel description',
      
      // Importance & Priority
      importance: Importance.max,      // How intrusive
      priority: Priority.high,         // Sort order
      
      // Visual
      icon: '@mipmap/ic_launcher',
      color: Colors.blue,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      
      // Sound & Vibration
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      
      // Behavior
      autoCancel: true,               // Auto dismiss on tap
      ongoing: false,                 // Can't be dismissed
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      
      // Style
      styleInformation: BigTextStyleInformation(
        'Long text that will be expanded',
        contentTitle: 'Title',
        summaryText: 'Summary',
      ),
      
      // Actions
      actions: [
        AndroidNotificationAction(
          'action_1',
          'Accept',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_2',
          'Reject',
          cancelNotification: true,
        ),
      ],
    ),
    
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.aiff',
      badgeNumber: 1,
      threadIdentifier: 'thread_id',
      attachments: [
        DarwinNotificationAttachment('path/to/image.png'),
      ],
    ),
  );
}
```

### B. Notification Types

#### Simple Notification
```dart
Future<void> showSimpleNotification() async {
  await _plugin.show(
    0,                          // Notification ID
    'Title',                    // Title
    'Body text',                // Body
    _createNotificationDetails(),
    payload: 'data',            // Custom data
  );
}
```

#### Big Picture Notification (Android)
```dart
Future<void> showBigPictureNotification() async {
  final bigPicture = BigPictureStyleInformation(
    FilePathAndroidBitmap('path/to/image.png'),
    largeIcon: FilePathAndroidBitmap('path/to/icon.png'),
    contentTitle: 'Title',
    summaryText: 'Summary',
  );
  
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      styleInformation: bigPicture,
    ),
  );
  
  await _plugin.show(0, 'Title', 'Body', details);
}
```

#### Progress Notification
```dart
Future<void> showProgressNotification() async {
  for (int i = 0; i <= 100; i += 10) {
    await Future.delayed(Duration(seconds: 1));
    
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'progress_channel',
        'Progress',
        showProgress: true,
        maxProgress: 100,
        progress: i,
        ongoing: true,
        autoCancel: false,
      ),
    );
    
    await _plugin.show(0, 'Downloading', '$i%', details);
  }
  
  // Complete
  await _plugin.cancel(0);
}
```

#### Grouped Notifications
```dart
Future<void> showGroupedNotifications() async {
  const groupKey = 'message_group';
  const groupChannelId = 'grouped_channel';
  
  // First notification
  await _plugin.show(
    1,
    'New Message',
    'Hello from John',
    NotificationDetails(
      android: AndroidNotificationDetails(
        groupChannelId,
        'Messages',
        groupKey: groupKey,
      ),
    ),
  );
  
  // Second notification
  await _plugin.show(
    2,
    'New Message',
    'Hello from Jane',
    NotificationDetails(
      android: AndroidNotificationDetails(
        groupChannelId,
        'Messages',
        groupKey: groupKey,
      ),
    ),
  );
  
  // Summary notification
  await _plugin.show(
    0,
    'Messages',
    '2 new messages',
    NotificationDetails(
      android: AndroidNotificationDetails(
        groupChannelId,
        'Messages',
        groupKey: groupKey,
        setAsGroupSummary: true,
      ),
    ),
  );
}
```

---

## 4. Scheduled Notifications

### One-Time Scheduled
```dart
Future<void> scheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
}) async {
  final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
  
  await _plugin.zonedSchedule(
    id,
    title,
    body,
    tzScheduledTime,
    _createNotificationDetails(),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}
```

### Daily Scheduled
```dart
Future<void> scheduleDailyNotification({
  required int id,
  required String title,
  required String body,
  required int hour,
  required int minute,
}) async {
  await _plugin.zonedSchedule(
    id,
    title,
    body,
    _nextInstanceOfTime(hour, minute),
    _createNotificationDetails(),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.time,  // Repeat daily
  );
}

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
```

### Weekly Scheduled
```dart
Future<void> scheduleWeeklyNotification({
  required int id,
  required String title,
  required String body,
  required int weekday,  // 1 = Monday, 7 = Sunday
  required int hour,
  required int minute,
}) async {
  await _plugin.zonedSchedule(
    id,
    title,
    body,
    _nextInstanceOfWeekday(weekday, hour, minute),
    _createNotificationDetails(),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
  );
}

tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
  tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
  
  while (scheduledDate.weekday != weekday) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  
  return scheduledDate;
}
```

---

## 5. Notification Channels (Android)

```dart
Future<void> createNotificationChannel() async {
  const channel = AndroidNotificationChannel(
    'high_importance_channel',  // ID
    'High Importance',          // Name
    description: 'This channel is for important notifications',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification_sound'),
    enableVibration: true,
    showBadge: true,
  );
  
  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

// Multiple channels for different notification types
Future<void> createAllChannels() async {
  final channels = [
    AndroidNotificationChannel(
      'messages',
      'Messages',
      description: 'Message notifications',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'reminders',
      'Reminders',
      description: 'Task reminders',
      importance: Importance.max,
    ),
    AndroidNotificationChannel(
      'updates',
      'Updates',
      description: 'App updates',
      importance: Importance.low,
    ),
  ];
  
  for (final channel in channels) {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
}
```

---

## 6. Push Notifications (Firebase Cloud Messaging)

### Setup FCM

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.9
```

### Implementation

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted permission');
      
      // Get FCM token
      String? token = await _messaging.getToken();
      print('FCM Token: $token');
      
      // Save token to server
      // await _saveTokenToServer(token);
      
      // Listen to token refresh
      _messaging.onTokenRefresh.listen(_saveTokenToServer);
      
      // Setup message handlers
      _setupMessageHandlers();
    }
  }
  
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });
    
    // Background messages (terminated state)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    
    // Message opened app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 Notification opened app');
      _handleNotificationTap(message);
    });
    
    // Check if app opened from notification
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });
  }
  
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    
    await FlutterLocalNotificationsPlugin().show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(/* ... */),
      payload: jsonEncode(message.data),
    );
  }
  
  void _handleNotificationTap(RemoteMessage message) {
    // Navigate based on data
    final data = message.data;
    if (data['type'] == 'chat') {
      // navigatorKey.currentState?.pushNamed('/chat', arguments: data);
    }
  }
}

// Top-level function for background handler
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📬 Background message: ${message.notification?.title}');
}
```

### Sending FCM from Server (Node.js example)

```javascript
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function sendNotification(token, title, body, data) {
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: data,
    token: token,
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        channelId: 'high_importance_channel',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };
  
  try {
    const response = await admin.messaging().send(message);
    console.log('✅ Notification sent:', response);
  } catch (error) {
    console.error('❌ Error sending notification:', error);
  }
}
```

---

## 7. Best Practices

### A. Permission Handling
```dart
Future<bool> requestNotificationPermission() async {
  if (Platform.isAndroid && Build.VERSION.SDK_INT >= 33) {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
  return true;
}
```

### B. Don't Over-Notify
- Respect user preferences
- Use notification channels
- Allow users to disable specific types
- Group related notifications

### C. Timing
- Avoid late-night notifications
- Consider user timezone
- Use quiet hours

### D. Content
- Clear, concise titles
- Actionable body text
- Relevant images/icons
- Useful actions

### E. Testing Checklist
- [ ] Foreground notifications
- [ ] Background notifications
- [ ] Killed app notifications
- [ ] Notification tap handling
- [ ] Permission requests
- [ ] Different Android versions
- [ ] iOS permissions
- [ ] Scheduled notifications persist after reboot
- [ ] Multiple notification handling

---

## Common Issues & Solutions

### Issue: Notifications not showing
**Solutions:**
- Check permissions
- Verify channel importance
- Test on physical device
- Check battery optimization settings

### Issue: Scheduled notifications not working after reboot
**Solutions:**
- Add RECEIVE_BOOT_COMPLETED permission
- Register boot receiver
- Use WorkManager for critical schedules

### Issue: Notification icon not showing
**Solutions:**
- Use white PNG with transparency
- Place in android/app/src/main/res/drawable
- Set in notification details

### Issue: Sound not playing
**Solutions:**
- Place sound file in android/app/src/main/res/raw
- Use RawResourceAndroidNotificationSound
- Check device volume settings

---

## Summary

**Local Notifications**: For app-generated alerts
**Push Notifications**: For server-sent messages
**Scheduled**: For time-based reminders
**Channels**: Organize by type and importance
**Permissions**: Always request properly
**Testing**: Test thoroughly on multiple devices

Remember: Good notifications enhance UX, bad ones annoy users!