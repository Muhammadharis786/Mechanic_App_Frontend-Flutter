import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../screens/authentication/user_session.dart';

const String _baseUrl =
    'https://mechanicapp-service-621632382478.asia-south1.run.app';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('FCM background message: ${message.messageId}');
}

class FcmNotificationService {
  FcmNotificationService._();

  static final FcmNotificationService instance = FcmNotificationService._();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'onfix_high_importance',
        'OnFix Notifications',
        description: 'Important booking and appointment notifications.',
        importance: Importance.high,
      );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _setupLocalNotifications();
    await _setupForegroundMessages();

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM opened notification: ${message.messageId}');
    });

    _messaging.onTokenRefresh.listen((token) {
      syncTokenWithBackend(token: token);
    });

    _initialized = true;
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM token error: $e');
      return null;
    }
  }

  Future<void> syncTokenWithBackend({String? token}) async {
    final session = UserSession();
    final fcmToken = token ?? await getToken();

    if (fcmToken == null || fcmToken.isEmpty) {
      debugPrint('FCM token is empty; skipping backend sync.');
      return;
    }

    final headers = session.getAuthHeader();
    if (headers.isEmpty) {
      debugPrint('No active session; skipping FCM backend sync.');
      return;
    }

    final body = <String, dynamic>{
      'token': fcmToken,
      'fcmToken': fcmToken,
      'role': session.userType,
      'userType': session.userType,
      'userId': session.userId,
      'platform': defaultTargetPlatform.name,
    };

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/fcm/token'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('FCM token synced with backend.');
      } else {
        debugPrint(
          'FCM token sync failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('FCM token sync error: $e');
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM delete token error: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('FCM permission: ${settings.authorizationStatus}');
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(settings: initializationSettings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _setupForegroundMessages() async {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final android = notification?.android;

      if (notification == null || kIsWeb) return;

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: android?.smallIcon ?? '@drawable/ic_notification',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });
  }
}
