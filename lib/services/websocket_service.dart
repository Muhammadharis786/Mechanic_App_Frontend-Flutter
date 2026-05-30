import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../screens/authentication/user_session.dart';

class WebSocketService {
  StompClient? client;
  final Function(dynamic data, String type) onNotificationReceived;

  WebSocketService({required this.onNotificationReceived});

  void connect(int mechanicId) {
    client = StompClient(
      config: StompConfig(
        url:
            'wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket',
        stompConnectHeaders: UserSession().getAuthHeader(),
        webSocketConnectHeaders: UserSession().getAuthHeader(),
        onConnect: (StompFrame frame) {
          debugPrint('Connected to WebSocket');
          _subscribe(mechanicId);
        },
        onStompError: (frame) => debugPrint('STOMP Error: ${frame.body}'),
        onWebSocketError: (error) => debugPrint('WebSocket Error: $error'),
        onDisconnect: (frame) => debugPrint('Disconnected from WebSocket'),
      ),
    );
    client?.activate();
  }

  void _subscribe(int mechanicId) {
    _subscribeToTopic('/topic/nearbymechanics/$mechanicId', 'road');
    _subscribeToTopic(
      '/topic/bookappointment/nearbymechanics/$mechanicId',
      'appointment',
    );
    _subscribeToTopic(
      '/topic/appointment/cancelappointment/$mechanicId',
      'cancel',
    );
    _subscribeToTopic('/topic/appointment/expired/$mechanicId', 'expired');
    _subscribeToTopic('/topic/mechanic/requests/$mechanicId', 'serviceRequest');
  }

  void _subscribeToTopic(String destination, String type) {
    subscribe(
      destination: destination,
      onMessage: (body) {
        if (body == null) return;
        debugPrint('[$type] Notification received on $destination: $body');
        try {
          final dynamic decoded = jsonDecode(body);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map) onNotificationReceived(item, type);
            }
          } else {
            onNotificationReceived(decoded, type);
          }
        } catch (e) {
          debugPrint('Error decoding notification: $e');
        }
      },
    );
  }

  StompUnsubscribe? subscribe({
    required String destination,
    required Function(String? body) onMessage,
  }) {
    return client?.subscribe(
      destination: destination,
      callback: (frame) => onMessage(frame.body),
    );
  }

  void disconnect() {
    client?.deactivate();
  }
}
