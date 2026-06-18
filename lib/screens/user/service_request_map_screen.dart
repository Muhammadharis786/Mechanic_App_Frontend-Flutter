import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/active_service_request_tracking.dart';
import '../authentication/user_session.dart';
import '../../utils/map_marker_icon.dart';
import '../../utils/smooth_route_tracker.dart';
import '../../widgets/service_charges_price_badge.dart';
import '../homescreen.dart';
import 'service_review_screen.dart';

const String _mapStyle = '''
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

const String _googleApiKey = 'AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU';

class ServiceRequestMapScreen extends StatefulWidget {
  final String serviceType;
  final String userNotes;
  final bool isFixedChargeAccepted;
  final String? selectedMechanicId;
  final Map<String, dynamic>? resumedTracking;

  const ServiceRequestMapScreen({
    super.key,
    required this.serviceType,
    required this.userNotes,
    required this.isFixedChargeAccepted,
    this.selectedMechanicId,
    this.resumedTracking,
  });

  @override
  State<ServiceRequestMapScreen> createState() => _ServiceRequestMapScreenState();
}

class _ServiceRequestMapScreenState extends State<ServiceRequestMapScreen>
    with TickerProviderStateMixin {
  
  static const Color _primary = Color(0xFFFB3300);

  GoogleMapController? _mapController;
  LatLng _markerPos = const LatLng(24.8607, 67.0011); 
  bool _isDragging = false;
  String? _locationLabel;
  bool _isLoading = false;

  // --- Nearby mechanics state ---
  bool _isWaiting = false; // true after request sent & nearby mechanics fetched
  bool _isAccepted = false;
  String? _activeRequestId;
  Map<String, dynamic>? _acceptedMechanic;
  LatLng? _acceptedMechanicPosition;
  String? _acceptedDistanceText;
  String? _acceptedEta;
  Set<Marker> _mechanicMarkers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _acceptedRoutePoints = [];
  StompClient? _trackingClient;
  StompClient? _requestClient;
  Timer? _acceptedLocationPollTimer;
  bool _requestSocketConnected = false;
  bool _liveLocationSubscribed = false;
  bool _userInitiatedCancel = false;
  bool _cancelExitHandled = false;
  bool _isPriceReceived = false;
  bool _isApprovingPayment = false;
  bool _paymentApproved = false;
  bool _workCompleted = false;
  bool _paymentPending = false;
  bool _cashHandoverMarked = false;
  bool _isPaying = false;
  double? _finalPrice;
  double? _arrivalPrice;
  DateTime? _lastRouteFetchAt;
  LatLng? _lastRouteOrigin;
  DateTime? _lastCameraFollowAt;
  double _acceptedBearing = 0;
  final SmoothRouteTracker _acceptedRouteTracker = SmoothRouteTracker();
  BitmapDescriptor? _mechanicTrackingIcon;
  BitmapDescriptor? _userTrackingIcon;

  // Animation support
  final Map<String, LatLng> _markerTargetPositions = {};
  final Map<String, LatLng> _markerCurrentPositions = {};
  final Map<String, String> _markerTitles = {}; // Track titles so we don't reload icons
  late final Ticker _markerTicker;

  late AnimationController _spinController;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<dynamic> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;
  Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });

    if (widget.resumedTracking != null) {
      _restoreRequestedLocation(widget.resumedTracking!);
      _restoreTrackingSync(widget.resumedTracking!);
    } else {
      _initializePosition();
    }
    
    ActiveServiceRequestTracking.current.addListener(_onGlobalTrackingChanged);

    // Initialize the smooth marker animation ticker
    _markerTicker = createTicker(_onMarkerTick);

    if (widget.resumedTracking != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final requestId = widget.resumedTracking!['requestId']?.toString();
        if (requestId != null && requestId.isNotEmpty) {
          _connectRequestStatus(requestId);
          _refreshResumedTracking(requestId);
        }
      });
    }

    _loadTrackingMarkerIcons();
  }

  void _onMarkerTick(Duration elapsed) {
    if (_isAccepted) {
      _tickAcceptedMechanic(elapsed);
      return;
    }

    if (_markerTargetPositions.isEmpty) return;

    bool needsUpdate = false;
    const double speed = 0.18;

    final newMarkers = Set<Marker>.from(_mechanicMarkers);
    
    _markerTargetPositions.forEach((id, target) {
      final current = _markerCurrentPositions[id] ?? target;
      
      // Calculate distance between current and target
      final latDiff = target.latitude - current.latitude;
      final lngDiff = target.longitude - current.longitude;
      
      if (latDiff.abs() > 0.000001 || lngDiff.abs() > 0.000001) {
        final bearing = _bearingBetween(current, target);
        // Linearly interpolate towards the target
        final newLat = current.latitude + (latDiff * speed);
        final newLng = current.longitude + (lngDiff * speed);
        final newPos = LatLng(newLat, newLng);
        
        _markerCurrentPositions[id] = newPos;
        if (_isAccepted && _acceptedMechanic?['mechanicId']?.toString() == id) {
          _acceptedMechanicPosition = newPos;
          _acceptedBearing = bearing;
          _shortenAcceptedRoute(newPos);
          _updateAcceptedPolyline(newPos);
          _followAcceptedMechanic(newPos, bearing);
        }
        
        // Update the marker in the set
        final markerId = MarkerId('mechanic_$id');
        newMarkers.removeWhere((m) => m.markerId == markerId);
        newMarkers.add(
          Marker(
            markerId: markerId,
            position: newPos,
            icon: _mechanicTrackingIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            anchor: const Offset(0.5, 0.5),
            flat: _isAccepted,
            rotation: _isAccepted ? bearing : 0,
            infoWindow: InfoWindow(title: _markerTitles[id] ?? 'Mechanic #$id'),
          ),
        );
        needsUpdate = true;
      }
    });

    if (needsUpdate) {
      setState(() {
        _mechanicMarkers = newMarkers;
      });
    } else {
      // If all caught up, stop ticker to save battery
      _markerTicker.stop();
    }
  }

  void _onGlobalTrackingChanged() {
    final active = ActiveServiceRequestTracking.current.value;
    if (active == null && mounted && !_cancelExitHandled) {
      debugPrint('MapScreen: Active tracking cleared globally, exiting...');
      _exitToUserHome(
        snackMessage: 'Request expired or was completed.',
        snackColor: Colors.orange,
      );
    }
  }

  void _tickAcceptedMechanic(Duration elapsed) {
    final mechanicId = _acceptedMechanic?['mechanicId']?.toString();
    if (mechanicId == null) return;

    final frame = _acceptedRouteTracker.tick(elapsed);
    if (frame == null) return;

    final newPos = frame.position;
    _acceptedMechanicPosition = newPos;
    _acceptedBearing = frame.bearing;
    _markerCurrentPositions[mechanicId] = newPos;

    if (frame.polylinePoints.length >= 2) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('accepted_route'),
          points: frame.polylinePoints,
          color: _primary,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    }

    _followAcceptedMechanic(newPos, _acceptedBearing);

    final markerId = MarkerId('mechanic_$mechanicId');
    _mechanicMarkers = {
      Marker(
        markerId: markerId,
        position: newPos,
        icon: _mechanicTrackingIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: _acceptedBearing,
        infoWindow: InfoWindow(
          title: _markerTitles[mechanicId] ??
              _acceptedMechanic?['mechanicName']?.toString() ??
              'Mechanic',
        ),
      ),
    };

    setState(() {});
  }

  void _initializePosition() {
    final savedLat = UserSession().latitude;
    final savedLng = UserSession().longitude;

    if (savedLat != null && savedLng != null) {
      _markerPos = LatLng(savedLat, savedLng);
    }
    _getUserLocation();
  }

  void _restoreRequestedLocation(Map<String, dynamic> tracking) {
    final userLat = _toDouble(
      tracking['userLat'] ??
          tracking['userLatitude'] ??
          tracking['latitude'],
    );
    final userLng = _toDouble(
      tracking['userLng'] ??
          tracking['userLongitude'] ??
          tracking['longitude'],
    );

    if (userLat != null && userLng != null) {
      _markerPos = LatLng(userLat, userLng);
    }

    final label = tracking['locationName'] ??
        tracking['userlocationname'] ??
        tracking['location'];
    if (label != null) {
      _locationLabel = label.toString();
    }
  }

  @override
  void dispose() {
    ActiveServiceRequestTracking.current.removeListener(_onGlobalTrackingChanged);
    _markerTicker.dispose();
    _spinController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _geocodeDebounce?.cancel();
    _acceptedLocationPollTimer?.cancel();
    _trackingClient?.deactivate();
    _requestClient?.deactivate();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final newPos = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _markerPos = newPos);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 14));
        _reverseGeocode(newPos);
      }
    } catch (_) {}
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$_googleApiKey';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final name = data['results'][0]['formatted_address'] as String;
          if (mounted) setState(() => _locationLabel = name);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$_googleApiKey&language=en';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _suggestions = data['predictions'] ?? [];
            _showSuggestions = _suggestions.isNotEmpty;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _selectSuggestion(dynamic prediction) async {
    final placeId = prediction['place_id'];
    final description = prediction['description'] as String;
    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_googleApiKey';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final loc = data['result']['geometry']['location'];
        final newPos = LatLng(loc['lat'], loc['lng']);
        setState(() {
          _markerPos = newPos;
          _locationLabel = description;
          _suggestions = [];
          _showSuggestions = false;
          _searchCtrl.text = description;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));
        _searchFocus.unfocus();
      }
    } catch (_) {}
  }

  String _mapServiceCategory(String category) {
    if (category.toLowerCase().contains("bike")) return "BIKE";
    if (category.toLowerCase().contains("car")) return "CAR";
    if (category.toLowerCase().contains("puncher")) return "PUNCHER";
    return "OTHER";
  }

  Future<void> _sendServiceRequest() async {
    if (_locationLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the location to resolve.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String mappedServiceType = _mapServiceCategory(widget.serviceType);
    final String userPhoneNumber = UserSession().email ?? "";

    final payload = {
      "serviceType": mappedServiceType,
      "userNotes": widget.userNotes,
      "isfixedchargeaccepted": widget.isFixedChargeAccepted,
      "userphonenumber": userPhoneNumber,
      "userLatitude": _markerPos.latitude,
      "userLongitude": _markerPos.longitude,
      "locationName": _locationLabel,
    };

    final String baseUrl = "https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request";
    final String url = (widget.selectedMechanicId != null) 
        ? "$baseUrl/create-for-mechanic/${widget.selectedMechanicId}"
        : "$baseUrl/create";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          ...UserSession().getAuthHeader(),
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _captureRequestId(response.body);
        if (_activeRequestId != null) {
          _saveActiveTracking();
          _connectRequestStatus(_activeRequestId!);
        }
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text('Service Request Sent Successfully!'), 
               backgroundColor: Colors.green.shade600
             ),
           );
           // Now fetch nearby mechanics
           await _fetchNearbyMechanics(mappedServiceType);
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Failed: ${response.body}')),
           );
        }
      }
    } catch(e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Request Error: $e')),
         );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _captureRequestId(String body) {
    try {
      final decoded = jsonDecode(body);
      final requestId = _findRequestId(decoded);
      _activeRequestId = requestId?.toString();
      debugPrint('Service request id captured: $_activeRequestId');
    } catch (e) {
      debugPrint('Request id parse error: $e');
    }
  }

  dynamic _findRequestId(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return _findRequestId(value.first);
    }

    if (value is Map) {
      final direct = value['requestId'] ?? value['requestid'];
      if (direct != null) return direct;

      final body = value['body'];
      if (body != null) return _findRequestId(body);

      final data = value['data'];
      if (data != null) return _findRequestId(data);
    }

    return null;
  }

  void _connectRequestStatus(String requestId) {
    _requestClient?.deactivate();
    _requestSocketConnected = false;
    _liveLocationSubscribed = false;
    _requestClient = StompClient(
      config: StompConfig(
        url:
            'wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket',
        stompConnectHeaders: UserSession().getAuthHeader(),
        webSocketConnectHeaders: UserSession().getAuthHeader(),
        onConnect: (_) {
          _requestSocketConnected = true;
          _requestClient?.subscribe(
            destination: '/topic/request/$requestId',
            callback: (frame) {
              if (frame.body == null || !mounted) return;
              try {
                final decoded = jsonDecode(frame.body!);
                if (decoded is! Map) return;
                _onRequestStatusUpdate(
                  Map<String, dynamic>.from(decoded),
                  requestId,
                );
              } catch (e) {
                debugPrint('Request status decode error: $e');
              }
            },
          );
          if (_isAccepted) {
            _subscribeAcceptedLiveLocation(requestId);
          }
        },
        onDisconnect: (_) {
          _requestSocketConnected = false;
          _liveLocationSubscribed = false;
        },
        onStompError: (frame) =>
            debugPrint('Request status STOMP error: ${frame.body}'),
        onWebSocketError: (error) {
          _requestSocketConnected = false;
          _liveLocationSubscribed = false;
          debugPrint('Request status socket error: $error');
        },
      ),
    );
    _requestClient?.activate();
  }

  void _onRequestStatusUpdate(Map<String, dynamic> data, String requestId) {
    final backendType =
        (data['type'] ?? data['backendType'])?.toString().toUpperCase() ?? '';
    final status = (data['status'] ?? data['requestStatus'])
            ?.toString()
            .toUpperCase() ??
        '';

    if (backendType == 'ROAD_REQUEST_CANCELLED' || status == 'EXPIRED') {
      if (status == 'EXPIRED') {
        _exitToUserHome(
          snackMessage: data['message']?.toString() ??
              'No mechanic was available. Please try again later.',
          snackColor: Colors.redAccent,
        );
      } else {
        _handleRequestCancelledBySocket(data);
      }
      return;
    }

    if (backendType == 'FINAL_PRICE_SENT') {
      final price = _toDouble(data['finalPrice']);
      if (price != null && mounted) {
        setState(() {
          _isPriceReceived = true;
          _finalPrice = price;
          _paymentApproved = false;
        });
      }
      return;
    }

    if (backendType == 'USER_APPROVED' ||
        status == 'APPROVED_PAYMENT_REQUEST' ||
        status == 'WORK_STARTED') {
      if (!mounted) return;
      setState(() => _applyApprovedPaymentPayload(data));
      _saveActiveTracking();
      return;
    }

    if (backendType == 'WORK_COMPLETED' ||
        _statusMeansWaitingForPayment(_normalizeTrackingStatus(data))) {
      if (!mounted) return;
      final local = ActiveServiceRequestTracking.current.value;
      final merged = local != null
          ? {...local, ...data}
          : Map<String, dynamic>.from(data);
      setState(() => _applyWorkCompletedPayload(merged));
      _saveActiveTracking();
      return;
    }

    if (backendType == 'PAYMENT_PENDING' || status == 'PAYMENT_PENDING') {
      if (!mounted) return;
      final local = ActiveServiceRequestTracking.current.value;
      final merged = local != null
          ? {...local, ...data}
          : Map<String, dynamic>.from(data);
      setState(() => _applyPaymentPendingPayload(merged));
      _saveActiveTracking();
      return;
    }

    if (backendType == 'PAYMENT_DONE' ||
        status == 'COMPLETED' ||
        _normalizeTrackingStatus(data) == 'COMPLETED') {
      if (!mounted) return;
      _navigateToServiceReview(
        requestId: data['requestId']?.toString() ?? requestId,
        snackMessage:
            data['message']?.toString() ?? 'Payment received successfully',
      );
      return;
    }

    if (!_handleAcceptedMechanic(data, requestId)) {
      debugPrint('Ignored request topic message: $data');
      return;
    }

    final mechanicName =
        (data['mechanicName'] ?? data['name'])?.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mechanicName == null
              ? 'Mechanic accepted your request'
              : '$mechanicName accepted your request',
        ),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  void _teardownRequestConnections() {
    _acceptedLocationPollTimer?.cancel();
    _acceptedLocationPollTimer = null;
    _requestClient?.deactivate();
    _trackingClient?.deactivate();
    _requestSocketConnected = false;
    _liveLocationSubscribed = false;
  }

  /// Review API uses ServiceType.EMERGENCY (not bike/car puncher category).
  String _reviewServiceType() => 'EMERGENCY';

  void _navigateToServiceReview({
    required String requestId,
    String? snackMessage,
  }) {
    if (_cancelExitHandled) return;
    _cancelExitHandled = true;

    final serviceId = requestId.isNotEmpty
        ? requestId
        : (_activeRequestId ?? '');
    final serviceType = _reviewServiceType();

    _teardownRequestConnections();
    ActiveServiceRequestTracking.clear();

    if (!mounted) return;

    if (snackMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMessage),
          backgroundColor: Colors.green,
        ),
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ServiceReviewScreen(
          serviceId: serviceId,
          serviceType: serviceType,
        ),
      ),
      (route) => false,
    );
  }

  void _goToUserDashboard({String? snackMessage, Color? snackColor}) {
    if (!mounted) return;

    if (snackMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMessage),
          backgroundColor: snackColor ?? Colors.orange,
        ),
      );
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _exitToUserHome({String? snackMessage, Color? snackColor}) {
    if (_cancelExitHandled) return;
    _cancelExitHandled = true;

    _teardownRequestConnections();
    ActiveServiceRequestTracking.clear();

    if (!mounted) return;

    setState(() {
      _isWaiting = false;
      _isAccepted = false;
      _acceptedMechanic = null;
      _acceptedMechanicPosition = null;
      _acceptedDistanceText = null;
      _acceptedEta = null;
      _mechanicMarkers = {};
      _polylines = {};
      _activeRequestId = null;
      _workCompleted = false;
      _paymentApproved = false;
      _isPriceReceived = false;
      _isLoading = false;
    });

    _goToUserDashboard(snackMessage: snackMessage, snackColor: snackColor);
  }

  void _handleRequestCancelledBySocket(Map<String, dynamic> data) {
    if (_cancelExitHandled) return;

    if (!_userInitiatedCancel) {
      final message = data['message']?.toString();
      _exitToUserHome(
        snackMessage:
            message?.isNotEmpty == true ? message! : 'Request cancelled',
      );
      return;
    }

    _teardownRequestConnections();
    ActiveServiceRequestTracking.clear();
  }

  Future<void> _cancelRequest() async {
    if (_activeRequestId == null) return;

    _userInitiatedCancel = true;
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/cancel/$_activeRequestId"),
        headers: {
          'Content-Type': 'application/json',
          ...UserSession().getAuthHeader(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _exitToUserHome(
          snackMessage: 'Request cancelled successfully',
        );
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Cancel failed: ${response.body}')),
           );
        }
      }
    } catch(e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Cancel error: $e')),
         );
      }
    } finally {
      _userInitiatedCancel = false;
      if (mounted && !_cancelExitHandled) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _normalizeTrackingStatus(Map<String, dynamic> data) {
    return (data['requestStatus'] ?? data['status'])
            ?.toString()
            .toUpperCase() ??
        '';
  }

  double? _pickPrice(Map<String, dynamic> data) {
    for (final key in ['finalPrice', 'inspectionPrice', 'inspectionprice']) {
      final value = _toDouble(data[key]);
      if (value != null && value > 0) return value;
    }
    return null;
  }

  double? _pickArrivalPrice(Map<String, dynamic> data) {
    final value = _toDouble(data['arrivalPrice']) ?? _toDouble(data['arrivalprice']);
    if (value != null && value > 0) return value;
    return null;
  }

  void _applyTrackingWorkflow(Map<String, dynamic> data) {
    final status = _normalizeTrackingStatus(data);
    final type =
        (data['type'] ?? data['backendType'])?.toString().toUpperCase() ?? '';

    if (_statusMeansPaymentPending(status) ||
        type == 'PAYMENT_PENDING' ||
        data['paymentPending'] == true) {
      _applyPaymentPendingPayload(data);
      _cashHandoverMarked = data['cashHandoverMarked'] == true;
      return;
    }

    if (_statusMeansWaitingForPayment(status) ||
        type == 'WORK_COMPLETED' ||
        data['workCompleted'] == true) {
      _applyWorkCompletedPayload(data);
      return;
    }

    if (status == 'APPROVED_PAYMENT_REQUEST' ||
        status == 'APPROVED_PRICE_REQUEST' ||
        status == 'WORK_STARTED' ||
        data['paymentApproved'] == true ||
        type == 'USER_APPROVED') {
      _applyApprovedPaymentPayload(data);
      return;
    }

    final price = _pickPrice(data);
    if (price != null) _finalPrice = price;
    if (!_paymentApproved && price != null) {
      _isPriceReceived = _statusMeansWaitingForUserApproval(status);
    }
  }

  void _restoreTrackingSync(Map<String, dynamic> tracking) {
    final requestId =
        tracking['requestId']?.toString() ?? tracking['requestid']?.toString();
    final userLat = _toDouble(tracking['userLat'] ?? tracking['userLatitude']);
    final userLng = _toDouble(tracking['userLng'] ?? tracking['userLongitude']);

    if (userLat != null && userLng != null) {
      _markerPos = LatLng(userLat, userLng);
    }

    if (requestId != null && requestId.isNotEmpty) {
      _activeRequestId = requestId;
    }

    final hasAcceptedMechanic =
        tracking['mechanicId'] != null ||
        tracking['mechanicLatitude'] != null ||
        tracking['latitude'] != null;

    if (hasAcceptedMechanic) {
      _handleAcceptedMechanic(tracking, requestId, updateState: false);
      _applyTrackingWorkflow(tracking);
      _cashHandoverMarked = tracking['cashHandoverMarked'] == true;
      _isWaiting = true;
    } else {
      _isWaiting = true;
      _isAccepted = false;
    }
  }

  Future<void> _refreshResumedTracking(String requestId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/tracking/$requestId',
        ),
        headers: UserSession().getAuthHeader(),
      );

      if (response.statusCode != 200 || response.body.isEmpty) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || !mounted) return;

      final data = Map<String, dynamic>.from(decoded);
      final local = ActiveServiceRequestTracking.current.value;
      final merged = local != null &&
              (local['requestId']?.toString() ??
                      local['requestid']?.toString()) ==
                  requestId
          ? {...local, ...data}
          : data;
      final status = _normalizeTrackingStatus(merged);
      if (status == 'CANCELLED' || status == 'REJECTED' || status == 'EXPIRED') {
        ActiveServiceRequestTracking.clear();
        _goToUserDashboard();
        return;
      }

      final hasAcceptedMechanic =
          merged['mechanicId'] != null || merged['mechanicLatitude'] != null;
      if (hasAcceptedMechanic) {
        _handleAcceptedMechanic(merged, requestId, updateState: false);
        if (!mounted) return;
        setState(() => _applyTrackingWorkflow(merged));
        _saveActiveTracking();
      }
    } catch (e) {
      debugPrint('Refresh resumed tracking failed: $e');
    }
  }

  bool _statusMeansWaitingForUserApproval(String status) {
    if (_statusMeansWaitingForPayment(status)) return false;
    return status.contains('WAITING') ||
        status == 'WAITING_USER_APPROVAL' ||
        status == 'WAITING_FOR_USER_APPROVAL';
  }

  bool _statusMeansWaitingForPayment(String status) {
    return status == 'WAITING_FOR_PAYMENT' ||
        status == 'WORK_COMPLETED' ||
        status == 'WAITING_FOR_PAYMENT_REQUEST';
  }

  bool _statusMeansPaymentPending(String status) {
    return status == 'PAYMENT_PENDING';
  }

  bool _handleAcceptedMechanic(
    Map<String, dynamic> data,
    String? fallbackRequestId, {
    bool updateState = true,
  }) {
    final backendType =
        (data['type'] ?? data['backendType'])?.toString().toUpperCase() ?? '';
    if (backendType == 'ROAD_REQUEST_CANCELLED' ||
        backendType == 'ROAD_REQUEST_EXPIRED') {
      return false;
    }

    final requestId =
        (data['requestId'] ?? fallbackRequestId ?? _activeRequestId)
            ?.toString();
    final mechanicId = (data['mechanicId'] ?? data['id'])?.toString();
    final lat = _toDouble(
      data['mechanicLatitude'] ?? data['latitude'] ?? data['lat'],
    );
    final lng = _toDouble(
      data['mechanicLongitude'] ?? data['longitude'] ?? data['lng'],
    );

    if (requestId == null || mechanicId == null || lat == null || lng == null) {
      debugPrint('Accepted mechanic payload missing route fields: $data');
      return false;
    }

    final position = LatLng(lat, lng);
    final name = (data['mechanicName'] ?? data['name'] ?? 'Mechanic').toString();
    final distance = _toDouble(data['distance']);
    final eta = data['eta']?.toString();

    _trackingClient?.deactivate();
    _trackingClient = null;

    _markerCurrentPositions
      ..clear()
      ..[mechanicId] = position;
    _markerTargetPositions
      ..clear()
      ..[mechanicId] = position;
    _markerTitles
      ..clear()
      ..[mechanicId] = name;

    final acceptedData = Map<String, dynamic>.from(data)
      ..['requestId'] = requestId
      ..['mechanicId'] = mechanicId
      ..['mechanicName'] = name
      ..['mechanicLatitude'] = lat
      ..['mechanicLongitude'] = lng
      ..['requestStatus'] =
          data['requestStatus'] ?? data['status'] ?? 'ACCEPTED'
      ..['userLat'] = _markerPos.latitude
      ..['userLng'] = _markerPos.longitude;

    void applyAccepted() {
      _activeRequestId = requestId;
      _isWaiting = true;
      _isAccepted = true;
      _acceptedMechanic = acceptedData;
      _acceptedMechanicPosition = position;
      _acceptedRouteTracker.reset(position);
      _acceptedBearing = 0;
      _acceptedDistanceText = distance == null
          ? data['distance']?.toString()
          : '${distance.toStringAsFixed(1)} km';
      _acceptedEta = eta;
      _mechanicMarkers = {
        Marker(
          markerId: MarkerId('mechanic_$mechanicId'),
          position: position,
          icon: _mechanicTrackingIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _acceptedBearing,
          infoWindow: InfoWindow(title: name),
        ),
      };
    }

    if (updateState) {
      setState(applyAccepted);
    } else {
      applyAccepted();
    }

    _saveActiveTracking();
    _connectAcceptedLiveLocation(requestId);
    _startAcceptedLocationPolling(requestId);
    _fetchAcceptedRoute(force: true);
    _fitAcceptedBounds();
    return true;
  }

  void _subscribeAcceptedLiveLocation(String requestId) {
    if (_liveLocationSubscribed || _requestClient == null) return;
    if (!_requestSocketConnected) return;

    _requestClient?.subscribe(
      destination: '/topic/request/$requestId/live-location',
      callback: (frame) {
        if (frame.body == null || !mounted) return;
        try {
          final decoded = jsonDecode(frame.body!);
          if (decoded is Map) {
            _handleAcceptedLiveLocation(Map<String, dynamic>.from(decoded));
          }
        } catch (e) {
          debugPrint('Accepted live location decode error: $e');
        }
      },
    );
    _liveLocationSubscribed = true;
  }

  void _connectAcceptedLiveLocation(String requestId) {
    if (_requestClient == null || !_requestSocketConnected) {
      _connectRequestStatus(requestId);
      return;
    }
    _subscribeAcceptedLiveLocation(requestId);
  }

  void _startAcceptedLocationPolling(String requestId) {
    _acceptedLocationPollTimer?.cancel();
    _acceptedLocationPollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshAcceptedLocation(requestId);
    });
    _refreshAcceptedLocation(requestId);
  }

  Future<void> _refreshAcceptedLocation(String requestId) async {
    if (!_isAccepted || !mounted) return;
    try {
      final response = await http.get(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/tracking/$requestId',
        ),
        headers: UserSession().getAuthHeader(),
      );

      if (response.statusCode != 200 || response.body.isEmpty || !mounted) {
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final data = Map<String, dynamic>.from(decoded);
      final lat = _toDouble(
        data['mechanicLatitude'] ??
            data['mechanicLat'] ??
            data['latitude'] ??
            data['lat'],
      );
      final lng = _toDouble(
        data['mechanicLongitude'] ??
            data['mechanicLng'] ??
            data['longitude'] ??
            data['lng'],
      );

      if (lat == null || lng == null) return;

      _handleAcceptedLiveLocation({
        ...data,
        'requestId': requestId,
        'mechanicId': data['mechanicId'] ?? _acceptedMechanic?['mechanicId'],
        'latitude': lat,
        'longitude': lng,
      });
    } catch (e) {
      debugPrint('Accepted location fallback refresh failed: $e');
    }
  }

  Future<void> _loadTrackingMarkerIcons() async {
    try {
      final mechanicIcon = await mapMarkerFromAsset(
        'assets/images/car.png',
        size: 40,
      );
      final userIcon = await _createUserRingMarker();
      
      if (!mounted) return;
      setState(() {
        _mechanicTrackingIcon = mechanicIcon;
        _userTrackingIcon = userIcon;
        _rebuildMechanicMarkersWithCurrentIcons();
      });
    } catch (e) {
      debugPrint('Error loading marker icons: $e');
      // Fallback to default if asset fails
      if (mounted) {
        setState(() {
          _mechanicTrackingIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
          _rebuildMechanicMarkersWithCurrentIcons();
        });
      }
    }
  }

  void _rebuildMechanicMarkersWithCurrentIcons() {
    final rebuilt = <Marker>{};
    for (final entry in _markerCurrentPositions.entries) {
      final isAcceptedMechanic =
          _isAccepted && _acceptedMechanic?['mechanicId']?.toString() == entry.key;
      rebuilt.add(
        Marker(
          markerId: MarkerId('mechanic_${entry.key}'),
          position: entry.value,
          icon: _mechanicTrackingIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: const Offset(0.5, 0.5),
          flat: isAcceptedMechanic,
          rotation: isAcceptedMechanic ? _acceptedBearing : 0,
          infoWindow: InfoWindow(
            title: _markerTitles[entry.key] ?? 'Mechanic #${entry.key}',
          ),
        ),
      );
    }
    _mechanicMarkers = rebuilt;
  }

  void _handleAcceptedLiveLocation(Map<String, dynamic> data) {
    final mechanicId =
        (data['mechanicId'] ?? _acceptedMechanic?['mechanicId'])?.toString();
    final lat = _toDouble(
      data['latitude'] ??
          data['mechanicLatitude'] ??
          data['mechanicLat'] ??
          data['lat'],
    );
    final lng = _toDouble(
      data['longitude'] ??
          data['mechanicLongitude'] ??
          data['mechanicLng'] ??
          data['lng'],
    );
    if (mechanicId == null || lat == null || lng == null) return;

    final target = LatLng(lat, lng);
    final distance = _toDouble(data['distance']);
    final eta = data['eta']?.toString();
    final name =
        (_acceptedMechanic?['mechanicName'] ?? 'Mechanic').toString();

    _markerCurrentPositions.putIfAbsent(mechanicId, () => target);
    _markerTargetPositions[mechanicId] = target;
    _markerTitles[mechanicId] = name;
    _acceptedRouteTracker.pushGps(target);
    if (_acceptedMechanicPosition == null) {
      _acceptedMechanicPosition = target;
      _acceptedRouteTracker.reset(target);
    }

    setState(() {
      _acceptedMechanic = {
        ...?_acceptedMechanic,
        'mechanicLatitude': lat,
        'mechanicLongitude': lng,
        if (distance != null) 'distance': distance,
        if (eta != null) 'eta': eta,
      };
      if (distance != null) {
        _acceptedDistanceText = '${distance.toStringAsFixed(1)} km';
      }
      if (eta != null && eta.isNotEmpty) {
        _acceptedEta = eta;
      }
    });

    if (!_markerTicker.isTicking) {
      _markerTicker.start();
    }

    _saveActiveTracking();
    _fetchAcceptedRoute();
  }

  void _saveActiveTracking() {
    if (_activeRequestId == null) return;

    if (_acceptedMechanic == null) {
      ActiveServiceRequestTracking.save({
        'requestId': _activeRequestId,
        'requestStatus': 'PENDING',
        'serviceType': widget.serviceType,
        'userNotes': widget.userNotes,
        'isFixedChargeAccepted': widget.isFixedChargeAccepted,
        'userLat': _markerPos.latitude,
        'userLng': _markerPos.longitude,
        if (_locationLabel != null) 'locationName': _locationLabel,
      });
      return;
    }

    ActiveServiceRequestTracking.save({
      ..._acceptedMechanic!,
      'requestId': _activeRequestId,
      'requestStatus': _paymentPending
          ? 'PAYMENT_PENDING'
          : (_workCompleted
              ? 'WORK_COMPLETED'
              : (_paymentApproved ? 'APPROVED_PAYMENT_REQUEST' : 'ACCEPTED')),
      'paymentApproved': _paymentApproved,
      'workCompleted': _workCompleted,
      'paymentPending': _paymentPending,
      'cashHandoverMarked': _cashHandoverMarked,
      if (_arrivalPrice != null) 'arrivalPrice': _arrivalPrice,
      'serviceType': widget.serviceType,
      'userNotes': widget.userNotes,
      'isFixedChargeAccepted': widget.isFixedChargeAccepted,
      'userLat': _markerPos.latitude,
      'userLng': _markerPos.longitude,
      if (_finalPrice != null) 'finalPrice': _finalPrice,
      if (_acceptedDistanceText != null) 'distanceText': _acceptedDistanceText,
      if (_acceptedEta != null) 'eta': _acceptedEta,
    });
  }

  Future<void> _fetchAcceptedRoute({bool force = false}) async {
    final mechanicId = _acceptedMechanic?['mechanicId']?.toString();
    final routeOrigin = mechanicId == null
        ? _acceptedMechanicPosition
        : (_markerTargetPositions[mechanicId] ?? _acceptedMechanicPosition);
    if (routeOrigin == null) return;

    final now = DateTime.now();
    final movedEnough = _lastRouteOrigin == null ||
        _distanceMeters(_lastRouteOrigin!, routeOrigin) >= 25;
    final timeEnough = _lastRouteFetchAt == null ||
        now.difference(_lastRouteFetchAt!).inSeconds >= 5;

    if (!force && !movedEnough && !timeEnough) return;

    _lastRouteFetchAt = now;
    _lastRouteOrigin = routeOrigin;

    try {
      final polylinePoints = PolylinePoints(apiKey: _googleApiKey);
      final result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(
            routeOrigin.latitude,
            routeOrigin.longitude,
          ),
          destination: PointLatLng(_markerPos.latitude, _markerPos.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (!mounted || result.points.isEmpty) return;

      final points =
          result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
      _acceptedRoutePoints = points;
      _acceptedRouteTracker.setRoute(
        points,
        anchor: _acceptedRouteTracker.displayPosition ?? _acceptedMechanicPosition,
      );
      final frame = _acceptedRouteTracker.tick(Duration.zero);
      if (frame != null && mounted) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('accepted_route'),
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
    } catch (e) {
      debugPrint('Accepted route fetch error: $e');
    }
  }

  void _shortenAcceptedRoute(LatLng mechanicPosition) {
    if (_acceptedRoutePoints.isEmpty) return;

    var indexToRemove = -1;
    for (var i = 0; i < _acceptedRoutePoints.length - 1; i++) {
      if (_distanceMeters(mechanicPosition, _acceptedRoutePoints[i]) < 18) {
        indexToRemove = i;
      }
    }

    if (indexToRemove != -1) {
      _acceptedRoutePoints.removeRange(0, indexToRemove + 1);
    }
  }

  void _updateAcceptedPolyline(LatLng mechanicPosition) {
    if (_acceptedRoutePoints.isEmpty || !mounted) return;

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('accepted_route'),
          points: [mechanicPosition, ..._acceptedRoutePoints],
          color: _primary,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    });
  }

  void _followAcceptedMechanic(LatLng position, double bearing) {
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

  void _fitAcceptedBounds() {
    final mechanicPosition = _acceptedMechanicPosition;
    if (mechanicPosition == null) return;

    final minLat = math.min(_markerPos.latitude, mechanicPosition.latitude);
    final maxLat = math.max(_markerPos.latitude, mechanicPosition.latitude);
    final minLng = math.min(_markerPos.longitude, mechanicPosition.longitude);
    final maxLng = math.max(_markerPos.longitude, mechanicPosition.longitude);

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  Future<void> _fetchNearbyMechanics(String serviceType) async {
    try {
      final nearbyPayload = {
        "latitude": _markerPos.latitude,
        "longitude": _markerPos.longitude,
        "serviceType": serviceType,
      };

      final res = await http.post(
        Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/nearbymechanic"),
        headers: {
          'Content-Type': 'application/json',
          ...UserSession().getAuthHeader(),
        },
        body: jsonEncode(nearbyPayload),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final String sessionId = data['mapSessionId'] ?? '';
        final List mechanics = data['mechanics'] ?? [];

        final Set<Marker> markers = {};
        for (final m in mechanics) {
          final double lat = (m['latitude'] is num)
              ? (m['latitude'] as num).toDouble()
              : double.tryParse(m['latitude'].toString()) ?? 0;
          final double lng = (m['longitude'] is num)
              ? (m['longitude'] as num).toDouble()
              : double.tryParse(m['longitude'].toString()) ?? 0;
          final int id = m['mechanicId'] ?? 0;
          final String mid = id.toString();
          final pos = LatLng(lat, lng);

          // Initialize animation state for loaded mechanics
          _markerCurrentPositions[mid] = pos;
          _markerTargetPositions[mid] = pos;
          _markerTitles[mid] = 'Mechanic #$id';

          markers.add(
            Marker(
              markerId: MarkerId('mechanic_$id'),
              position: pos,
              icon: _mechanicTrackingIcon ??
                  BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: InfoWindow(title: 'Mechanic #$id'),
            ),
          );
        }

        if (mounted) {
          setState(() {
            _mechanicMarkers = markers;
            _isWaiting = true;
          });
          _connectNearbyMechanicTracking(sessionId);

          // Zoom the map to fit both user and mechanics
          if (markers.isNotEmpty) {
            _fitMapBounds(markers);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No nearby mechanics found: ${res.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding nearby mechanics: $e')),
        );
      }
    }
  }

  void _connectNearbyMechanicTracking(String mapSessionId) {
    if (mapSessionId.isEmpty) return;

    _trackingClient?.deactivate();
    _trackingClient = StompClient(
      config: StompConfig(
        url:
            'wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket',
        stompConnectHeaders: UserSession().getAuthHeader(),
        webSocketConnectHeaders: UserSession().getAuthHeader(),
        onConnect: (_) {
          _trackingClient?.subscribe(
            destination: '/topic/nearby-mechanics/$mapSessionId',
            callback: (frame) {
              if (frame.body == null) return;
              try {
                final decoded = jsonDecode(frame.body!);
                if (decoded is Map) {
                  _updateMechanicMarker(Map<String, dynamic>.from(decoded));
                }
              } catch (e) {
                debugPrint('Nearby mechanic tracking decode error: $e');
              }
            },
          );
        },
        onStompError: (frame) =>
            debugPrint('Nearby mechanic STOMP error: ${frame.body}'),
        onWebSocketError: (error) =>
            debugPrint('Nearby mechanic socket error: $error'),
      ),
    );
    _trackingClient?.activate();
  }

  void _updateMechanicMarker(Map<String, dynamic> data) {
    final mechanicId = data['mechanicId']?.toString();
    final lat = _toDouble(data['latitude']);
    final lng = _toDouble(data['longitude']);
    if (mechanicId == null || lat == null || lng == null || !mounted) return;

    final target = LatLng(lat, lng);
    
    // Initialize if brand new mechanic (not in initial list)
    _markerCurrentPositions.putIfAbsent(mechanicId, () => target);
    _markerTitles[mechanicId] = 'Mechanic #$mechanicId';

    // Set the new target
    _markerTargetPositions[mechanicId] = target;

    // Start ticker if not already running
    if (!_markerTicker.isTicking) {
      _markerTicker.start();
    }
    
    debugPrint('🎬 Marker update received for $mechanicId → Animating to $lat, $lng');
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
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

  void _fitMapBounds(Set<Marker> markers) {
    double minLat = _markerPos.latitude;
    double maxLat = _markerPos.latitude;
    double minLng = _markerPos.longitude;
    double maxLng = _markerPos.longitude;

    for (final m in markers) {
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.01, minLng - 0.01),
          northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
        ),
        60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              c.setMapStyle(_mapStyle);
            },
            initialCameraPosition: CameraPosition(
              target: _markerPos,
              zoom: 14,
            ),
            markers: _isWaiting
                ? {
                    Marker(
                      markerId: const MarkerId('user_location'),
                      position: _markerPos,
                      icon: _userTrackingIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueOrange,
                          ),
                      anchor: const Offset(0.5, 0.5),
                      infoWindow: const InfoWindow(title: 'Your Location'),
                    ),
                    ..._mechanicMarkers,
                  }
                : {},
            polylines: _polylines,
            myLocationEnabled: !_isWaiting,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            onCameraMoveStarted: _isWaiting ? null : () {
              setState(() {
                _isDragging = true;
                _locationLabel = null;
              });
            },
            onCameraMove: _isWaiting ? null : (pos) {
              setState(() => _markerPos = pos.target);
            },
            onCameraIdle: _isWaiting ? null : () {
              setState(() => _isDragging = false);
              _geocodeDebounce?.cancel();
              _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
                _reverseGeocode(_markerPos);
              });
            },
          ),

          // Show the draggable pin ONLY when NOT in waiting mode
          if (!_isWaiting)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMarkerWidget(),
                  Container(
                    width: 3,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),

          if (_locationLabel != null && !_isDragging && !_isWaiting)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: _buildTooltip(_locationLabel!),
              ),
            ),

          if (!_isWaiting)
            SafeArea(
              child: Column(
                children: [
                  _buildSearchBar(),
                  if (_showSuggestions) _buildSuggestionsList(),
                ],
              ),
            ),

          if (!_isWaiting)
            Positioned(
              right: 16,
              bottom: 120,
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                elevation: 4,
                onPressed: _getUserLocation,
                child: const Icon(Icons.my_location_rounded, color: _primary),
              ),
            ),

          // Bottom: Send Request button OR Waiting card
          if (!_isWaiting)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendServiceRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isLoading 
                  ? const SizedBox(
                      width: 24, 
                      height: 24, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    )
                  : const Text(
                  'Send Request',
                  style: TextStyle(
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Waiting for Response card
          if (_isWaiting)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: _isPriceReceived
                  ? _buildPriceApprovalCard()
                  : (_isAccepted
                      ? _buildAcceptedMechanicCard()
                      : _buildWaitingCard()),
            ),

          // Back button in waiting mode
          if (_isWaiting)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: GestureDetector(
                  onTap: () {
                    _saveActiveTracking();
                    _goToUserDashboard();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 6)
                      ],
                    ),
                    child: Icon(
                      _isAccepted ? Icons.close : Icons.arrow_back_ios_new_rounded,
                      color: _isAccepted ? Colors.black87 : const Color(0xFFFB3300),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarkerWidget() {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isDragging)
            AnimatedBuilder(
              animation: _spinController,
              builder: (_, __) => Transform.rotate(
                angle: _spinController.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(56, 56),
                  painter: _DashedCirclePainter(color: _primary),
                ),
              ),
            ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: _isDragging ? Colors.transparent : _primary,
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.location_pin,
              color: _primary,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Bricolage Grotesque',
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: isDark ? Colors.black38 : Colors.black12, blurRadius: 6)
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFFFB3300),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: isDark ? Colors.black38 : Colors.black12, blurRadius: 8)
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                style: TextStyle(
                    fontFamily: 'Bricolage Grotesque', fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Search location...',
                  hintStyle: TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      color: Colors.grey.shade500,
                      fontSize: 13),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: _primary, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _suggestions = [];
                              _showSuggestions = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    _fetchSuggestions(v);
                  });
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _suggestions.take(5).map((p) {
              final desc = p['description'] as String;
              final main = p['structured_formatting']?['main_text'] as String?
                  ?? desc;
              final secondary =
                  p['structured_formatting']?['secondary_text'] as String?;
              return InkWell(
                onTap: () => _selectSuggestion(p),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: _primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              main,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (secondary != null)
                              Text(
                                secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Bricolage Grotesque',
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
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  int _defaultArrivalPrice() {
    final type = widget.serviceType.toLowerCase();
    if (type.contains('bike')) return 300;
    if (type.contains('car')) return 500;
    if (type.contains('puncher')) return 100;
    return 300;
  }

  void _applyApprovedPaymentPayload(Map<String, dynamic> data) {
    final status =
        (data['status'] ?? data['requestStatus'])?.toString().toUpperCase() ??
            '';
    final type =
        (data['type'] ?? data['backendType'])?.toString().toUpperCase() ?? '';

    if (_statusMeansWaitingForPayment(status) ||
        _statusMeansPaymentPending(status) ||
        type == 'WORK_COMPLETED' ||
        type == 'PAYMENT_PENDING' ||
        data['workCompleted'] == true) {
      if (_statusMeansPaymentPending(status) || type == 'PAYMENT_PENDING') {
        _applyPaymentPendingPayload(data);
      } else {
        _applyWorkCompletedPayload(data);
      }
      return;
    }

    final isApproved = data['paymentApproved'] == true ||
        status == 'APPROVED_PAYMENT_REQUEST' ||
        status == 'APPROVED_PRICE_REQUEST' ||
        status == 'WORK_STARTED' ||
        type == 'USER_APPROVED';

    if (isApproved && !_workCompleted) {
      _paymentApproved = true;
      _isPriceReceived = false;
    }

    final price = _pickPrice(data);
    if (price != null) _finalPrice = price;
    _arrivalPrice = _pickArrivalPrice(data) ??
        _arrivalPrice ??
        (isApproved ? _defaultArrivalPrice().toDouble() : null);
  }

  void _applyWorkCompletedPayload(Map<String, dynamic> data) {
    _workCompleted = true;
    _paymentApproved = true;
    _isPriceReceived = false;
    _paymentPending = false;
    _cashHandoverMarked = false;
    final price = _pickPrice(data);
    if (price != null) _finalPrice = price;
    _arrivalPrice = _pickArrivalPrice(data) ??
        _arrivalPrice ??
        _defaultArrivalPrice().toDouble();
  }

  void _applyPaymentPendingPayload(Map<String, dynamic> data) {
    _paymentPending = true;
    _workCompleted = true;
    _paymentApproved = true;
    _isPriceReceived = false;

    final price = _pickPrice(data) ?? _toDouble(data['amount']);
    if (price != null) _finalPrice = price;

    final visiting = _pickArrivalPrice(data) ??
        _toDouble(data['visiting charges']) ??
        _toDouble(data['visitingCharges']);
    _arrivalPrice = visiting ?? _arrivalPrice ?? _defaultArrivalPrice().toDouble();
  }

  double _totalPayableAmount() {
    return (_finalPrice ?? 0) + (_arrivalPrice ?? 0);
  }

  Future<void> _showPayNowSheet() async {
    if (_activeRequestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request id missing')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose payment method',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _payOptionTile(
                      icon: Icons.payments_rounded,
                      title: 'Cash',
                      subtitle: 'Pay directly to mechanic',
                      onTap: () async {
                        Navigator.pop(context);
                        await _startCashPayment();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _payOptionTile(
                      icon: Icons.language_rounded,
                      title: 'Online',
                      subtitle: 'Coming soon',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Online payment coming soon')),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _payOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          color: Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _primary),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startCashPayment() async {
    if (_activeRequestId == null) return;
    setState(() => _isPaying = true);

    try {
      final response = await http.post(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/paynow/$_activeRequestId',
        ),
        headers: {
          'Content-Type': 'application/json',
          ...UserSession().getAuthHeader(),
        },
        body: jsonEncode({'paymentype': 'CASH'}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _applyPaymentPendingPayload({
            'status': 'PAYMENT_PENDING',
            'type': 'PAYMENT_PENDING',
            'requestId': _activeRequestId,
            'finalPrice': _finalPrice,
            'arrivalPrice': _arrivalPrice,
          });
        });
        _saveActiveTracking();
        await _showCashHandoverSheet();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pay now failed: ${response.body}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pay now error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  Future<void> _showCashHandoverSheet() async {
    final amount = _totalPayableAmount();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cash payment',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inspection: Rs. ${(_finalPrice ?? 0).toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visiting: Rs. ${(_arrivalPrice ?? 0).toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Total: Rs. ${amount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Please handover cash to mechanic.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _cashHandoverMarked = true;
                    });
                    _saveActiveTracking();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: Text(
                    'Payment Done',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _approvePaymentRequest() async {
    if (_activeRequestId == null || _finalPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request or price missing')),
      );
      return;
    }

    setState(() => _isApprovingPayment = true);

    try {
      final requestId = int.tryParse(_activeRequestId!) ?? _activeRequestId;
      final response = await http.post(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/approve-payment-request',
        ),
        headers: {
          'Content-Type': 'application/json',
          ...UserSession().getAuthHeader(),
        },
        body: jsonEncode({
          'requestId': requestId,
          'finalPrice': _finalPrice,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Map<String, dynamic> payload = {
          'finalPrice': _finalPrice,
          'arrivalPrice': _defaultArrivalPrice(),
          'type': 'USER_APPROVED',
          'status': 'APPROVED_PAYMENT_REQUEST',
        };
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            payload = {...payload, ...Map<String, dynamic>.from(decoded)};
          }
        } catch (_) {}

        setState(() => _applyApprovedPaymentPayload(payload));
        _saveActiveTracking();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Charges approved. Mechanic will start work.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approval failed: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isApprovingPayment = false);
      }
    }
  }

  Widget _buildPriceApprovalCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black26,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded, color: _primary, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            'Inspection Charges',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rs. ${_finalPrice?.toStringAsFixed(0) ?? '0'}',
            style: GoogleFonts.poppins(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please review and confirm the charges',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isPriceReceived = false;
                        _finalPrice = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Charges declined'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                    label: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.red,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isApprovingPayment ? null : _approvePaymentRequest,
                    icon: _isApprovingPayment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    label: Text(
                      _isApprovingPayment ? 'Wait...' : 'Approve',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedMechanicCard() {
    final mechanic = _acceptedMechanic ?? {};
    final name = (mechanic['mechanicName'] ?? 'Mechanic').toString();
    final number = (mechanic['mechanicNumber'] ?? '').toString();
    final image = (mechanic['mechanicImage'] ?? '').toString();
    final type = (mechanic['mechanicType'] ?? 'Mechanic').toString();
    final shop = (mechanic['mechanicShopName'] ?? 'Shop location').toString();
    final experience = mechanic['mechanicExperience']?.toString() ?? '0';
    final reviews = mechanic['mechanicTotalReviews']?.toString() ?? '0';
    final rating = _toDouble(mechanic['mechanicRating']);
    final distance = _acceptedDistanceText ??
        (mechanic['distanceText'] ?? mechanic['distance'] ?? '--').toString();
    final eta = _acceptedEta ?? mechanic['eta']?.toString() ?? '--';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black26,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                backgroundImage:
                    image.startsWith('http') ? NetworkImage(image) : null,
                child: image.startsWith('http')
                    ? null
                    : const Icon(Icons.person, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$type • $experience yrs exp',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      shop,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      ),
                    ),
                    if (_workCompleted) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Work completed',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ] else if (_paymentApproved) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Charges confirmed • work starting',
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
              if (_paymentApproved || _workCompleted)
                ServiceChargesPriceBadge(
                  inspectionPrice: _finalPrice,
                  visitingPrice: _arrivalPrice,
                  primaryColor: _primary,
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          rating == null ? '--' : rating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$reviews reviews',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _trackingMetric(
                  Icons.route_rounded,
                  'Distance',
                  distance,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _trackingMetric(
                  Icons.schedule_rounded,
                  'ETA',
                  eta,
                ),
              ),
              if (number.isNotEmpty) ...[
                const SizedBox(width: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => launchUrl(Uri.parse('tel:$number')),
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
            ],
          ),
          if (_workCompleted) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade50,
                    Colors.indigo.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  Icon(
                    _paymentPending
                        ? Icons.hourglass_bottom_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.blue.shade700,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _paymentPending
                        ? 'Waiting for mechanic confirmation'
                        : 'Service Completed',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _paymentPending
                        ? (_cashHandoverMarked
                            ? 'Payment marked done. Mechanic will confirm.'
                            : 'Choose payment method to proceed.')
                        : 'Pay Rs. ${_totalPayableAmount().toStringAsFixed(0)} to finish',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (!_paymentPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isPaying ? null : _showPayNowSheet,
                  icon: _isPaying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.payments_rounded, color: Colors.white),
                  label: Text(
                    _isPaying ? 'Please wait...' : 'Pay Now',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _cancelRequest,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                : const Icon(Icons.cancel_rounded, color: Colors.red),
              label: Text(
                _isLoading ? 'Cancelling...' : 'Cancel Request',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.red,
                ),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: const BorderSide(color: Colors.red),
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
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black26,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              color: Color(0xFFFB3300),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Waiting for Response...',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_mechanicMarkers.length} nearby mechanic${_mechanicMarkers.length == 1 ? '' : 's'} notified',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Please wait while a mechanic accepts your request.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton.icon(
              onPressed: _isLoading ? null : _cancelRequest,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                : const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              label: Text(
                _isLoading ? 'Cancelling...' : 'Cancel Request',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const dashCount = 10;
    const dashAngle = math.pi * 2 / dashCount;
    const gapFraction = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final start = dashAngle * i;
      final sweep = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
