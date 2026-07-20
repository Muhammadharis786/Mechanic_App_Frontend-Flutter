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
  bool _isDisposed = false; // ✅ Track if disposed
  bool _isOnline = false; // ✅ Track if mechanic is online (to control heartbeat)

  // Callbacks for live UI updates (e.g. on Dashboard)
  final List<Function(Map<String, dynamic> data, String type)> _listeners = [];

  void addListener(Function(Map<String, dynamic> data, String type) callback) {
    _listeners.add(callback);
  }

  void removeListener(
    Function(Map<String, dynamic> data, String type) callback,
  ) {
    _listeners.remove(callback);
  }

  /// Ensure WebSocket is connected (call after disconnect or app resume)
  void ensureConnected() {
    if (_webSocketService != null && _mechanicId != null) {
      debugPrint("🔄 Ensuring WebSocket connection for mechanic ID: $_mechanicId");
      _webSocketService!.ensureConnected(_mechanicId!);
    } else {
      debugPrint("⚠️ Cannot ensure connection - WebSocket or mechanicId is null");
    }
  }

  void init() {
    if (_webSocketService != null) {
      debugPrint("⚠️ MechanicNotificationController: Already initialized");
      return; // Already initialized
    }

    final int? mechId = UserSession().userId;
    if (mechId == null) {
      debugPrint("❌ MechanicNotificationController: User ID is null");
      return;
    }

    debugPrint("🚀 MechanicNotificationController: Initializing for mechanic ID: $mechId");
    _mechanicId = mechId;
    _isDisposed = false; // ✅ Reset disposed flag
    // DON'T set _isOnline here - let caller control it via startHeartbeatIfOnline()

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

        // Detect new Service Request format.
        if ((hasRoadRequestLocation && hasRoadRequestId) ||
            mapData.containsKey('userNotes') ||
            mapData.containsKey('notes')) {
          mapData['requestId'] =
              mapData['requestId'] ?? resolvedRoadRequestId;
          EmergencyAlertService.instance.openRoadRequestAlert(mapData);
          
          // Optionally still notify listeners so dashboard updates its list
          // But do NOT show the standard overlay
          final request = _mapRoadRequest(mapData); // Fallback mapping for lists
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

        // 1. Show Global Overlay
        showNotificationOverlay(request, type, backendType: backendType);

        // 2. Notify Listeners (like Dashboard)
        for (var listener in _listeners) {
          listener(request, type);
        }
      },
      onConnected: () {
        debugPrint("🔗 WebSocket connected");
        // ✅ Start heartbeat ONLY if mechanic is online
        if (_isOnline) {
          debugPrint("🔗 WebSocket connected & mechanic is ONLINE - starting heartbeat");
          _startHeartbeat();
        }
      },
      onDisconnected: () {
        debugPrint("🔌 WebSocket disconnected");
        // ✅ Stop heartbeat if it was running
        _stopHeartbeat();
      },
    );

    _webSocketService!.connect(mechId);
    debugPrint(
      "✅ MechanicNotificationController: WebSocket Connected for ID $mechId",
    );
  }

  /// Start sending heartbeat every 10 seconds
  void _startHeartbeat() {
    // ✅ CRITICAL: Check session userType
    final sessionUserType = UserSession().userType?.toUpperCase();
    if (sessionUserType != 'MECHANIC') {
      debugPrint("🚫 Cannot start heartbeat - session userType is $sessionUserType (not MECHANIC)");
      return;
    }
    
    // ✅ CRITICAL: Don't start if disposed
    if (_isDisposed) {
      debugPrint("🚫 Cannot start heartbeat - controller is disposed");
      return;
    }
    
    _stopHeartbeat(); // Clear any existing timer
    
    if (_mechanicId == null) return;
    
    // ✅ Mark as online
    _isOnline = true;
    
    debugPrint("💓 Starting heartbeat for mechanic ID: $_mechanicId");
    
    // ✅ Timer runs continuously, even when app is backgrounded
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      // ✅ CRITICAL: Check session on every tick
      final currentUserType = UserSession().userType?.toUpperCase();
      if (currentUserType != 'MECHANIC') {
        debugPrint("⏹️ Heartbeat stopping - session switched to $currentUserType");
        timer.cancel();
        _heartbeatTimer = null;
        return;
      }
      
      // ✅ CRITICAL: Check if mechanic is still online
      if (!_isOnline) {
        debugPrint("⏹️ Heartbeat stopping - mechanic went offline");
        timer.cancel();
        _heartbeatTimer = null;
        return;
      }
      
      // Check if still valid
      if (_isDisposed || _mechanicId == null || _webSocketService == null) {
        debugPrint("⏹️ Heartbeat stopping - disposed=$_isDisposed, mechId=$_mechanicId");
        timer.cancel();
        _heartbeatTimer = null;
        return;
      }
      
      _sendHeartbeat();
    });
    
    // ✅ Send initial heartbeat ONLY if WebSocket is already connected
    // If not connected yet, onConnected callback will handle it
    if (_webSocketService != null && (_webSocketService!.client?.connected ?? false)) {
      debugPrint("💓 WebSocket already connected - sending initial heartbeat");
      _sendHeartbeat();
    } else {
      debugPrint("⏳ WebSocket connecting... heartbeat will start after connection");
    }
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    if (_heartbeatTimer != null) {
      debugPrint("💔 Stopping heartbeat for mechanic ID: $_mechanicId");
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  /// Send heartbeat message to backend
  void _sendHeartbeat() {
    // ✅ Check session first
    final sessionUserType = UserSession().userType?.toUpperCase();
    if (sessionUserType != 'MECHANIC') {
      debugPrint("⚠️ Cannot send heartbeat - session is $sessionUserType (not MECHANIC)");
      _stopHeartbeat(); // Stop the timer
      return;
    }
    
    // Triple check before sending
    if (_isDisposed || _webSocketService == null || _mechanicId == null) {
      debugPrint("⚠️ Cannot send heartbeat - disposed=$_isDisposed, mechId=$_mechanicId");
      return;
    }
    
    try {
      _webSocketService!.sendMessage(
        destination: '/app/heartbeat',
        body: jsonEncode({'mechanicId': _mechanicId}),
      );
      debugPrint("💚 Heartbeat sent for mechanic ID: $_mechanicId");
    } catch (e) {
      debugPrint("⚠️ Heartbeat send skipped - WebSocket not ready yet: $e");
      // Don't stop timer - it will retry on next tick when WebSocket is connected
    }
  }

  /// Call this when app comes to foreground - ensure WebSocket is connected
  /// BUT only if mechanic is online
  void resumeHeartbeat() {
    debugPrint("▶️ App foregrounded - checking if should reconnect");
    
    // ✅ ONLY reconnect if mechanic is online
    if (!_isOnline) {
      debugPrint("⏸️ Mechanic is OFFLINE - skipping WebSocket reconnect");
      return;
    }
    
    debugPrint("🔄 Mechanic is ONLINE - ensuring WebSocket connection");
    
    // Reconnect WebSocket if disconnected
    if (_webSocketService != null && _mechanicId != null) {
      _webSocketService!.ensureConnected(_mechanicId!);
    }
  }

  /// Start heartbeat when mechanic goes ONLINE
  void startHeartbeatIfOnline() {
    debugPrint("💓 startHeartbeatIfOnline called");
    // ✅ Set flag FIRST so onConnected callback knows to start heartbeat
    _isOnline = true;
    // If WebSocket already connected, start heartbeat immediately
    // If not connected yet, onConnected callback will start it
    _startHeartbeat();
  }

  /// Stop heartbeat only - WebSocket stays connected to receive requests
  void stopHeartbeatOnly() {
    debugPrint("⏸️ stopHeartbeatOnly - Stopping heartbeat timer only");
    _stopHeartbeat();
  }
  
  /// Stop heartbeat AND disconnect WebSocket (for offline mode)
  void disconnectCompletely() {
    debugPrint("🔴 disconnectCompletely - Stopping heartbeat & disconnecting WebSocket");
    _isOnline = false; // ✅ Mark as offline FIRST (stops timer on next tick)
    _stopHeartbeat();
    _webSocketService?.disconnect();
    // Don't nullify _webSocketService so we can reconnect later
  }

  void dispose() {
    debugPrint("🧹 MechanicNotificationController: Disposing");
    _isDisposed = true; // ✅ Mark as disposed FIRST
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
    if (_webSocketService == null) {
      debugPrint("❌ MechanicNotificationController: Cannot subscribe, WebSocket is null");
      return null;
    }

    return _webSocketService!.subscribe(
      destination: destination,
      onMessage: (body) {
        if (body == null) return;
        try {
          final data = jsonDecode(body);
          if (data is Map) {
            onMessage(Map<String, dynamic>.from(data));
          }
        } catch (e) {
          debugPrint('Error decoding topic message: $e');
        }
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

    // Determine title and styling
    String title = type == 'appointment'
        ? 'New Appointment Request!'
        : 'New Daily Request!';
    Color accentColor = const Color(0xFFFB3300); // Default primary
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
                  onTap: () {
                    _removeOverlay();
                    // Optional: Navigate to notification center using navigatorKey
                    // navigatorKey.currentState?.pushNamed('/mechanic-notifications');
                  },
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
      'id':
          data['userid']?.toString() ??
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
    final Map<String, dynamic> user = (rawUser is Map)
        ? Map<String, dynamic>.from(rawUser)
        : {};

    final String username =
        data['username'] ??
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

    final String notificationId =
        (data['notificationid'] ??
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
      'appointmentId': (data['appointmentid'] ?? data['appointmentId'] ?? '')
          .toString(),
      'userName': username,
      'userimage': userImg,
      'location':
          data['useraddress'] ?? data['address'] ?? 'Address not provided',
      'time': TimeAgo.format(data['created_at']),
      'issue':
          data['problemDescription'] ??
          data['problem'] ??
          'Service appointment request',
      'price': 'Rs. --',
      'distance': '',
      'scheduledTime': scheduled,
      'serviceType':
          data['serviceType'] ?? data['servicetype'] ?? 'General Service',
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
      'userName':
          data['title'] ??
          (socketType == 'expired'
              ? 'Appointment Expired'
              : 'Appointment Cancelled'),
      'location':
          data['message'] ??
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
