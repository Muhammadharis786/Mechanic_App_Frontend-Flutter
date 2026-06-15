import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../screens/authentication/user_session.dart';
import 'emergency_alert_service.dart';

const String _baseUrl =
    'https://mechanicapp-service-621632382478.asia-south1.run.app';

const String emergencyChannelId = 'emergency_channel';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await UserSession().loadSession();
  await FcmNotificationService.instance.ensureBackgroundReady();
  await FcmNotificationService.instance.handleRemoteMessage(
    message,
    fromBackground: true,
  );
}

class FcmNotificationService {
  FcmNotificationService._();

  static final FcmNotificationService instance = FcmNotificationService._();

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
        'onfix_high_importance',
        'OnFix Notifications',
        description: 'Important booking and appointment notifications.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _emergencyChannel =
      AndroidNotificationChannel(
        emergencyChannelId,
        'Emergency Requests',
        description: 'Urgent roadside assistance requests for mechanics.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _backgroundReady = false;

  Future<void> ensureBackgroundReady() async {
    if (_backgroundReady) return;

    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_emergencyChannel);
    await androidPlugin?.createNotificationChannel(_defaultChannel);
    _backgroundReady = true;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _setupLocalNotifications();
    await _setupForegroundMessages();
    await _handleLaunchNotification();

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationOpen(message);
    });

    _messaging.onTokenRefresh.listen((token) {
      syncTokenWithBackend(token: token);
    });

    _backgroundReady = true;
    _initialized = true;
  }

  Future<void> handleRemoteMessage(
    RemoteMessage message, {
    required bool fromBackground,
  }) async {
    final data = Map<String, dynamic>.from(message.data);
    if (!EmergencyAlertService.isRoadRequestPayload(data)) return;
    if (!EmergencyAlertService.isMechanicSession()) return;

    final normalized = EmergencyAlertService.normalizeRoadRequest(data);
    final requestId = normalized['requestId']?.toString() ?? 'road_request';

    if (fromBackground) {
      await _showEmergencyNotification(
        id: requestId.hashCode,
        title: message.notification?.title ?? 'Emergency Request',
        body: message.notification?.body ??
            'Need Emergency: ${normalized['userNotes'] ?? 'New roadside request'}',
        payload: jsonEncode(normalized),
      );
      return;
    }

    await EmergencyAlertService.instance.openRoadRequestAlert(normalized);
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

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            EmergencyAlertService.instance.openRoadRequestAlert(
              Map<String, dynamic>.from(decoded),
            );
          }
        } catch (e) {
          debugPrint('Notification payload decode error: $e');
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_defaultChannel);
    await androidPlugin?.createNotificationChannel(_emergencyChannel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _setupForegroundMessages() async {
    FirebaseMessaging.onMessage.listen((message) async {
      if (kIsWeb) return;

      final data = Map<String, dynamic>.from(message.data);
      if (EmergencyAlertService.isRoadRequestPayload(data) &&
          EmergencyAlertService.isMechanicSession()) {
        await handleRemoteMessage(message, fromBackground: false);
        return;
      }

      final notification = message.notification;
      if (notification == null) return;

      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _defaultChannel.id,
            _defaultChannel.name,
            channelDescription: _defaultChannel.description,
            icon: notification.android?.smallIcon ?? '@drawable/ic_notification',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    });
  }

  Future<void> _handleLaunchNotification() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage == null) return;

    await UserSession().loadSession();
    _handleNotificationOpen(initialMessage);
  }

  void _handleNotificationOpen(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    if (!EmergencyAlertService.isRoadRequestPayload(data)) return;
    if (!EmergencyAlertService.isMechanicSession()) return;

    EmergencyAlertService.instance.openRoadRequestAlert(
      EmergencyAlertService.normalizeRoadRequest(data),
    );
  }

  Future<void> _showEmergencyNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _emergencyChannel.id,
          _emergencyChannel.name,
          channelDescription: _emergencyChannel.description,
          icon: '@drawable/ic_notification',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          ongoing: true,
          autoCancel: false,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 800]),
          sound: const RawResourceAndroidNotificationSound('emergency'),
        ),
      ),
      payload: payload,
    );
  }
}
