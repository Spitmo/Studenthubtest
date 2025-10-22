import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Initialize notifications
  static Future<void> initialize() async {
    // Initialize timezone
    try {
      tz.initializeTimeZones();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize timezones: $e');
      }
    }

    // Request permission for notifications
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission for notifications');
      }
    } else {
      if (kDebugMode) {
        print('User declined or has not accepted permission for notifications');
      }
    }

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  // Get FCM token
  static Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  // Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topic $topic: $e');
      }
    }
  }

  // Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from topic $topic: $e');
      }
    }
  }

  // Show local notification
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
    String? channelDescription,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId ?? 'default_channel',
      channelName ?? 'Default Channel',
      channelDescription: channelDescription ?? 'Default notification channel',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Schedule notification
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final androidDetails = const AndroidNotificationDetails(
      'scheduled_channel',
      'Scheduled Notifications',
      channelDescription: 'Notifications scheduled for later',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convert DateTime to TZDateTime
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      notificationDetails,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Cancel notification
  static Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Handle background messages
  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    if (kDebugMode) {
      print('Handling background message: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
    }

    // Show local notification for background messages
    if (message.notification != null) {
      await showLocalNotification(
        id: message.hashCode,
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? 'You have a new notification',
        payload: message.data['route'],
      );
    }
  }

  // Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Received foreground message: ${message.messageId}');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
    }

    // Show local notification for foreground messages
    if (message.notification != null) {
      showLocalNotification(
        id: message.hashCode,
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? 'You have a new notification',
        payload: message.data['route'],
      );
    }
  }

  // Handle when message opened app
  static void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('App opened from notification: ${message.messageId}');
    }
    
    // Navigate to specific screen based on message data
    final route = message.data['route'];
    if (route != null) {
      // Navigation will be handled by the router
      _navigateToRoute(route);
    }
  }

  // Handle local notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped with payload: ${response.payload}');
    }
    
    if (response.payload != null) {
      _navigateToRoute(response.payload!);
    }
  }

  // Navigate to route (will be implemented with go_router)
  static void _navigateToRoute(String route) {
    // This will be implemented when we add go_router
    if (kDebugMode) {
      print('Should navigate to: $route');
    }
  }

  // Notification types for different scenarios
  static Future<void> sendEventReminder({
    required String eventTitle,
    required DateTime eventTime,
  }) async {
    final notificationTime = eventTime.subtract(const Duration(hours: 1));
    
    if (notificationTime.isAfter(DateTime.now())) {
      await scheduleNotification(
        id: eventTitle.hashCode,
        title: 'Event Reminder',
        body: '$eventTitle starts in 1 hour',
        scheduledTime: notificationTime,
        payload: 'events',
      );
    }
  }

  static Future<void> sendFileStatusNotification({
    required String fileName,
    required String status,
  }) async {
    String title;
    String body;
    
    switch (status.toLowerCase()) {
      case 'approved':
        title = 'File Approved';
        body = 'Your file "$fileName" has been approved';
        break;
      case 'rejected':
        title = 'File Rejected';
        body = 'Your file "$fileName" has been rejected';
        break;
      default:
        title = 'File Status Update';
        body = 'Your file "$fileName" status: $status';
    }

    await showLocalNotification(
      id: fileName.hashCode,
      title: title,
      body: body,
      payload: 'notes',
    );
  }

  static Future<void> sendNewMessageNotification({
    required String senderName,
    required String messageText,
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'New Message from $senderName',
      body: messageText,
      payload: 'discussion',
      channelId: 'messages',
      channelName: 'Messages',
      channelDescription: 'New message notifications',
    );
  }
}