import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/active_service_request_tracking.dart';
import '../../services/mechanic_notification_controller.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../authentication/user_session.dart';
import 'mechanic_dashboard.dart';

class MechanicUserMap extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const MechanicUserMap({
    Key? key,
    required this.requestData,
  }) : super(key: key);

  @override
  State<MechanicUserMap> createState() => _MechanicUserMapState();
}

class _MechanicUserMapState extends State<MechanicUserMap>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  
  // Locations
  LatLng? _userLocation;
  LatLng? _mechanicCurrentPos;
  LatLng? _mechanicTargetPos;
  
  // Tracking
  StreamSubscription<Position>? _positionSub;
  late final Ticker _animTicker;
  
  // Polylines
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];
  String _currentDistance = '--';
  String _currentEta = '--';
  DateTime? _lastRouteFetchAt;
  LatLng? _lastRouteOrigin;
  StompClient? _mapClient;
  bool _isClosingForCancellation = false;
  
  // State
  bool _isLoading = true;
  final Color _primary = const Color(0xFFFB3300);
  final String _googleApiKey = "AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU";

  @override
  void initState() {
    super.initState();
    _parseInitialData();
    _currentDistance = widget.requestData['distance']?.toString() ?? 
                       (widget.requestData['distanceKm'] != null ? '${widget.requestData['distanceKm']} km' : '--');
    _currentEta = widget.requestData['eta']?.toString() ?? '--';
    _startLiveTracking();
    _subscribeToBackendUpdates();
    _animTicker = createTicker(_onTick);
    
    // Add a global fallback listener just in case backend routes the cancellation to the global mechanic topic
    MechanicNotificationController().addListener(_onGlobalFallbackNotification);
  }

  void _onGlobalFallbackNotification(Map<String, dynamic> data, String type) {
    if (data['type'] == 'ROAD_REQUEST_CANCELLED' || data['backendType'] == 'ROAD_REQUEST_CANCELLED') {
      final incomingReqId = data['requestId']?.toString() ?? data['requestid']?.toString();
      final myReqId = widget.requestData['requestId']?.toString() ?? widget.requestData['requestid']?.toString();
      
      if (incomingReqId != null && myReqId != null && incomingReqId == myReqId) {
        _goToDashboardAfterCancellation();
      }
    }
  }

  void _goToDashboardAfterCancellation() {
    if (_isClosingForCancellation) return;
    _isClosingForCancellation = true;
    ActiveServiceRequestTracking.clear();
    _positionSub?.cancel();
    _mapClient?.deactivate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Customer has cancelled the request!'),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
      (route) => false,
    );
  }

  void _parseInitialData() {
    try {
      final double uLat = _toDouble(
        widget.requestData['userLatitude'] ?? widget.requestData['userLat'],
      );
      final double uLng = _toDouble(
        widget.requestData['userLongitude'] ?? widget.requestData['userLng'],
      );
      _userLocation = LatLng(uLat, uLng);
    } catch (e) {
      debugPrint('Error parsing user location: $e');
    }
  }

  void _startLiveTracking() async {
    bool permission = await _checkPermission();
    if (!permission) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Get initial position
    try {
      debugPrint('📍 Fetching initial mechanic position...');
      Position pos = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      ).catchError((e) {
        debugPrint('Geolocator error: $e');
        return Position(
          latitude: 24.8607,
          longitude: 67.0011,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      });
      
      _mechanicCurrentPos = LatLng(pos.latitude, pos.longitude);
      _mechanicTargetPos = LatLng(pos.latitude, pos.longitude);
      
      if (mounted) {
        debugPrint('✅ Initial position found: ${_mechanicCurrentPos!.latitude}, ${_mechanicCurrentPos!.longitude}');
        setState(() => _isLoading = false);
        _fetchRoute(force: true);
      }
    } catch (e) {
      debugPrint('❌ Initial position error: $e');
      if (mounted) setState(() => _isLoading = false);
    }

    // Start stream
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position pos) {
      if (!mounted) return;
      
      final newPos = LatLng(pos.latitude, pos.longitude);
      _mechanicTargetPos = newPos;
      
      if (!_animTicker.isTicking) {
        _animTicker.start();
      }
      
      _fetchRoute();
    });
  }

  void _onTick(Duration elapsed) {
    if (_mechanicTargetPos == null || _mechanicCurrentPos == null) return;

    final target = _mechanicTargetPos!;
    final current = _mechanicCurrentPos!;

    final latDiff = target.latitude - current.latitude;
    final lngDiff = target.longitude - current.longitude;

    if (latDiff.abs() > 0.000001 || lngDiff.abs() > 0.000001) {
      const double speed = 0.05;
      _mechanicCurrentPos = LatLng(
        current.latitude + (latDiff * speed),
        current.longitude + (lngDiff * speed),
      );
      
      _shortenRoute();
      setState(() {});
    } else {
      _animTicker.stop();
    }
  }

  Future<void> _fetchRoute({bool force = false}) async {
    if (_mechanicTargetPos == null || _userLocation == null) return;

    final now = DateTime.now();
    final movedEnough = _lastRouteOrigin == null ||
        _distanceMeters(_lastRouteOrigin!, _mechanicTargetPos!) >= 30;
    final timeEnough = _lastRouteFetchAt == null ||
        now.difference(_lastRouteFetchAt!).inSeconds >= 10;

    if (!force && !movedEnough && !timeEnough) return;

    _lastRouteFetchAt = now;
    _lastRouteOrigin = _mechanicTargetPos;

    try {
      PolylinePoints polylinePoints = PolylinePoints(apiKey: _googleApiKey);
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(_mechanicTargetPos!.latitude, _mechanicTargetPos!.longitude),
          destination: PointLatLng(_userLocation!.latitude, _userLocation!.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (mounted && result.points.isNotEmpty) {
        _routePoints = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
        _updatePolyline();
      }
    } catch (e) {
      debugPrint('Route fetch error: $e');
    }
  }

  void _shortenRoute() {
    if (_routePoints.isEmpty || _mechanicCurrentPos == null) return;

    // Remove points from the start if we've passed them
    int indexToRemove = -1;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      if (_distanceMeters(_mechanicCurrentPos!, _routePoints[i]) < 15) {
        indexToRemove = i;
      }
    }

    if (indexToRemove != -1) {
      _routePoints.removeRange(0, indexToRemove + 1);
      _updatePolyline();
    }
  }

  void _updatePolyline() {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_mechanicCurrentPos!, ..._routePoints],
          color: _primary,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        )
      };
    });
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const double earthRadius = 6371000;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthRadius * 2 * math.asin(math.sqrt(h));
  }

  Future<bool> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '0') ?? 0;
  }

  @override
  void dispose() {
    MechanicNotificationController().removeListener(_onGlobalFallbackNotification);
    _animTicker.dispose();
    _positionSub?.cancel();
    _mapClient?.deactivate();
    _mapController?.dispose();
    super.dispose();
  }

  void _subscribeToBackendUpdates() {
    final requestId = widget.requestData['requestId'];
    if (requestId == null) return;

    _mapClient?.deactivate();
    _mapClient = StompClient(
      config: StompConfig(
        url: 'wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket',
        stompConnectHeaders: UserSession().getAuthHeader(),
        webSocketConnectHeaders: UserSession().getAuthHeader(),
        onConnect: (frame) {
          // Listen for status changes (like Cancellation)
          _mapClient?.subscribe(
            destination: '/topic/request/$requestId',
            callback: (message) {
              if (message.body == null || !mounted) return;
              try {
                final data = jsonDecode(message.body!);
                if (data is Map && (data['type'] == 'ROAD_REQUEST_CANCELLED' || data['backendType'] == 'ROAD_REQUEST_CANCELLED')) {
                  _goToDashboardAfterCancellation();
                }
              } catch (_) {}
            },
          );

          // Listen for Live Location updates from Backend
          _mapClient?.subscribe(
            destination: '/topic/request/$requestId/live-location',
            callback: (message) {
              if (message.body == null || !mounted) return;
              try {
                final data = jsonDecode(message.body!);
                if (data is Map) {
                  setState(() {
                    if (data.containsKey('distance')) {
                      _currentDistance = data['distance'].toString();
                    }
                    if (data.containsKey('eta')) {
                      _currentEta = data['eta'].toString();
                    }
                  });
                }
              } catch (_) {}
            },
          );
        },
        onStompError: (frame) => debugPrint('Mechanic Map STOMP error: ${frame.body}'),
        onWebSocketError: (error) => debugPrint('Mechanic Map socket error: $error'),
      ),
    );
    _mapClient?.activate();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = widget.requestData;
    final String customerName = (data['username'] ?? 'Customer').toString();
    final String customerImg = (data['userimage'] ?? data['userimgurl'] ?? '').toString();
    final String locationName = (data['userlocationname'] ??
            data['locationName'] ??
            data['location'] ??
            'Customer Location')
        .toString();
    final String serviceType = (data['serviceType'] ?? data['mechanicType'] ?? 'General').toString();
    final String userNotes = (data['userNotes'] ?? 'No special notes').toString();
    final String customerPhone =
        (data['userPhoneNumber'] ?? data['userphonenumber'] ?? data['phone'] ?? '')
            .toString();

    return Scaffold(
      body: Stack(
        children: [
          _isLoading || _userLocation == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: (c) => _mapController = c,
                  initialCameraPosition: CameraPosition(
                    target: _mechanicCurrentPos ?? _userLocation!,
                    zoom: 15,
                  ),
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  markers: {
                    if (_mechanicCurrentPos != null)
                      Marker(
                        markerId: const MarkerId('mechanic'),
                        position: _mechanicCurrentPos!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                        infoWindow: const InfoWindow(title: 'You'),
                      ),
                    Marker(
                      markerId: const MarkerId('user'),
                      position: _userLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                      infoWindow: const InfoWindow(title: 'Customer'),
                    ),
                  },
                  polylines: _polylines,
                ),

          // Top Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'EN ROUTE',
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[100], 
                          shape: BoxShape.circle,
                          image: customerImg.isNotEmpty 
                            ? DecorationImage(image: NetworkImage(customerImg), fit: BoxFit.cover)
                            : null,
                        ),
                        child: customerImg.isEmpty ? Icon(Icons.person, color: _primary) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              '$serviceType request',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Text(
                              locationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      if (customerPhone.isNotEmpty)
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => launchUrl(Uri.parse('tel:$customerPhone')),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.phone_rounded, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _trackingMetric(Icons.route_rounded, 'Distance', _currentDistance)),
                      const SizedBox(width: 10),
                      Expanded(child: _trackingMetric(Icons.schedule_rounded, 'ETA', _currentEta)),
                    ],
                  ),
                  if (userNotes != 'No special notes') ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Notes: $userNotes',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ActiveServiceRequestTracking.clear();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'I HAVE ARRIVED',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackingMetric(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade600)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
