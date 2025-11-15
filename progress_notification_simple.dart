import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// ==================== SIMPLE PROGRESS BAR NOTIFICATION ====================

class ProgressNotificationExample {
  final FlutterLocalNotificationsPlugin _plugin = 
      FlutterLocalNotificationsPlugin();

  // Initialize
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    await _plugin.initialize(
      InitializationSettings(android: androidSettings),
    );
  }

  // ==================== METHOD 1: BASIC PROGRESS BAR ====================
  
  // Show progress notification
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required int progress,      // Current progress (0-100)
    required int maxProgress,   // Total (usually 100)
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      importance: Importance.low,
      priority: Priority.low,
      
      // 🔑 KEY PART: Progress bar enable করুন
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress,
      
      // Keep notification until complete
      ongoing: progress < maxProgress,
      autoCancel: false,
      
      // Show percentage
      onlyAlertOnce: true,
    );

    await _plugin.show(
      id,
      title,
      '$progress% completed',  // Body text
      NotificationDetails(android: androidDetails),
    );
  }

  // ==================== METHOD 2: SIMULATING DOWNLOAD ====================
  
  // Simulate download with progress
  Future<void> simulateDownload() async {
    const notificationId = 1;
    
    // Loop: 0% to 100%
    for (int i = 0; i <= 100; i += 10) {
      await Future.delayed(Duration(milliseconds: 500));
      
      // Update notification with new progress
      await showProgressNotification(
        id: notificationId,
        title: 'Downloading file...',
        progress: i,
        maxProgress: 100,
      );
      
      debugPrint('Progress: $i%');
    }
    
    // Download complete!
    await _showDownloadCompleteNotification(notificationId);
  }

  // Show completion notification
  Future<void> _showDownloadCompleteNotification(int id) async {
    await _plugin.show(
      id,
      '✅ Download Complete',
      'File downloaded successfully',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'downloads',
          'Downloads',
          importance: Importance.high,
          playSound: true,
        ),
      ),
    );
  }

  // ==================== METHOD 3: REAL FILE DOWNLOAD ====================
  
  Future<void> downloadFile({
    required String url,
    required String fileName,
  }) async {
    try {
      const notificationId = 2;
      final dio = Dio();
      
      // Get download directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      
      debugPrint('📥 Starting download: $url');
      debugPrint('💾 Saving to: $filePath');
      
      // Download with progress tracking
      await dio.download(
        url,
        filePath,
        
        // 🔑 Progress callback
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Calculate percentage
            final progress = (received / total * 100).toInt();
            
            // Update notification
            showProgressNotification(
              id: notificationId,
              title: 'Downloading $fileName',
              progress: progress,
              maxProgress: 100,
            );
            
            debugPrint('Download: $progress%');
          }
        },
      );
      
      // Download complete
      debugPrint('✅ Download complete!');
      await _showDownloadCompleteNotification(notificationId);
      
    } catch (e) {
      debugPrint('❌ Download error: $e');
      await _showDownloadErrorNotification();
    }
  }

  Future<void> _showDownloadErrorNotification() async {
    await _plugin.show(
      999,
      '❌ Download Failed',
      'Could not download file',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'downloads',
          'Downloads',
          importance: Importance.high,
        ),
      ),
    );
  }

  // ==================== METHOD 4: INDETERMINATE PROGRESS ====================
  
  // Indeterminate progress (যখন total size জানা নেই)
  Future<void> showIndeterminateProgress() async {
    final androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      importance: Importance.low,
      
      // 🔑 Indeterminate progress (spinning animation)
      showProgress: true,
      maxProgress: 0,  // 0 means indeterminate
      progress: 0,
      
      ongoing: true,
      autoCancel: false,
    );

    await _plugin.show(
      3,
      'Processing...',
      'Please wait',
      NotificationDetails(android: androidDetails),
    );
  }

  // ==================== METHOD 5: MULTIPLE DOWNLOADS ====================
  
  Future<void> downloadMultipleFiles(List<String> urls) async {
    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];
      final fileName = 'file_${i + 1}.pdf';
      
      await downloadFile(url: url, fileName: fileName);
      
      // Small delay between downloads
      await Future.delayed(Duration(seconds: 1));
    }
  }

  // Cancel download
  Future<void> cancelDownload(int notificationId) async {
    await _plugin.cancel(notificationId);
    debugPrint('❌ Download cancelled');
  }
}

// ==================== FULL DEMO APP ====================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final progressService = ProgressNotificationExample();
  await progressService.initialize();
  
  runApp(MyApp(progressService: progressService));
}

class MyApp extends StatelessWidget {
  final ProgressNotificationExample progressService;

  MyApp({required this.progressService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DownloadDemo(progressService: progressService),
    );
  }
}

class DownloadDemo extends StatelessWidget {
  final ProgressNotificationExample progressService;

