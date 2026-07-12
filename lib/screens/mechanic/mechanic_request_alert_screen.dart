import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../services/mechanic_live_location_service.dart';
import '../../utils/distance_formatter.dart';
import '../../services/active_service_request_tracking.dart';
import '../../services/emergency_alert_service.dart';
import '../../services/mechanic_notification_controller.dart';
import 'mechanic_usermap.dart';
import 'mechanic_dashboard.dart';
import '../authentication/user_session.dart';
import '../../utils/map_theme_helper.dart';

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

class MechanicRequestAlertScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const MechanicRequestAlertScreen({super.key, required this.requestData});

  @override
  State<MechanicRequestAlertScreen> createState() =>
      _MechanicRequestAlertScreenState();
}

class _MechanicRequestAlertScreenState extends State<MechanicRequestAlertScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late LatLng _targetPos;

  // Timer stuff
  Timer? _timer;
  int _secondsLeft = 60;
  final int _totalSeconds = 60;
  bool _isAccepting = false;
  bool _isRejecting = false;
  bool _isClosingForCancellation = false;

  final Color primaryColor = const Color(0xFFFB3300);
  final String _googleApiKey = 'AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU';
  String _calculatedDistance = '--';
  String _calculatedEta = '--';

  @override
  void initState() {
    super.initState();
    // Safely parse latitude and longitude
    double lat = 0.0;
    double lng = 0.0;

    if (widget.requestData['userLatitude'] != null) {
      if (widget.requestData['userLatitude'] is num) {
        lat = (widget.requestData['userLatitude'] as num).toDouble();
      } else {
        lat =
            double.tryParse(widget.requestData['userLatitude'].toString()) ??
            0.0;
      }
    }

    if (widget.requestData['userLongitude'] != null) {
      if (widget.requestData['userLongitude'] is num) {
        lng = (widget.requestData['userLongitude'] as num).toDouble();
      } else {
        lng =
            double.tryParse(widget.requestData['userLongitude'].toString()) ??
            0.0;
      }
    }

    _targetPos = LatLng(lat, lng);
    _fetchDistanceAndEta();

    MechanicNotificationController().addListener(_onNotification);
    ActiveServiceRequestTracking.save({
      ...widget.requestData,
      'requestStatus': 'PENDING',
    });

    // Start 60 second countdown
    _startTimer();
  }

  void _onNotification(Map<String, dynamic> data, String type) {
    final incomingReqId =
        data['requestId']?.toString() ?? data['requestid']?.toString();
    final myReqId =
        widget.requestData['requestId']?.toString() ??
        widget.requestData['requestid']?.toString();

    if (incomingReqId == null || myReqId == null || incomingReqId != myReqId) {
      return;
    }

    if (data['type'] == 'ROAD_REQUEST_CANCELLED' ||
        data['backendType'] == 'ROAD_REQUEST_CANCELLED') {
      _goToDashboardAfterCancellation(message: data['message']?.toString());
      return;
    }

    if (data['type'] == 'ROAD_REQUEST_EXPIRED' ||
        data['backendType'] == 'ROAD_REQUEST_EXPIRED') {
      _closeAfterRequestTakenByAnother(data['message']?.toString());
    }
  }

  void _goToDashboardAfterCancellation({String? message}) {
    if (_isClosingForCancellation) return;
    _isClosingForCancellation = true;
    _timer?.cancel();
    ActiveServiceRequestTracking.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message?.isNotEmpty == true
            ? message!
            : 'Customer has cancelled the request!'),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
      (route) => false,
    );
  }

  void _closeAfterRequestTakenByAnother(String? message) {
    if (_isClosingForCancellation) return;
    _isClosingForCancellation = true;
    _timer?.cancel();
    ActiveServiceRequestTracking.clear();
    if (!mounted) return;
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
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
        (route) => false,
      );
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        if (mounted) {
          setState(() {
            _secondsLeft--;
          });
        }
      } else {
        _timer?.cancel();
        ActiveServiceRequestTracking.clear();
        _cancelRequestOnServer(); // call asynchronously to update server state
        EmergencyAlertService.instance.stopEffects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request expired'),
              backgroundColor: Colors.orange,
            ),
          );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
              (route) => false,
            );
          }
        }
      }
    });
  }

  Future<void> _fetchDistanceAndEta() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final originLat = position.latitude;
      final originLng = position.longitude;
      final destLat = _targetPos.latitude;
      final destLng = _targetPos.longitude;

      final url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$originLat,$originLng'
          '&destination=$destLat,$destLng'
          '&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final legs = data['routes'][0]['legs'];
          if (legs != null && legs.isNotEmpty) {
            final distanceText = legs[0]['distance']['text'] as String;
            final durationText = legs[0]['duration']['text'] as String;

            if (mounted) {
              setState(() {
                _calculatedDistance = distanceText;
                _calculatedEta = durationText;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching distance and ETA: $e");
    }
  }

  @override
  void dispose() {
    MechanicNotificationController().removeListener(_onNotification);
    EmergencyAlertService.instance.stopEffects();
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ignore: unused_element
  void _acceptRequest() {
    // TODO: Actually hit the API to accept the request
    // api/service-request/accept ...

    debugPrint("✅ Request Accepted: ${widget.requestData}");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request Accepted!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _cancelRequestOnServer() async {
    // API removed — no longer used
    debugPrint("Cancel API removed");
  }

  Future<void> _rejectRequest() async {
    if (_isRejecting || _isAccepting) return;
    setState(() => _isRejecting = true);

    await EmergencyAlertService.instance.stopEffects();
    _timer?.cancel();
    ActiveServiceRequestTracking.clear();

    await _cancelRequestOnServer();

    if (!mounted) return;
    setState(() => _isRejecting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request declined'),
        backgroundColor: Colors.red,
      ),
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _acceptRequestFromBackend() async {
    if (_isAccepting) return;

    final requestId =
        widget.requestData['requestId']?.toString() ??
        widget.requestData['requestid']?.toString() ??
        widget.requestData['serviceRequestId']?.toString() ??
        widget.requestData['servicerequestid']?.toString() ??
        widget.requestData['roadRequestId']?.toString() ??
        widget.requestData['roadrequestid']?.toString() ??
        widget.requestData['request_id']?.toString();
    if (requestId == null || requestId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request id missing')));
      return;
    }

    setState(() => _isAccepting = true);

    try {
      final response = await http.post(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/accept/$requestId',
        ),
        headers: {
          ...UserSession().getAuthHeader(),
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await EmergencyAlertService.instance.stopEffects();
        final acceptedData = jsonDecode(response.body);

        // Merge original request data with acceptance response
        // so the map has serviceType, userNotes, and user location from the original notification
        final mergedData = <String, dynamic>{
          ...widget
              .requestData, // original notification data (serviceType, userNotes, userLatitude, etc.)
          ...Map<String, dynamic>.from(
            acceptedData,
          ), // acceptance response (mechanic details, user info)
          'requestStatus': 'ACCEPTED',
        };

        ActiveServiceRequestTracking.save(mergedData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Accepted!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MechanicUserMap(requestData: mergedData),
          ),
        );
        MechanicLiveLocationService.instance.start(requestId: requestId);
      } else {
        String message = response.body;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Accept request failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mapController != null) {
      MapThemeHelper.applyMapTheme(_mapController!, context);
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String userId =
        widget.requestData['userid']?.toString() ??
        widget.requestData['userId']?.toString() ??
        'N/A';

    final String serviceType =
        widget.requestData['serviceType'] ?? 'General Service';
    final String status = widget.requestData['requestStatus'] ?? 'PENDING';
    final String distance = _calculatedDistance != '--' ? _calculatedDistance : _extractDistance(widget.requestData);
    final String eta = _calculatedEta != '--' ? _calculatedEta : _extractEta(widget.requestData);
    final String userNotes = _extractUserNotes(widget.requestData);

    final progress = _secondsLeft / _totalSeconds;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Map
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              MapThemeHelper.applyMapTheme(c, context);
            },
            initialCameraPosition: CameraPosition(target: _targetPos, zoom: 15),
            markers: {
              Marker(
                markerId: const MarkerId('user_location'),
                position: _targetPos,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange, // Match primary color approx
                ),
              ),
            },
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),

          // 2. Linear Progress Bar at the top SafeArea
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Text(
                            "Emergency Request • $_secondsLeft s",
                            style: GoogleFonts.poppins(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade300,
                          color: primaryColor,
                          minHeight: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom Card Details
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              bottom: true,
              child: Container(
                margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 64),
                padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Service Type & ID
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.build_circle_rounded,
                            color: primaryColor,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            serviceType.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "User ID: $userId",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const Divider(height: 24),

                  // Info row: ETA & Distance
                  Row(
                    children: [
                      _infoBox(Icons.timer_rounded, "ETA", eta, isDark),
                      const SizedBox(width: 12),
                      _infoBox(
                        Icons.route_rounded,
                        "Distance",
                        distance,
                        isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.orange.shade100,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "User Notes:",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userNotes,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (_isAccepting || _isRejecting)
                              ? null
                              : _rejectRequest,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isRejecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'REJECT',
                                  style: GoogleFonts.poppins(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (_isAccepting || _isRejecting)
                              ? null
                              : _acceptRequestFromBackend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                          child: _isAccepting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'ACCEPT',
                                  style: TextStyle(
                                    fontFamily: 'Bricolage Grotesque',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String label, String value, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractDistance(Map<String, dynamic> data) {
    final dynamic rawDistance =
        data['distanceKm'] ??
        data['distance'] ??
        data['distanceInKm'] ??
        data['distance_in_km'] ??
        data['distanceKmFormatted'];
    if (rawDistance == null) return '--';
    return DistanceFormatter.formatKilometers(rawDistance);
  }

  String _extractEta(Map<String, dynamic> data) {
    final dynamic rawEta =
        data['eta'] ??
        data['ETA'] ??
        data['estimatedTime'] ??
        data['estimated_time'] ??
        data['arrivalTime'] ??
        data['arrival_time'];
    if (rawEta == null) return '--';
    return rawEta.toString();
  }

  String _extractUserNotes(Map<String, dynamic> data) {
    final String rawNotes =
        (data['userNotes'] ??
                data['notes'] ??
                data['note'] ??
                data['user_notes'] ??
                '')
            .toString()
            .trim();
    if (rawNotes.isEmpty) return 'No notes provided.';
    return rawNotes;
  }
}