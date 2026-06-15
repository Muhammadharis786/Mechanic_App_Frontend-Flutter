import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

import '../main.dart';
import '../screens/authentication/user_session.dart';
import '../screens/mechanic/mechanic_request_alert_screen.dart';

/// Uber-style emergency request alerts for mechanics:
/// loud alarm, vibration, and full-screen accept/reject UI.
class EmergencyAlertService {
  EmergencyAlertService._();

  static final EmergencyAlertService instance = EmergencyAlertService._();

  static const String roadRequestType = 'ROAD_REQUEST';

  bool _alertOpen = false;
  String? _currentRequestId;
  Timer? _vibrationTimer;

  bool get isAlertOpen => _alertOpen;

  static bool isMechanicSession() {
    final role = UserSession().userType?.toUpperCase();
    return role == 'MECHANIC';
  }

  static bool isRoadRequestPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString().toUpperCase();
    if (type == roadRequestType) return true;

    final requestId = _readRequestId(data);
    final hasLocation = data.containsKey('userLatitude') ||
        data.containsKey('userLat') ||
        data.containsKey('latitude');
    final hasNotes = data.containsKey('userNotes') || data.containsKey('notes');

    return requestId != null && (hasLocation || hasNotes);
  }

  static Map<String, dynamic> normalizeRoadRequest(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    final requestId = _readRequestId(map);

    return {
      ...map,
      'type': map['type'] ?? roadRequestType,
      if (requestId != null) 'requestId': requestId,
      'userNotes': map['userNotes'] ?? map['notes'] ?? '',
      'username': map['username'] ?? map['userName'] ?? 'Customer',
      'locationName': map['locationName'] ?? map['userlocname'] ?? '',
      'serviceType': map['serviceType'] ?? map['servicetype'] ?? 'Service',
      'requestStatus': map['requestStatus'] ?? map['status'] ?? 'PENDING',
    };
  }

  static String? _readRequestId(Map<String, dynamic> data) {
    final value = data['requestId'] ??
        data['requestid'] ??
        data['serviceRequestId'] ??
        data['servicerequestid'];
    if (value == null) return null;
    final id = value.toString();
    return id.isEmpty ? null : id;
  }

  Future<void> openRoadRequestAlert(Map<String, dynamic> rawData) async {
    if (!isMechanicSession()) {
      debugPrint('Emergency alert skipped: not a mechanic session.');
      return;
    }

    final data = normalizeRoadRequest(rawData);
    final requestId = _readRequestId(data);
    if (requestId == null) {
      debugPrint('Emergency alert skipped: request id missing.');
      return;
    }

    if (_alertOpen && _currentRequestId == requestId) return;

    await startEffects();

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('Emergency alert waiting: navigator not ready.');
      return;
    }

    _alertOpen = true;
    _currentRequestId = requestId;

    await navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MechanicRequestAlertScreen(requestData: data),
      ),
    );

    _alertOpen = false;
    _currentRequestId = null;
    await stopEffects();
  }

  Future<void> startEffects() async {
    if (kIsWeb) return;

    try {
      await FlutterRingtonePlayer().playAlarm(asAlarm: true, looping: true);
    } catch (e) {
      debugPrint('Emergency alarm error: $e');
    }

    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(
          pattern: [0, 400, 200, 400, 200, 600],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      }
    });

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      await Vibration.vibrate(
        pattern: [0, 500, 150, 500, 150, 800],
        intensities: [0, 255, 0, 255, 0, 255],
      );
    }
  }

  Future<void> stopEffects() async {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    if (kIsWeb) return;

    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('Stop emergency alarm error: $e');
    }

    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('Stop vibration error: $e');
    }
  }
}
