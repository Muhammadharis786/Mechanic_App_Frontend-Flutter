import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../main.dart'; // To access navigatorKey
import '../screens/authentication/user_session.dart';
import '../utils/time_utils.dart';
import 'active_service_request_tracking.dart';
import 'websocket_service.dart';
import 'emergency_alert_service.dart';

class MechanicNotificationController {
  // Singleton
  static final MechanicNotificationController _instance =
      MechanicNotificationController._internal();
  factory MechanicNotificationController() => _instance;
  MechanicNotificationController._internal();

  WebSocketService? _webSocketService;
  OverlayEntry? _overlayEntry;
  Timer? _heartbeatTimer;
  int? _mechanicId;
  bool _isDisposed = false;
  bool _isOnline = false;

  final List<Function(Map<String, dynamic> data, String type)> _listeners = [];

  void addListener(Function(Map<String, dynamic> data, String type) callback) {
    _listeners.add(callback);
  }

  void removeListener(Function(Map<String, dynamic> data, String type) callback) {
    _listeners.remove(callback);
  }

  void ensureConnected() {
    if (_webSocketService != null && _mechanicId != null) {
      _webSocketService!.ensureConnected(_mechanicId!);
    }
  }

  void init() {
    if (_webSocketService != null) return;

    final int? mechId = UserSession().userId;
    if (mechId == null) return;

    _mechanicId = mechId;
    _isDisposed = false;

    _webSocketService = WebSocketService(
      onNotificationReceived: (data, type) {
        if (data is! Map) return;
        final mapData = Map<String, dynamic>.from(data);
        final String backendType = mapData['type']?.toString() ?? '';

        if (backendType == 'ROAD_REQUEST_CANCELLED') {
          _removeOverlay();
          final requestId = mapData['requestId']?.toString() ??
              mapData['requestid']?.toString();
          if (requestId != null && requestId.isNotEmpty) {
            ActiveServiceRequestTracking.clearIfMatches(requestId);
          } else if (ActiveServiceRequestTracking.current.value != null) {
            ActiveServiceRequestTracking.clear();
          }
          for (var listener in _listeners) {
            listener(mapData, type);
          }
          return;
        }

        if (backendType == 'ROAD_REQUEST_EXPIRED') {
          _removeOverlay();
          _showExpiredSnackBar(mapData['message']?.toString());
          for (var listener in _listeners) {
            listener(mapData, type);
          }
          return;
        }

        final resolvedRoadRequestId = mapData['requestId'] ??
            mapData['requestid'] ??
            mapData['serviceRequestId'] ??
            mapData['servicerequestid'] ??
            mapData['roadRequestId'] ??
            mapData['roadrequestid'] ??
            mapData['request_id'];
        final hasRoadRequestId = resolvedRoadRequestId != null;
        final hasRoadRequestLocation =
            mapData.containsKey('userLatitude') ||
                mapData.containsKey('userLat') ||
                mapData.containsKey('latitude');

        if ((hasRoadRequestLocation && hasRoadRequestId) ||
            mapData.containsKey('userNotes') ||
            mapData.containsKey('notes')) {
          mapData['requestId'] = mapData['requestId'] ?? resolvedRoadRequestId;
          EmergencyAlertService.instance.openRoadRequestAlert(mapData);
          final request = _mapRoadRequest(mapData);
          for (var listener in _listeners) {
            listener(request, type);
          }
          return;
        }

        final request = type == 'appointment'
            ? _mapAppointmentRequest(mapData)
            : (type == 'cancel' || type == 'expired')
            ? _mapStatusNotification(mapData, type)
            : _mapRoadRequest(mapData);

        showNotificationOverlay(request, type, backendType: backendType);

        for (var listener in _listeners) {
          listener(request, type);
        }
      },
      onConnected: () {
        // ✅ Start heartbeat ONLY if mechanic is online
        if (_isOnline) {
          _startHeartbeat();
        }
      },
      onDisconnected: () {
        _stopHeartbeat();
      },
    );

    _webSocketService!.connect(mechId);
  }

