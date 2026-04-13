import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../screens/authentication/user_session.dart';

class WebSocketService {
  StompClient? client;
  final Function(Map<String, dynamic>) onNotificationReceived;

  WebSocketService({required this.onNotificationReceived});

  void connect(int mechanicId) {
    client = StompClient(
      config: StompConfig(
        url: 'wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket',
        stompConnectHeaders: UserSession().getAuthHeader(),
        webSocketConnectHeaders: UserSession().getAuthHeader(),
        onConnect: (StompFrame frame) {
          print('✅ Connected to WebSocket');
          _subscribe(mechanicId);
        },
        onStompError: (frame) => print('❌ STOMP Error: ${frame.body}'),
        onWebSocketError: (error) => print('❌ WebSocket Error: $error'),
        onDisconnect: (frame) => print('ℹ️ Disconnected from WebSocket'),
      ),
    );
    client?.activate();
  }

  void _subscribe(int mechanicId) {
    client?.subscribe(
      destination: '/topic/nearbymechanics/$mechanicId',
      callback: (frame) {
        if (frame.body != null) {
          print('📩 Notification received: ${frame.body}');
          try {
            final data = jsonDecode(frame.body!);
            onNotificationReceived(data);
          } catch (e) {
            print('❌ Error decoding notification: $e');
          }
        }
      },
    );
  }

  void disconnect() {
    client?.deactivate();
  }
}
