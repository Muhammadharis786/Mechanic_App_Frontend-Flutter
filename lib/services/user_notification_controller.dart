import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart'; // To access navigatorKey
import '../screens/authentication/user_session.dart';
import '../screens/user/user_notification_screen.dart';
import 'user_websocket_service.dart';
import 'active_service_request_tracking.dart';

class UserNotificationController {
  // Singleton
  static final UserNotificationController _instance =
      UserNotificationController._internal();
  factory UserNotificationController() => _instance;
  UserNotificationController._internal();

  UserWebSocketService? _userWebSocket;
  OverlayEntry? _overlayEntry;

  // Callbacks for live UI updates
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback callback) {
    _listeners.add(callback);
  }

  void removeListener(VoidCallback callback) {
    _listeners.remove(callback);
  }

  void init() {
    if (_userWebSocket != null) return; // Already initialized

    final int? userId = UserSession().userId;
    if (userId == null) {
      debugPrint("❌ UserNotificationController: User ID is null");
      return;
    }

    _userWebSocket = UserWebSocketService(
      onNotificationReceived: (data, type) {
        if (type == 'request_expired' || type == 'request_cancelled') {
          ActiveServiceRequestTracking.clear();
        }
        // 1. Show Global Overlay
        showNotificationOverlay(data, type);

        // 2. Notify Listeners
        for (var listener in _listeners) {
          listener();
        }
      },
    );

    _userWebSocket!.connect(userId);
    debugPrint("✅ UserNotificationController: WebSocket Connected for ID $userId");
  }

  void dispose() {
    _userWebSocket?.disconnect();
    _userWebSocket = null;
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void showNotificationOverlay(Map<String, dynamic> data, String type) {
    _removeOverlay();

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final String title = switch (type) {
      'accepted' => '✅ Appointment Accepted!',
      'on_the_way' => '🚗 Mechanic On The Way!',
      'arrived' => '📍 Mechanic Arrived!',
      'in_progress' => '🔧 Work Started!',
      'work_completed' => '✅ Work Completed!',
      'send_charges' => '💰 Bill Ready',
      'rejected' => '❌ Appointment Rejected',
      'request_expired' => '⏳ Request Expired',
      'request_cancelled' => '❌ Request Cancelled',
      _ => '🔔 Appointment Update',
    };
    final String message = data['message']?.toString() ?? '';
    final String image = data['image']?.toString() ?? '';
    final Color primaryColor = const Color(0xFFFB3300);

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _removeOverlay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Row(
                children: [
                   CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: image.isNotEmpty && image.startsWith('http')
                        ? NetworkImage(image)
                        : null,
                    child: image.isEmpty
                        ? Icon(Icons.notifications_rounded,
                            color: primaryColor, size: 22)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: GoogleFonts.getFont('Bricolage Grotesque',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            )),
                        if (message.isNotEmpty)
                          Text(message,
                              style: GoogleFonts.getFont('Bricolage Grotesque',
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _removeOverlay();
                      navigatorKey.currentState?.push(
                        MaterialPageRoute(builder: (_) => const UserNotificationScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('View',
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    navigatorKey.currentState?.overlay?.insert(_overlayEntry!);
    Future.delayed(const Duration(seconds: 5), _removeOverlay);
  }
}
