import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../screens/authentication/user_session.dart';

/// WebSocket service for user-side real-time appointment notifications.
/// Listens to appointment accept, reject, on-the-way, and cancel topics.
class UserWebSocketService {
  StompClient? client;

  /// Called whenever a real-time notification arrives.
  /// [data] = decoded JSON payload, [type] = topic type string.
  final Function(Map<String, dynamic> data, String type) onNotificationReceived;

  UserWebSocketService({required this.onNotificationReceived});

  void connect(int userId) {
    client = StompClient(
      config: StompConfig(
        url: 'wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket',
        stompConnectHeaders: UserSession().getAuthHeader(),
        webSocketConnectHeaders: UserSession().getAuthHeader(),
        onConnect: (StompFrame frame) {
          print('✅ User WebSocket Connected');
          _subscribe(userId);
        },
        onStompError: (frame) => print('❌ User STOMP Error: ${frame.body}'),
        onWebSocketError: (error) => print('❌ User WebSocket Error: $error'),
        onDisconnect: (frame) => print('ℹ️ User WebSocket Disconnected'),
      ),
    );
    client?.activate();
  }

  void _subscribe(int userId) {
    // Mechanic accepted appointment → user gets notified
    _subscribeToTopic('/topic/appointment/acceptappointment/$userId', 'accepted');
    // All mechanics rejected → final rejection notification
    _subscribeToTopic('/topic/appointment/final-reject/$userId', 'rejected');
    // Mechanic started appointment (on the way)
    _subscribeToTopic('/topic/appointment/on-the-way/$userId', 'on_the_way');
  }

  void _subscribeToTopic(String destination, String type) {
    client?.subscribe(
      destination: destination,
      callback: (frame) {
        if (frame.body != null) {
          print('📩 [User-$type] Notification: ${frame.body}');
          try {
            final dynamic decoded = jsonDecode(frame.body!);
            if (decoded is Map) {
              onNotificationReceived(Map<String, dynamic>.from(decoded), type);
            }
          } catch (e) {
            print('❌ Error decoding user notification: $e');
          }
        }
      },
    );
  }

  void disconnect() {
    client?.deactivate();
  }
}
