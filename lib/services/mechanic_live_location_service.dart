import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../screens/authentication/user_session.dart';
import 'active_service_request_tracking.dart';

class MechanicLiveLocationService {
  MechanicLiveLocationService._();

  static final MechanicLiveLocationService instance =
      MechanicLiveLocationService._();

  static const String _socketUrl =
      'wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket';

  StompClient? _client;
  StreamSubscription<Position>? _positionSub;
  
  Timer? _heartbeatTimer;
  double? _testLat;
  double? _testLng;
  int _testStep = 0;
  double? _lastLat;
  double? _lastLng;
  String? _activeRequestId;
  bool _isConnected = false;
  bool _isStarting = false;

  String? _resolveRequestId(String? requestId) {
    if (requestId != null && requestId.trim().isNotEmpty) {
      return requestId.trim();
    }
    final tracking = ActiveServiceRequestTracking.current.value;
    if (tracking == null) return null;
    return tracking['requestId']?.toString() ??
        tracking['requestid']?.toString();
  }

  void _setActiveRequestId(String? requestId) {
    final resolved = _resolveRequestId(requestId);
    if (resolved == null || resolved.isEmpty) return;
    _activeRequestId = resolved;
  }

  Future<void> start({String? requestId}) async {
    _setActiveRequestId(requestId);

    if (_positionSub != null) {
      _startHeartbeat();
      if (_isConnected && _lastLat != null && _lastLng != null) {
        _sendLocation(
          latitude: _lastLat!,
          longitude: _lastLng!,
          bearing: 0.0,
          speed: 0.0,
        );
      } else {
        _connectSocket();
      }
   
      return;
    }

    if (_isStarting) return;

    final mechanicId = UserSession().userId;
    if (mechanicId == null) {
      return;
    }

    _isStarting = true;
    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) return;

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      final current = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      _lastLat = current.latitude;
      _lastLng = current.longitude;

      _connectSocket();
      _startHeartbeat();

      _positionSub = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (position) {
          _lastLat = position.latitude;
          _lastLng = position.longitude;
          _sendPosition(position);
        },
        onError: (error) {},
      );
    } finally {
      _isStarting = false;
    }
  }

  Future<({double lat, double lng})?> currentCoordinates({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return null;

    try {
      const settings = LocationSettings(accuracy: LocationAccuracy.high);
      final current = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(timeout);
      _lastLat = current.latitude;
      _lastLng = current.longitude;
      return (lat: current.latitude, lng: current.longitude);
    } catch (e) {}

    if (_lastLat != null && _lastLng != null) {
      return (lat: _lastLat!, lng: _lastLng!);
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      _lastLat = lastKnown.latitude;
      _lastLng = lastKnown.longitude;
      return (lat: lastKnown.latitude, lng: lastKnown.longitude);
    }

    return null;
  }

  /// Publishes the mechanic's current GPS to Redis (via backend) before arrival check.
  Future<bool> publishLocationNow({required String requestId}) async {
    _setActiveRequestId(requestId);

    final coords = await currentCoordinates(timeout: const Duration(seconds: 4));
    if (coords == null) return false;

    if (_positionSub == null) {
      await start(requestId: requestId);
    }

    if (!_isConnected || _client == null) {
      _connectSocket();
    }

    for (var attempt = 0; attempt < 12; attempt++) {
      if (_isConnected) {
        _sendLocation(
          latitude: coords.lat,
          longitude: coords.lng,
          bearing: 0.0,
          speed: 0.0,
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    return false;
  }

  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _testLat = null;
    _testLng = null;
    _testStep = 0;
    _lastLat = null;
    _lastLng = null;
    _activeRequestId = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _client?.deactivate();
    _client = null;
    _isConnected = false;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_activeRequestId == null ||
          _lastLat == null ||
          _lastLng == null ||
          !_isConnected) {
        return;
      }
      _sendLocation(
        latitude: _lastLat!,
        longitude: _lastLng!,
        bearing: 0.0,
        speed: 0.0,
      );
    });
  }

  void _connectSocket() {
    if (_client != null) return;

    _client = StompClient(
      config: StompConfig(
        url: _socketUrl,
        stompConnectHeaders: UserSession().getAuthHeader(),
        webSocketConnectHeaders: UserSession().getAuthHeader(),
        onConnect: (_) {
          _isConnected = true;
          debugPrint('✅ Mechanic live tracking STOMP connected!');

          if (_lastLat != null && _lastLng != null) {
            debugPrint('📤 Sending initial position after connect: $_lastLat, $_lastLng');
            _sendLocation(
              latitude: _lastLat!,
              longitude: _lastLng!,
              bearing: 0.0,
              speed: 0.0,
            );
          }
        },
        onDisconnect: (_) {
          _isConnected = false;
          debugPrint('🛑 Live tracking stopped! Mechanic live tracking disconnected');
        },
        onStompError: (frame) {
          _isConnected = false;
        },
        onWebSocketError: (error) {
          _isConnected = false;
        },
      ),
    );
    _client?.activate();
  }

  void _sendPosition(Position position) {
    _sendLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      bearing: position.heading.isFinite ? position.heading : 0.0,
      speed: position.speed.isFinite ? position.speed : 0.0,
    );
  }

  void _sendLocation({
    required double latitude,
    required double longitude,
    required double bearing,
    required double speed,
  }) {
    final mechanicId = UserSession().userId;
    if (mechanicId == null) {
      return;
    }
    if (_activeRequestId == null || _activeRequestId!.isEmpty) {
      debugPrint('! Send skipped: active requestId missing');
      return;
    }
    if (!_isConnected) {
      return;
    }
    if (_client == null) {
      return;
    }

    final requestIdRaw = _activeRequestId!;
    final requestIdParsed = int.tryParse(requestIdRaw);

    final payload = <String, dynamic>{
      'mechanicId': mechanicId,
      'requestId': requestIdParsed ?? requestIdRaw,
      'latitude': latitude,
      'longitude': longitude,
      'bearing': bearing,
      'speed': speed,
    };

    try {
      _client!.send(
        destination: '/app/mechanic/live-location',
        body: jsonEncode(payload),
      );
    } catch (e) {
      _isConnected = false;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final allowed = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    return allowed;
  }
}
