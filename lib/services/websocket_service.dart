import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../screens/authentication/user_session.dart';

class WebSocketService {
  StompClient? client;
  final Function(dynamic data, String type) onNotificationReceived;
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;

  WebSocketService({
    required this.onNotificationReceived,
    this.onConnected,
    this.onDisconnected,
  });

  void connect(int mechanicId) {
    // mechanicId ko STOMP CONNECT frame ke custom header may bhejo — backend
    // isay use karega taake session disconnect hone pe pata chal sake
    // yeh konsa mechanic tha (crash/force-kill safety net ke liye).
    final connectHeaders = <String, String>{
      ...UserSession().getAuthHeader(),
      'mechanicId': mechanicId.toString(),
    };

    client = StompClient(
      config: StompConfig(
        url:
            'wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket',
        stompConnectHeaders: connectHeaders,
        webSocketConnectHeaders: connectHeaders,
        onConnect: (StompFrame frame) {
          debugPrint('✅ Connected to WebSocket for mechanic ID: $mechanicId');
          _subscribe(mechanicId);
          onConnected?.call();
        },
        onStompError: (frame) => debugPrint('❌ STOMP Error: ${frame.body}'),
        onWebSocketError: (error) => debugPrint('❌ WebSocket Error: $error'),
        onDisconnect: (frame) {
          debugPrint('💔 Disconnected from WebSocket');
          onDisconnected?.call();
        },
      ),
    );
    client?.activate();
  }

  /// Send message to backend (for heartbeat, etc.)
  void sendMessage({required String destination, required String body}) {
    if (client == null || !client!.connected) {
      debugPrint('❌ Cannot send message - WebSocket not connected');
      throw Exception('WebSocket not connected');
    }
    
    try {
      client!.send(
        destination: destination,
        body: body,
      );
    } catch (e) {
      debugPrint('❌ Error sending message to $destination: $e');
      rethrow;
    }
  }

  /// Ensure WebSocket is connected, reconnect if needed
  void ensureConnected(int mechanicId) {
    if (client == null || !client!.connected) {
      debugPrint('🔄 Reconnecting WebSocket for mechanic ID: $mechanicId');
      connect(mechanicId);
    }
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
    _subscribeToTopic(
      '/topic/mechanic/slectedmechanic/requests/$mechanicId',
      'serviceRequest',
    );
    _subscribeToTopic(
      '/topic/appointment/appointmentdone/$mechanicId',
      'appointment_done',
    );
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