  void _startHeartbeat() {
    final sessionUserType = UserSession().userType?.toUpperCase();
    if (sessionUserType != 'MECHANIC') return;
    if (_isDisposed) return;

    _stopHeartbeat();
    if (_mechanicId == null) return;

    _isOnline = true;
    debugPrint("💓 Starting heartbeat for mechanic ID: $_mechanicId");

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final currentUserType = UserSession().userType?.toUpperCase();
      if (currentUserType != 'MECHANIC') {
        timer.cancel();
        _heartbeatTimer = null;
        return;
      }

      if (!_isOnline) {
        timer.cancel();
        _heartbeatTimer = null;
        return;
      }

      if (_isDisposed || _mechanicId == null || _webSocketService == null) {
        timer.cancel();
        _heartbeatTimer = null;
        return;
      }

      _sendHeartbeat();
    });

    // Send initial heartbeat ONLY if WebSocket is already connected
    if (_webSocketService != null && (_webSocketService!.client?.connected ?? false)) {
      _sendHeartbeat();
    }
  }

  void _stopHeartbeat() {
    if (_heartbeatTimer != null) {
      debugPrint("💔 Stopping heartbeat for mechanic ID: $_mechanicId");
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  void _sendHeartbeat() {
    final sessionUserType = UserSession().userType?.toUpperCase();
    if (sessionUserType != 'MECHANIC') {
      _stopHeartbeat();
      return;
    }

    if (_isDisposed || _webSocketService == null || _mechanicId == null) return;

    try {
      _webSocketService!.sendMessage(
        destination: '/app/heartbeat',
        body: jsonEncode({'mechanicId': _mechanicId}),
      );
      debugPrint("💚 Heartbeat sent for mechanic ID: $_mechanicId");
    } catch (e) {
      // Don't stop timer - will retry on next tick
    }
  }

  void resumeHeartbeat() {
    if (!_isOnline) return;
    if (_webSocketService != null && _mechanicId != null) {
      _webSocketService!.ensureConnected(_mechanicId!);
    }
  }

  void startHeartbeatIfOnline() {
    _isOnline = true;
    _startHeartbeat();
  }

  void stopHeartbeatOnly() {
    _stopHeartbeat();
  }

  void disconnectCompletely() {
    _isOnline = false;
    _stopHeartbeat();
    _webSocketService?.disconnect();
  }

  void dispose() {
    _isDisposed = true;
    _stopHeartbeat();
    _webSocketService?.disconnect();
    _webSocketService = null;
    _removeOverlay();
    _mechanicId = null;
    _listeners.clear();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showExpiredSnackBar(String? message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message?.isNotEmpty == true
              ? message!
              : 'This request was accepted by another mechanic',
        ),
        backgroundColor: Colors.orange.shade800,
      ),
    );
  }

  StompUnsubscribe? subscribeToTopic({
    required String destination,
    required Function(Map<String, dynamic> data) onMessage,
  }) {
    if (_webSocketService == null) return null;

    return _webSocketService!.subscribe(
      destination: destination,
      onMessage: (body) {
        if (body == null) return;
        try {
          final data = jsonDecode(body);
          if (data is Map) {
            onMessage(Map<String, dynamic>.from(data));
          }
        } catch (_) {}
      },
    );
  }

  void showNotificationOverlay(
    Map<String, dynamic> request,
    String type, {
    String? backendType,
  }) {
    _removeOverlay();

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final String userName = request['userName'] ?? 'New Request';
    final String location = request['location'] ?? 'Nearby location';
    final String userimage = request['userimage'] ?? '';
    final String distance = request['distance'] ?? '';

    String title = type == 'appointment'
        ? 'New Appointment Request!'
        : 'New Daily Request!';
    Color accentColor = const Color(0xFFFB3300);
    IconData headerIcon = Icons.notifications_active_rounded;

    final String bType = backendType ?? request['backendType'] ?? '';
    if (bType == 'APPOINTMENT_CANCELLED' || bType == 'ROAD_REQUEST_CANCELLED') {
      title = 'Request Cancelled!';
      accentColor = Colors.red;
      headerIcon = Icons.cancel_rounded;
    } else if (bType == 'APPOINTMENT_EXPIRED') {
      title = 'Appointment Expired!';
      accentColor = Colors.orange;
      headerIcon = Icons.hourglass_disabled_rounded;
    } else if (bType == 'PAYMENT_SUCCESS') {
      title = 'Payment Received!';
      accentColor = Colors.green;
      headerIcon = Icons.payments_rounded;
    }

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: userimage.isNotEmpty
                      ? NetworkImage(userimage)
                      : null,
                  child: userimage.isEmpty
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            color: accentColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(headerIcon, size: 12, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'Service Notification',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        userName,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      if (distance.isNotEmpty)
                        Text(
                          distance,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      Text(
                        location,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _removeOverlay,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'View',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    navigatorKey.currentState?.overlay?.insert(_overlayEntry!);
    Future.delayed(const Duration(seconds: 5), _removeOverlay);
  }

  // --- MAPPING HELPERS ---

  Map<String, dynamic> _mapRoadRequest(Map<String, dynamic> data) {
    return {
      'type': 'road',
      'requestId': data['requestId'] ?? data['requestid'],
      'id': data['userid']?.toString() ??
          data['requestId']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'userName': data['username'] ?? 'Unknown User',
      'location': data['userlocname'] ?? 'Location not provided',
      'time': TimeAgo.format(data['created_at']),
      'issue': 'Emergency Roadside Assistance',
      'price': data['price'] != null ? 'Rs. ${data['price']}' : 'Rs. --',
      'distance': data['distance'] != null ? '${data['distance']} km away' : '',
      'userimage': data['userimage'] ?? '',
      'lat': data['lat'],
      'lon': data['lon'],
      'isRead': false,
      'backendType': data['type']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _mapAppointmentRequest(Map<String, dynamic> data) {
    final rawUser = data['user'];
    final Map<String, dynamic> user =
        (rawUser is Map) ? Map<String, dynamic>.from(rawUser) : {};

    final String username = data['username'] ??
        data['userName'] ??
        user['username'] ??
        user['phonenumber'] ??
        data['userphonenumber'] ??
        'Appointment User';
    final String userImg =
        data['userimage'] ?? user['userimgurl'] ?? user['image'] ?? '';

    final rawDate = data['appointmentDate']?.toString() ?? '--';
    final rawTime = data['appointmentTime']?.toString() ?? '--';
    final scheduled = '$rawDate | $rawTime';

    final dynamic rawIsRead = data['isRead'] ?? data['isread'] ?? data['read'];
    final bool isRead = rawIsRead is bool
        ? rawIsRead
        : (rawIsRead?.toString().toLowerCase() == 'true');

    final String notificationId = (data['notificationid'] ??
            data['notificationId'] ??
            data['id'] ??
            data['appointmentid'] ??
            data['appointmentId'] ??
            DateTime.now().millisecondsSinceEpoch.toString())
        .toString();

    return {
      'type': 'appointment',
      'id': notificationId,
      'notificationId': notificationId,
      'appointmentId':
          (data['appointmentid'] ?? data['appointmentId'] ?? '').toString(),
      'userName': username,
      'userimage': userImg,
      'location': data['useraddress'] ?? data['address'] ?? 'Address not provided',
      'time': TimeAgo.format(data['created_at']),
      'issue': data['problemDescription'] ??
          data['problem'] ??
          'Service appointment request',
      'price': 'Rs. --',
      'distance': '',
      'scheduledTime': scheduled,
      'serviceType': data['serviceType'] ?? data['servicetype'] ?? 'General Service',
      'status': data['status']?.toString() ?? 'PENDING',
      'isRead': isRead,
      'created_at': data['created_at'] ?? '',
      'backendType': data['type']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _mapStatusNotification(
    Map<String, dynamic> data,
    String socketType,
  ) {
    final backendType = socketType == 'expired'
        ? 'APPOINTMENT_EXPIRED'
        : 'APPOINTMENT_CANCELLED';

    return {
      'type': 'appointment',
      'userName': data['title'] ??
          (socketType == 'expired'
              ? 'Appointment Expired'
              : 'Appointment Cancelled'),
      'location': data['message'] ??
          (socketType == 'expired'
              ? 'This appointment was accepted by another mechanic'
              : 'User cancelled the request'),
      'userimage': data['image'] ?? '',
      'time': TimeAgo.format(data['createdAt']),
      'issue': data['message'] ?? 'Reason not provided',
      'isRead': false,
      'backendType': data['type']?.toString() ?? backendType,
      'created_at': data['createdAt'] ?? '',
    };
  }
}
