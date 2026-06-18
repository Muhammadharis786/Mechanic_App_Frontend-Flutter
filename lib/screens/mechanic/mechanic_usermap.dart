import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/app_back_button.dart';
import '../../services/active_service_request_tracking.dart';
import '../../services/mechanic_live_location_service.dart';
import '../../services/mechanic_notification_controller.dart';
import '../../utils/distance_formatter.dart';
import '../../utils/map_marker_icon.dart';
import '../../utils/smooth_route_tracker.dart';
import '../../widgets/service_charges_price_badge.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../authentication/user_session.dart';
import 'mechanic_dashboard.dart';

const String _mechanicMapStyle = '''
[
  {"featureType":"all","elementType":"labels.text.fill","stylers":[{"color":"#444444"}]},
  {"featureType":"landscape","elementType":"all","stylers":[{"color":"#f2f2f2"}]},
  {"featureType":"poi","elementType":"all","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"all","stylers":[{"saturation":-100},{"lightness":45}]},
  {"featureType":"road.highway","elementType":"all","stylers":[{"visibility":"simplified"}]},
  {"featureType":"road.arterial","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","elementType":"all","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"all","stylers":[{"color":"#c9d9e8"},{"visibility":"on"}]}
]
''';

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
  final SmoothRouteTracker _routeTracker = SmoothRouteTracker();
  
  // Polylines
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];
  String _currentDistance = '--';
  String _currentEta = '--';
  DateTime? _lastRouteFetchAt;
  LatLng? _lastRouteOrigin;
  DateTime? _lastCameraFollowAt;
  double _mechanicBearing = 0;
  BitmapDescriptor? _mechanicTrackingIcon;
  BitmapDescriptor? _userTrackingIcon;
  StompClient? _mapClient;
  bool _isClosingForCancellation = false;
  bool _isCheckingArrival = false;
  bool _hasArrived = false;
  bool _isSendingPrice = false;
  bool _hasSentPrice = false;
  bool _workStarted = false;
  bool _workCompleted = false;
  bool _paymentPending = false;
  bool _isCompletingWork = false;
  bool _isConfirmingCashPayment = false;
  bool _showJobCompletedBanner = false;
  double? _approvedFinalPrice;
  double? _approvedArrivalPrice;
  final TextEditingController _priceController = TextEditingController();
  
  // State
  bool _isLocatingMechanic = false;
  final Color _primary = const Color(0xFFFB3300);
  final String _googleApiKey = "AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU";

  @override
  void initState() {
    super.initState();
    _parseInitialData();
    _isLocatingMechanic = _userLocation == null;
    _currentDistance = _initialDistanceLabel();
    _restoreWorkflowStateFrom(_localTrackingSnapshot());
    _currentEta = widget.requestData['eta']?.toString() ?? '--';
    _animTicker = createTicker(_onTick);
    _jobDoneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fetchRoute(force: true);
    if (!_hasArrived) {
      _startLiveTracking();
      final requestId = widget.requestData['requestId']?.toString() ??
          widget.requestData['requestid']?.toString();
      MechanicLiveLocationService.instance.start(requestId: requestId);
    }
    _subscribeToBackendUpdates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWorkflowFromServer();
    });
    _loadTrackingMarkerIcons();

    // Add a global fallback listener just in case backend routes the cancellation to the global mechanic topic
    MechanicNotificationController().addListener(_onGlobalFallbackNotification);
  }

  late final AnimationController _jobDoneController;

  bool _statusMeansWaitingForUser(String status) {
    if (_statusMeansWaitingForPayment(status)) return false;
    return status.contains('WAITING') ||
        status == 'WAITING_USER_APPROVAL' ||
        status == 'PRICE_SENT' ||
        status == 'FINAL_PRICE_SENT' ||
        status == 'PENDING_APPROVAL' ||
        status == 'AWAITING_USER_APPROVAL' ||
        status == 'WAITING_FOR_USER_APPROVAL';
  }

  bool _statusMeansArrived(String status) {
    return status == 'ARRIVED' ||
        _statusMeansWaitingForUser(status) ||
        _statusMeansWaitingForPayment(status) ||
        status == 'APPROVED_PAYMENT_REQUEST' ||
        status == 'WORK_STARTED' ||
        status == 'IN_PROGRESS' ||
        status == 'COMPLETED';
  }

  bool _statusMeansApprovedPayment(String status) {
    return status == 'APPROVED_PAYMENT_REQUEST' ||
        status == 'APPROVED_PRICE_REQUEST' ||
        status == 'WORK_STARTED';
  }

  bool _statusMeansPaymentPending(String status) {
    return status == 'PAYMENT_PENDING';
  }

  bool _statusMeansWaitingForPayment(String status) {
    return status == 'WAITING_FOR_PAYMENT' ||
        status == 'WORK_COMPLETED' ||
        status == 'WAITING_FOR_PAYMENT_REQUEST';
  }

  String _normalizeStatus(Map<String, dynamic> data) {
    return (data['requestStatus'] ?? data['status'])
            ?.toString()
            .toUpperCase() ??
        '';
  }

  int _workflowRank(String status) {
    if (_statusMeansPaymentPending(status)) return 7;
    if (_statusMeansWaitingForPayment(status)) return 6;
    if (_statusMeansApprovedPayment(status)) return 5;
    if (_statusMeansWaitingForUser(status)) return 4;
    if (status == 'ARRIVED') return 3;
    if (status == 'ACCEPTED') return 2;
    return 1;
  }

  double? _extractFinalPrice(Map<String, dynamic> data) {
    for (final key in ['finalPrice', 'inspectionPrice', 'inspectionprice']) {
      final value = _toDouble(data[key]);
      if (value != null) return value;
    }
    final fromAmount = _toDouble(data['amount']);
    if (fromAmount != null) return fromAmount;
    return null;
  }

  double? _extractArrivalPrice(Map<String, dynamic> data) {
    return _toDouble(data['arrivalPrice']) ??
        _toDouble(data['arrivalprice']) ??
        _toDouble(data['visiting charges']) ??
        _toDouble(data['visitingCharges']);
  }

  double? _pickBestPrice(double? local, double? server) {
    if (local != null && local > 0) return local;
    if (server != null && server > 0) return server;
    return null;
  }

  int _defaultArrivalPrice() {
    final type = (widget.requestData['serviceType'] ??
            widget.requestData['mechanicType'] ??
            '')
        .toString()
        .toLowerCase();
    if (type.contains('bike')) return 300;
    if (type.contains('car')) return 500;
    if (type.contains('puncher')) return 100;
    return 300;
  }

  bool _sameRequestId(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aId = a['requestId']?.toString() ?? a['requestid']?.toString();
    final bId = b['requestId']?.toString() ?? b['requestid']?.toString();
    return aId != null && aId == bId;
  }

  Map<String, dynamic> _localTrackingSnapshot() {
    final stored = ActiveServiceRequestTracking.current.value;
    if (stored != null && _sameRequestId(stored, widget.requestData)) {
      return {...widget.requestData, ...stored};
    }
    return Map<String, dynamic>.from(widget.requestData);
  }

  Map<String, dynamic> _mergeWorkflowData(
    Map<String, dynamic> local,
    Map<String, dynamic> server,
  ) {
    final localStatus = _normalizeStatus(local);
    final serverStatus = _normalizeStatus(server);
    final base = _workflowRank(serverStatus) >= _workflowRank(localStatus)
        ? {...local, ...server}
        : {...server, ...local};

    if (local['workStarted'] == true || server['workStarted'] == true) {
      base['workStarted'] = true;
    }
    if (local['workCompleted'] == true || server['workCompleted'] == true) {
      base['workCompleted'] = true;
      base['workStarted'] = true;
    }
    if (_statusMeansPaymentPending(localStatus) ||
        _statusMeansPaymentPending(serverStatus)) {
      base['paymentPending'] = true;
      base['workCompleted'] = true;
      base['workStarted'] = true;
      base['requestStatus'] = 'PAYMENT_PENDING';
    } else if (_statusMeansWaitingForPayment(localStatus) ||
        _statusMeansWaitingForPayment(serverStatus)) {
      base['workCompleted'] = true;
      base['workStarted'] = true;
      base['requestStatus'] = 'WORK_COMPLETED';
      base['paymentPending'] = false;
    } else if (_statusMeansApprovedPayment(localStatus) ||
        _statusMeansApprovedPayment(serverStatus)) {
      base['workStarted'] = true;
      base['requestStatus'] = _workflowRank(serverStatus) >=
              _workflowRank(localStatus)
          ? serverStatus
          : localStatus;
    }

    final price = _pickBestPrice(
      _extractFinalPrice(local),
      _extractFinalPrice(server),
    );
    if (price != null) {
      base['finalPrice'] = price;
    }

    final arrival = _pickBestPrice(
      _extractArrivalPrice(local),
      _extractArrivalPrice(server),
    );
    if (arrival != null) {
      base['arrivalPrice'] = arrival;
    }

    return base;
  }

  void _applyApprovedCharges(Map<String, dynamic> data) {
    _approvedFinalPrice = _extractFinalPrice(data);
    _approvedArrivalPrice =
        _extractArrivalPrice(data) ?? _defaultArrivalPrice().toDouble();
    _workStarted = true;
    _hasSentPrice = false;
    _hasArrived = true;
  }

  void _restoreWorkflowStateFrom(Map<String, dynamic> data) {
    final status = _normalizeStatus(data);
    final backendType =
        (data['type'] ?? data['backendType'])?.toString().toUpperCase() ?? '';

    _paymentPending = data['paymentPending'] == true ||
        _statusMeansPaymentPending(status) ||
        backendType == 'PAYMENT_PENDING';

    _workCompleted = data['workCompleted'] == true ||
        _statusMeansWaitingForPayment(status) ||
        backendType == 'WORK_COMPLETED';

    _workStarted = data['workStarted'] == true ||
        _paymentPending ||
        _workCompleted ||
        _statusMeansApprovedPayment(status) ||
        backendType == 'USER_APPROVED';

    if (_workStarted) {
      _approvedFinalPrice =
          _extractFinalPrice(data) ?? _approvedFinalPrice;
      _approvedArrivalPrice = _extractArrivalPrice(data) ??
          _approvedArrivalPrice ??
          _defaultArrivalPrice().toDouble();
      _hasSentPrice = false;
      _hasArrived = true;
      return;
    }

    _hasSentPrice = data['hasSentPrice'] == true ||
        data['hasSentCharges'] == true ||
        _statusMeansWaitingForUser(status);
    _hasArrived = data['hasArrived'] == true ||
        _statusMeansArrived(status) ||
        _hasSentPrice;
  }

  String _workflowStatusLabel() {
    if (_paymentPending) return 'PAYMENT_PENDING';
    if (_workCompleted) return 'WORK_COMPLETED';
    if (_workStarted) return 'APPROVED_PAYMENT_REQUEST';
    if (_hasSentPrice) return 'WAITING_FOR_USER_APPROVAL';
    if (_hasArrived) return 'ARRIVED';
    return (widget.requestData['requestStatus'] ?? 'ACCEPTED').toString();
  }

  void _persistWorkflowState({double? finalPrice}) {
    final snapshot = _localTrackingSnapshot();
    final requestId = snapshot['requestId']?.toString() ??
        snapshot['requestid']?.toString();
    final savedPrice = _approvedFinalPrice ?? finalPrice;
    ActiveServiceRequestTracking.save({
      ...snapshot,
      if (requestId != null) 'requestId': requestId,
      'requestStatus': _workflowStatusLabel(),
      'hasArrived': _hasArrived,
      'hasSentPrice': _hasSentPrice,
      'workStarted': _workStarted,
      'workCompleted': _workCompleted,
      'paymentPending': _paymentPending,
      if (savedPrice != null) 'finalPrice': savedPrice,
      if (_approvedArrivalPrice != null) 'arrivalPrice': _approvedArrivalPrice,
    });
  }

  Future<void> _onWorkCompleted() async {
    if (_isCompletingWork || _workCompleted) return;

    final requestId = widget.requestData['requestId']?.toString() ??
        widget.requestData['requestid']?.toString();
    if (requestId == null || requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request id missing')),
      );
      return;
    }

    setState(() => _isCompletingWork = true);

    try {
      final response = await http.get(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/work-completed/$requestId',
        ),
        headers: UserSession().getAuthHeader(),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final preservedFinal =
            _approvedFinalPrice ?? _extractFinalPrice(_localTrackingSnapshot());
        final preservedArrival = _approvedArrivalPrice ??
            _extractArrivalPrice(_localTrackingSnapshot());
        setState(() {
          _workCompleted = true;
          _workStarted = true;
          _hasArrived = true;
          if (preservedFinal != null) _approvedFinalPrice = preservedFinal;
          if (preservedArrival != null) _approvedArrivalPrice = preservedArrival;
        });
        _persistWorkflowState(finalPrice: _approvedFinalPrice);

        String message = 'Work marked complete. Waiting for customer payment.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      String message = 'Could not mark work as completed';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isCompletingWork = false);
      }
    }
  }

  Future<void> _refreshWorkflowFromServer() async {
    final requestId = widget.requestData['requestId']?.toString() ??
        widget.requestData['requestid']?.toString();
    if (requestId == null || requestId.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/tracking/$requestId',
        ),
        headers: UserSession().getAuthHeader(),
      );

      if (!mounted || response.statusCode != 200 || response.body.isEmpty) {
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final serverData = Map<String, dynamic>.from(decoded);
      final status = _normalizeStatus(serverData);

      if (status == 'CANCELLED' ||
          status == 'REJECTED' ||
          status == 'EXPIRED' ||
          status == 'COMPLETED') {
        return;
      }

      final merged = _mergeWorkflowData(_localTrackingSnapshot(), serverData);
      setState(() => _restoreWorkflowStateFrom(merged));
      _persistWorkflowState(finalPrice: _approvedFinalPrice);
    } catch (e) {
      debugPrint('Mechanic workflow refresh failed: $e');
    }
  }

  void _applyRequestTopicUpdate(Map<String, dynamic> data) {
    final backendType =
        (data['type'] ?? data['backendType'])?.toString().toUpperCase() ?? '';
    final status = _normalizeStatus(data);

    if (backendType == 'ROAD_REQUEST_CANCELLED') {
      _goToDashboardAfterCancellation();
      return;
    }

    if (backendType == 'FINAL_PRICE_SENT' || backendType == 'PRICE_SENT') {
      if (!mounted) return;
      setState(() {
        _hasArrived = true;
        _hasSentPrice = true;
        _workStarted = false;
      });
      _persistWorkflowState(finalPrice: _extractFinalPrice(data));
      return;
    }

    if (backendType == 'USER_APPROVED' ||
        _statusMeansApprovedPayment(
          data['status']?.toString().toUpperCase() ?? '',
        )) {
      if (!mounted) return;
      setState(() => _applyApprovedCharges(data));
      _persistWorkflowState(finalPrice: _approvedFinalPrice);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['message']?.toString() ??
                'Customer approved your charges. Start work now.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    if (backendType == 'PAYMENT_DONE' || status == 'COMPLETED') {
      if (!mounted) return;
      ActiveServiceRequestTracking.clear();
      setState(() {
        _showJobCompletedBanner = true;
        _paymentPending = false;
        _workCompleted = false;
        _workStarted = false;
      });
      _jobDoneController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['message']?.toString() ?? 'Payment received successfully',
          ),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
          (route) => false,
        );
      });
      return;
    }

    if (backendType == 'PAYMENT_PENDING' ||
        _statusMeansPaymentPending(status)) {
      if (!mounted) return;
      final snapshot = _localTrackingSnapshot();
      setState(() {
        _paymentPending = true;
        _workCompleted = true;
        _workStarted = true;
        _hasArrived = true;
        _approvedFinalPrice =
            _extractFinalPrice(data) ?? _extractFinalPrice(snapshot) ?? _approvedFinalPrice;
        _approvedArrivalPrice =
            _extractArrivalPrice(data) ?? _extractArrivalPrice(snapshot) ?? _approvedArrivalPrice;
      });
      _persistWorkflowState(finalPrice: _approvedFinalPrice);
      return;
    }

    if (backendType == 'WORK_COMPLETED' ||
        _statusMeansWaitingForPayment(
          _normalizeStatus(data),
        )) {
      if (!mounted) return;
      final snapshot = _localTrackingSnapshot();
      setState(() {
        _workCompleted = true;
        _paymentPending = false;
        _workStarted = true;
        _hasArrived = true;
        _approvedFinalPrice =
            _extractFinalPrice(data) ??
            _extractFinalPrice(snapshot) ??
            _approvedFinalPrice;
        _approvedArrivalPrice =
            _extractArrivalPrice(data) ??
            _extractArrivalPrice(snapshot) ??
            _approvedArrivalPrice;
      });
      _persistWorkflowState(finalPrice: _approvedFinalPrice);
      return;
    }

    _restoreWorkflowStateFrom(data);
    if (mounted) {
      setState(() {});
      _persistWorkflowState(finalPrice: _extractFinalPrice(data));
    }
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
      final uLat = _toCoordinate(
        widget.requestData['userLatitude'] ?? widget.requestData['userLat'],
      );
      final uLng = _toCoordinate(
        widget.requestData['userLongitude'] ?? widget.requestData['userLng'],
      );
      if (uLat != null && uLng != null) {
        _userLocation = LatLng(uLat, uLng);
      }

      final mechanicLatValue =
          widget.requestData['mechanicLatitude'] ??
          widget.requestData['latitude'] ??
          widget.requestData['lat'];
      final mechanicLngValue =
          widget.requestData['mechanicLongitude'] ??
          widget.requestData['longitude'] ??
          widget.requestData['lng'];

      if (mechanicLatValue != null && mechanicLngValue != null) {
        final mLat = _toCoordinate(mechanicLatValue);
        final mLng = _toCoordinate(mechanicLngValue);
        if (mLat == null || mLng == null) return;
        final mechanicPos = LatLng(mLat, mLng);
        _mechanicCurrentPos = mechanicPos;
        _mechanicTargetPos = mechanicPos;
      }
    } catch (e) {
      debugPrint('Error parsing user location: $e');
    }
  }

  void _startLiveTracking() async {
    bool permission = await _checkPermission();
    if (!permission) {
      if (mounted) setState(() => _isLocatingMechanic = false);
      return;
    }

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null && mounted) {
      _mechanicCurrentPos = LatLng(lastKnown.latitude, lastKnown.longitude);
      _mechanicTargetPos = _mechanicCurrentPos;
      setState(() => _isLocatingMechanic = false);
      _fetchRoute(force: true);
    } else if (mounted) {
      setState(() => _isLocatingMechanic = false);
    }

    // Get initial position
    try {
      debugPrint('📍 Fetching initial mechanic position...');
      Position pos = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 4),
      ).catchError((e) {
        debugPrint('Geolocator error: $e');
        if (lastKnown != null) return lastKnown;
        throw e;
      });
      
      _mechanicCurrentPos = LatLng(pos.latitude, pos.longitude);
      _mechanicTargetPos = LatLng(pos.latitude, pos.longitude);
      _routeTracker.reset(_mechanicCurrentPos!);
      
      if (mounted) {
        debugPrint('✅ Initial position found: ${_mechanicCurrentPos!.latitude}, ${_mechanicCurrentPos!.longitude}');
        setState(() => _isLocatingMechanic = false);
        _fetchRoute(force: true);
      }
    } catch (e) {
      debugPrint('❌ Initial position error: $e');
      if (mounted) setState(() => _isLocatingMechanic = false);
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
      final heading = pos.heading.isFinite && pos.heading >= 0
          ? pos.heading
          : null;
      _routeTracker.pushGps(newPos, heading: heading);
      
      if (!_animTicker.isTicking) {
        _animTicker.start();
      }
      
      _fetchRoute();
    });
  }

  void _onTick(Duration elapsed) {
    final frame = _routeTracker.tick(elapsed);
    if (frame == null || _mechanicTargetPos == null) return;

    _mechanicCurrentPos = frame.position;
    _mechanicBearing = frame.bearing;

    if (frame.polylinePoints.length >= 2) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: frame.polylinePoints,
          color: _primary,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    }

    _followMechanic(_mechanicCurrentPos!, _mechanicBearing);
    setState(() {});
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
        _routeTracker.setRoute(
          _routePoints,
          anchor: _routeTracker.displayPosition ?? _mechanicCurrentPos,
        );
        final frame = _routeTracker.tick(Duration.zero);
        if (frame != null && mounted) {
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: frame.polylinePoints,
                color: _primary,
                width: 6,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            };
          });
        }
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

  Future<void> _loadTrackingMarkerIcons() async {
    try {
      final mechanicIcon = await mapMarkerFromAsset(
        'assets/images/navigation.png',
        size: 48,
      );
      final userIcon = await _createUserRingMarker();
      
      if (!mounted) return;
      setState(() {
        _mechanicTrackingIcon = mechanicIcon;
        _userTrackingIcon = userIcon;
      });
    } catch (e) {
      debugPrint('Error loading marker icons: $e');
      if (mounted) {
        setState(() {
          _mechanicTrackingIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        });
      }
    }
  }

  void _followMechanic(LatLng position, double bearing) {
    final now = DateTime.now();
    if (_lastCameraFollowAt != null &&
        now.difference(_lastCameraFollowAt!).inMilliseconds < 280) {
      return;
    }
    _lastCameraFollowAt = now;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 17,
          tilt: 45,
          bearing: bearing,
        ),
      ),
    );
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }


  Future<BitmapDescriptor> _createUserRingMarker() async {
    const size = 54.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final ringPaint = Paint()
      ..color = const Color(0xFF666666)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final fillPaint = Paint()..color = Colors.white;

    canvas.drawCircle(const Offset(size / 2, size / 2), 10, fillPaint);
    canvas.drawCircle(const Offset(size / 2, size / 2), 10, ringPaint);

    final image = await recorder.endRecording().toImage(
          size.toInt(),
          size.toInt(),
        );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List markerBytes = bytes!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(markerBytes);
  }

  Future<bool> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  double? _toCoordinate(dynamic val) {
    if (val is num) return val.toDouble();
    if (val == null) return null;
    return double.tryParse(val.toString());
  }

  double? _toDouble(dynamic val) {
    if (val is num) {
      final parsed = val.toDouble();
      return parsed > 0 ? parsed : null;
    }
    if (val == null) return null;
    final parsed = double.tryParse(val.toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  String _initialDistanceLabel() {
    if (widget.requestData['distance'] != null) {
      return DistanceFormatter.formatKilometers(widget.requestData['distance']);
    }
    final distanceKm = widget.requestData['distanceKm'];
    if (distanceKm is num) {
      return DistanceFormatter.formatKilometers(distanceKm);
    }
    return '--';
  }

  Future<void> _onHaveArrived() async {
    if (_isCheckingArrival) return;

    final requestId = widget.requestData['requestId']?.toString() ??
        widget.requestData['requestid']?.toString();
    if (requestId == null || requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request id missing')),
      );
      return;
    }

    setState(() => _isCheckingArrival = true);

    try {
      final coords =
          await MechanicLiveLocationService.instance.currentCoordinates();

      final arrivalUri = Uri.parse(
        'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/isarrived/$requestId',
      ).replace(
        queryParameters: coords != null
            ? {
                'lat': coords.lat.toString(),
                'lng': coords.lng.toString(),
              }
            : null,
      );

      // Best-effort websocket update; arrival API uses lat/lng query params.
      if (coords != null) {
        MechanicLiveLocationService.instance.publishLocationNow(
          requestId: requestId,
        );
      }

      final response = await http
          .get(
            arrivalUri,
            headers: UserSession().getAuthHeader(),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        await MechanicLiveLocationService.instance.stop();
        _positionSub?.cancel();
        _animTicker.stop();

        if (!mounted) return;
        setState(() {
          _hasArrived = true;
          _isCheckingArrival = false;
        });
        _persistWorkflowState();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have arrived at the customer location'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      String message = response.body.trim();
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          message = decoded['message'].toString();
        }
      } catch (_) {}

      final formattedDistance =
          DistanceFormatter.parseMetersFromNotArrivedBody(message);
      if (formattedDistance != null) {
        message = 'You are $formattedDistance away from the customer';
      } else if (message.isEmpty) {
        message = 'You have not reached the customer yet';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arrival check timed out. Check internet and try again.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not verify arrival: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingArrival = false);
      }
    }
  }

  void _showSendChargesDialog() {
    _priceController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, color: _primary, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Set Inspection Charges',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the charges for this service',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Rs.',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade300,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final price = double.tryParse(_priceController.text.trim());
                    if (price == null || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _sendFinalPrice(price);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Send Charges',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendFinalPrice(double price) async {
    if (_isSendingPrice) return;

    final requestId = widget.requestData['requestId']?.toString() ??
        widget.requestData['requestid']?.toString();
    if (requestId == null || requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request ID missing')),
      );
      return;
    }

    setState(() => _isSendingPrice = true);

    try {
      final response = await http.post(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/send-final-price',
        ),
        headers: {
          'Content-Type': 'application/json',
          ...UserSession().getAuthHeader(),
        },
        body: jsonEncode({
          'requestId': int.tryParse(requestId) ?? requestId,
          'finalPrice': price,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _hasArrived = true;
          _hasSentPrice = true;
          _isSendingPrice = false;
        });
        _persistWorkflowState(finalPrice: price);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charges sent to customer'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _isSendingPrice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingPrice = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _leaveMap() {
    _persistWorkflowState(finalPrice: _approvedFinalPrice);
    Navigator.pop(context);
  }

  Future<void> _confirmCashPaymentReceived() async {
    if (_isConfirmingCashPayment) return;
    final requestId = widget.requestData['requestId']?.toString() ??
        widget.requestData['requestid']?.toString();
    if (requestId == null || requestId.isEmpty) return;

    setState(() => _isConfirmingCashPayment = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/completed/$requestId',
        ),
        headers: UserSession().getAuthHeader(),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ActiveServiceRequestTracking.clear();
        setState(() {
          _showJobCompletedBanner = true;
        });
        _jobDoneController.forward(from: 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment confirmed. Job completed.'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1100));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Confirm failed: ${response.body}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isConfirmingCashPayment = false);
    }
  }

  @override
  void dispose() {
    if (_hasArrived || _hasSentPrice || _workStarted) {
      _persistWorkflowState(finalPrice: _approvedFinalPrice);
    }
    _priceController.dispose();
    MechanicNotificationController().removeListener(_onGlobalFallbackNotification);
    _animTicker.dispose();
    _jobDoneController.dispose();
    _positionSub?.cancel();
    _mapClient?.deactivate();
    _mapController?.dispose();
    super.dispose();
  }

  void _subscribeToBackendUpdates() {
    final requestId = widget.requestData['requestId'] ??
        widget.requestData['requestid'];
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
                if (data is Map) {
                  _applyRequestTopicUpdate(
                    Map<String, dynamic>.from(data),
                  );
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
                      _currentDistance =
                          DistanceFormatter.formatKilometers(data['distance']);
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
          _userLocation == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  onMapCreated: (c) {
                    _mapController = c;
                    c.setMapStyle(_mechanicMapStyle);
                  },
                  initialCameraPosition: CameraPosition(
                    target: _userLocation!,
                    zoom: 14,
                  ),
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  markers: {
                    if (_mechanicCurrentPos != null)
                      Marker(
                        markerId: const MarkerId('mechanic'),
                        position: _mechanicCurrentPos!,
                        icon: _mechanicTrackingIcon ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueBlue,
                            ),
                        anchor: const Offset(0.5, 0.5),
                        flat: true,
                        rotation: _mechanicBearing,
                        infoWindow: const InfoWindow(title: 'You'),
                      ),
                    Marker(
                      markerId: const MarkerId('user'),
                      position: _userLocation!,
                      icon: _userTrackingIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueOrange,
                          ),
                      anchor: const Offset(0.5, 0.5),
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
                    onTap: _leaveMap,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFFFB3300),
                        size: 20,
                      ),
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

          if (_showJobCompletedBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _jobDoneController,
                  curve: Curves.easeOutBack,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green.shade700,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Job completed',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Payment confirmed successfully',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isLocatingMechanic)
            Positioned(
              top: MediaQuery.of(context).padding.top + 72,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Locating you...',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                            if (_paymentPending) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Confirm cash payment',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ] else if (_workCompleted) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Waiting for payment',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ] else if (_workStarted) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Customer approved charges',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_workStarted)
                        ServiceChargesPriceBadge(
                          inspectionPrice: _approvedFinalPrice ??
                              _extractFinalPrice(_localTrackingSnapshot()) ??
                              _extractFinalPrice(widget.requestData),
                          visitingPrice: _approvedArrivalPrice ??
                              _extractArrivalPrice(_localTrackingSnapshot()) ??
                              _extractArrivalPrice(widget.requestData) ??
                              _defaultArrivalPrice().toDouble(),
                          primaryColor: _primary,
                        )
                      else if (customerPhone.isNotEmpty)
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
                  if (_paymentPending)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isConfirmingCashPayment
                            ? null
                            : _confirmCashPaymentReceived,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isConfirmingCashPayment
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'CONFIRM PAYMENT RECEIVED',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    )
                  else if (_workCompleted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade50,
                            Colors.indigo.shade50,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            color: Colors.blue.shade700,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Waiting for Payment',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Customer will pay the approved charges',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_workStarted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isCompletingWork ? null : _onWorkCompleted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isCompletingWork
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.build_circle_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'WORK COMPLETED',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    )
                  else if (_hasSentPrice)
                    // Waiting for Approval state
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade50,
                            Colors.orange.shade50,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.amber.shade700,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Waiting for Approval',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Customer is reviewing your charges',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.amber.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _hasArrived
                            ? (_isSendingPrice ? null : _showSendChargesDialog)
                            : (_isCheckingArrival ? null : _onHaveArrived),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _hasArrived ? _primary : _primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSendingPrice
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasArrived
                                        ? Icons.send_rounded
                                        : Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _hasArrived
                                        ? 'SEND CHARGES'
                                        : 'I HAVE ARRIVED',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
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
