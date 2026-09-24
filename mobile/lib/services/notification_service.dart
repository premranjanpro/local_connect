import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  final data = message.data;
  final type = data['type']?.toString();

  if (type == 'incoming_call') {
    await NotificationService.showIncomingCallNotification(
      callId: data['callId'] ?? '',
      callerName: data['callerName'] ?? 'Incoming Call',
      callerRole: data['callerRole'] ?? 'Caller',
      liveKitUrl: data['liveKitUrl'],
      calleeToken: data['calleeToken'],
    );
  } else if (type == 'ongoing_order') {
    await NotificationService.showOngoingOrderNotification(
      id: 101,
      title: message.notification?.title ?? 'Live Order Update',
      body: message.notification?.body ?? 'Your delivery is in progress',
    );
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // Global callback for incoming call navigation
  static Function(Map<String, dynamic> callData)? onCallReceived;
  // Global callback for real-time task refresh
  static Function(Map<String, dynamic> taskData)? onTaskUpdated;

  static const String ongoingChannelId = 'shopconnector_ongoing_orders';
  static const String callChannelId = 'shopconnector_calls';

  static Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            if (data['type'] == 'incoming_call' && onCallReceived != null) {
              onCallReceived!(data);
            } else if (onTaskUpdated != null) {
              onTaskUpdated!(data);
            }
          } catch (_) {}
        }
      },
    );

    final androidNotificationPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidNotificationPlugin != null) {
      await androidNotificationPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          ongoingChannelId,
          'Ongoing Orders & Dispatches',
          description: 'Live delivery progress, Driver ETA, and Pickup OTP',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidNotificationPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          callChannelId,
          'Incoming Voice & VoIP Calls',
          description: 'High-priority incoming call alerts with Accept & Decline buttons',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    _isInitialized = true;
  }

  static Future<void> initFirebaseMessaging() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final data = message.data;
        final type = data['type']?.toString();

        if (type == 'incoming_call') {
          showIncomingCallNotification(
            callId: data['callId'] ?? '',
            callerName: data['callerName'] ?? 'Incoming Call',
            callerRole: data['callerRole'] ?? 'Caller',
            liveKitUrl: data['liveKitUrl'],
            calleeToken: data['calleeToken'],
          );
          if (onCallReceived != null) {
            onCallReceived!(data);
          }
        } else {
          // Play rich audio alert & vibration
          try {
            SystemSound.play(SystemSoundType.alert);
            HapticFeedback.heavyImpact();
          } catch (_) {}

          showOngoingOrderNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: message.notification?.title ?? 'Order & Delivery Alert',
            body: message.notification?.body ?? '',
          );

          if (onTaskUpdated != null) {
            onTaskUpdated!(data);
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('FirebaseMessaging init skipped/deferred: $e');
      }
    }
  }

  static Future<void> showOngoingOrderNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      ongoingChannelId,
      'Ongoing Orders & Dispatches',
      channelDescription: 'Live delivery progress, Driver ETA, and Pickup OTP',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      styleInformation: BigTextStyleInformation(body),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
    } catch (_) {}
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  static Future<void> showIncomingCallNotification({
    required String callId,
    required String callerName,
    required String callerRole,
    String? liveKitUrl,
    String? calleeToken,
  }) async {
    await initialize();

    final payload = jsonEncode({
      'type': 'incoming_call',
      'callId': callId,
      'callerName': callerName,
      'callerRole': callerRole,
      'liveKitUrl': liveKitUrl,
      'calleeToken': calleeToken,
    });

    final androidDetails = AndroidNotificationDetails(
      callChannelId,
      'Incoming Voice & VoIP Calls',
      channelDescription: 'High-priority incoming call alerts with Accept & Decline buttons',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'action_accept',
          'Accept Call',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'action_decline',
          'Decline',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (_) {}
    await _notificationsPlugin.show(
      id: 999,
      title: '📞 Incoming Call: $callerName',
      body: '$callerRole is calling regarding your order',
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  static Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  static Future<void> cancelCall() async {
    await _notificationsPlugin.cancel(id: 999);
  }
}