  DownloadDemo({required this.progressService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Progress Notification Demo')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Example 1: Simulate download
            ElevatedButton(
              onPressed: () {
                progressService.simulateDownload();
              },
              child: Text('📊 Simulate Download (0-100%)'),
            ),
            SizedBox(height: 16),

            // Example 2: Real download (small file)
            ElevatedButton(
              onPressed: () {
                progressService.downloadFile(
                  url: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
                  fileName: 'sample.pdf',
                );
              },
              child: Text('📥 Download PDF File'),
            ),
            SizedBox(height: 16),

            // Example 3: Download image
            ElevatedButton(
              onPressed: () {
                progressService.downloadFile(
                  url: 'https://picsum.photos/2000/2000',
                  fileName: 'image.jpg',
                );
              },
              child: Text('🖼️ Download Image'),
            ),
            SizedBox(height: 16),

            // Example 4: Indeterminate progress
            ElevatedButton(
              onPressed: () async {
                await progressService.showIndeterminateProgress();
                
                // Simulate some work
                await Future.delayed(Duration(seconds: 3));
                
                // Done
                await progressService._showDownloadCompleteNotification(3);
              },
              child: Text('⏳ Indeterminate Progress'),
            ),
            SizedBox(height: 16),

            // Example 5: Manual progress control
            ElevatedButton(
              onPressed: () {
                _showManualProgressDemo(context);
              },
              child: Text('🎮 Manual Progress Control'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualProgressDemo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ManualProgressDialog(
        progressService: progressService,
      ),
    );
  }
}

// ==================== MANUAL PROGRESS CONTROL ====================

class ManualProgressDialog extends StatefulWidget {
  final ProgressNotificationExample progressService;

  ManualProgressDialog({required this.progressService});

  @override
  State<ManualProgressDialog> createState() => _ManualProgressDialogState();
}

class _ManualProgressDialogState extends State<ManualProgressDialog> {
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Manual Progress'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Progress: ${_progress.toInt()}%'),
          SizedBox(height: 16),
          Slider(
            value: _progress,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_progress.toInt()}%',
            onChanged: (value) {
              setState(() {
                _progress = value;
              });
              
              // Update notification
              widget.progressService.showProgressNotification(
                id: 99,
                title: 'Manual Progress',
                progress: _progress.toInt(),
                maxProgress: 100,
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.progressService.cancelDownload(99);
            Navigator.pop(context);
          },
          child: Text('Close'),
        ),
      ],
    );
  }
}

// ==================== REAL WORLD EXAMPLE ====================

class FileDownloadManager {
  final ProgressNotificationExample _progressService;

  FileDownloadManager(this._progressService);

  // Download assignment file
  Future<void> downloadAssignment({
    required String assignmentId,
    required String fileName,
    required String downloadUrl,
  }) async {
    final notificationId = assignmentId.hashCode;
    
    try {
      debugPrint('📥 Downloading assignment: $fileName');
      
      final dio = Dio();
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      
      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toInt();
            
            // Show progress
            _progressService.showProgressNotification(
              id: notificationId,
              title: 'Downloading $fileName',
              progress: progress,
              maxProgress: 100,
            );
          }
        },
      );
      
      // Success
      await _showSuccessNotification(notificationId, fileName, filePath);
      
    } catch (e) {
      debugPrint('❌ Download failed: $e');
      await _showErrorNotification(notificationId, fileName);
    }
  }

  Future<void> _showSuccessNotification(
    int id,
    String fileName,
    String filePath,
  ) async {
    await _progressService._plugin.show(
      id,
      '✅ Download Complete',
      fileName,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'downloads',
          'Downloads',
          importance: Importance.high,
          styleInformation: BigTextStyleInformation(
            'File saved to: $filePath',
            contentTitle: '✅ Download Complete',
          ),
          actions: [
            AndroidNotificationAction(
              'open',
              'Open File',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showErrorNotification(int id, String fileName) async {
    await _progressService._plugin.show(
      id,
      '❌ Download Failed',
      'Could not download $fileName',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'downloads',
          'Downloads',
          importance: Importance.high,
        ),
      ),
    );
  }
}

// ==================== KEY POINTS ====================

/*
✅ PROGRESS BAR NOTIFICATION:

1. showProgress: true  → Enable progress bar
2. maxProgress: 100    → Total (usually 100%)
3. progress: 45        → Current progress
4. ongoing: true       → Can't dismiss until done

🔑 SIMPLE FORMULA:
progress = (downloaded / total) * 100

📊 TYPES:
- Determinate: জানা আছে কতটুকু download হবে (0-100%)
- Indeterminate: জানা নেই, শুধু spinning animation

💡 TIPS:
- Use Importance.low to avoid sound
- Set ongoing: true to prevent dismissal
- Update every 5-10% to avoid lag
- Show completion notification when done

📦 REQUIRED PACKAGES:
dependencies:
  flutter_local_notifications: ^17.0.0
  dio: ^5.0.0  # For downloading
  path_provider: ^2.0.0  # For file path
*/