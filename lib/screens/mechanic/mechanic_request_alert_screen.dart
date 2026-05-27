import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/mechanic_notification_controller.dart';

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

  const MechanicRequestAlertScreen({
    super.key,
    required this.requestData,
  });

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
  
  final Color primaryColor = const Color(0xFFFB3300);

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
        lat = double.tryParse(widget.requestData['userLatitude'].toString()) ?? 0.0;
      }
    }
    
    if (widget.requestData['userLongitude'] != null) {
      if (widget.requestData['userLongitude'] is num) {
        lng = (widget.requestData['userLongitude'] as num).toDouble();
      } else {
        lng = double.tryParse(widget.requestData['userLongitude'].toString()) ?? 0.0;
      }
    }
    
    _targetPos = LatLng(lat, lng);

    // Start 60 second countdown
    _startTimer();
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
        // Time expired, pop screen
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String userId = widget.requestData['userid']?.toString() ??
        widget.requestData['userId']?.toString() ?? 'N/A';
        
    final String serviceType = widget.requestData['serviceType'] ?? 'General Service';
    final String status = widget.requestData['requestStatus'] ?? 'PENDING';
    final String distance = widget.requestData['distanceKm'] != null 
        ? '${(widget.requestData['distanceKm'] as num).toStringAsFixed(1)} km' 
        : '--';
    final String eta = widget.requestData['eta']?.toString() ?? '--';
    final String userNotes = widget.requestData['userNotes'] ?? 'No notes provided.';

    final progress = _secondsLeft / _totalSeconds;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Map
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              c.setMapStyle(_mapStyle);
            },
            initialCameraPosition: CameraPosition(
              target: _targetPos,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('user_location'),
                position: _targetPos,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange, // Match primary color approx
                ),
              )
            },
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // 2. Linear Progress Bar at the top SafeArea
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  )
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
                          Icon(Icons.build_circle_rounded, color: primaryColor, size: 28),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      _infoBox(Icons.route_rounded, "Distance", distance, isDark),
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
                        color: isDark ? Colors.grey.shade800 : Colors.orange.shade100,
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
                  
                  // Accept Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _acceptRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        "ACCEPT REQUEST",
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
          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
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
}
