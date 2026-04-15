import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MechanicRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;

  const MechanicRequestDetailScreen({super.key, required this.request});

  @override
  State<MechanicRequestDetailScreen> createState() =>
      _MechanicRequestDetailScreenState();
}

class _MechanicRequestDetailScreenState
    extends State<MechanicRequestDetailScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  LatLng? _userLocation;
  LatLng? _mechanicLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  String? _actionTaken;

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  Future<void> _setupMap() async {
    try {
      // 1️⃣ Get mechanic's current GPS location
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      Position? mechPos;
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        mechPos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      }

      // 2️⃣ Get user location — from lat/lon DTO or geocode address
      LatLng? userLatLng;
      final lat = widget.request['lat'];
      final lon = widget.request['lon'];
      if (lat != null && lon != null) {
        userLatLng = LatLng((lat as num).toDouble(), (lon as num).toDouble());
      } else {
        try {
          final locs = await locationFromAddress(widget.request['location'] ?? '');
          if (locs.isNotEmpty) {
            userLatLng = LatLng(locs[0].latitude, locs[0].longitude);
          }
        } catch (_) {}
      }

      if (!mounted) return;

      final Set<Marker> markers = {};
      final Set<Polyline> polylines = {};

      if (userLatLng != null) {
        markers.add(Marker(
          markerId: const MarkerId('user_loc'),
          position: userLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: widget.request['userName'] ?? 'User',
            snippet: widget.request['location'] ?? '',
          ),
        ));
      }

      if (mechPos != null) {
        final mechLatLng = LatLng(mechPos.latitude, mechPos.longitude);
        markers.add(Marker(
          markerId: const MarkerId('mechanic_loc'),
          position: mechLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'My Location'),
        ));

        // 3️⃣ Draw route (isolated try/catch so markers show even if route fails on web)
        if (userLatLng != null) {
          try {
            PolylinePoints pp = PolylinePoints(apiKey: "AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU");
            PolylineResult result = await pp.getRouteBetweenCoordinates(
              request: PolylineRequest(
                origin: PointLatLng(mechPos.latitude, mechPos.longitude),
                destination: PointLatLng(userLatLng.latitude, userLatLng.longitude),
                mode: TravelMode.driving,
              ),
            );
            if (result.points.isNotEmpty) {
              polylines.add(Polyline(
                polylineId: const PolylineId('route'),
                color: Colors.red,
                width: 5,
                points: result.points
                    .map((p) => LatLng(p.latitude, p.longitude))
                    .toList(),
              ));
            } else {
              polylines.add(Polyline(
                polylineId: const PolylineId('fallback'),
                color: Colors.red,
                width: 4,
                points: [mechLatLng, userLatLng],
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              ));
            }
          } catch (_) {
            // CORS/network error on web — draw dashed straight line
            polylines.add(Polyline(
              polylineId: const PolylineId('fallback'),
              color: Colors.red,
              width: 4,
              points: [mechLatLng, userLatLng],
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ));
          }
        }
      }

      setState(() {
        _userLocation = userLatLng;
        _mechanicLocation = mechPos != null
            ? LatLng(mechPos.latitude, mechPos.longitude)
            : null;
        _markers = markers;
        _polylines = polylines;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Map setup error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAccept() {
    setState(() => _actionTaken = 'accepted');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text("Request Accepted!",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          "You've accepted the request from ${widget.request['userName']}. Navigate to the location.",
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("OK",
                style: GoogleFonts.poppins(
                    color: Colors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _handleReject() {
    setState(() => _actionTaken = 'rejected');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text("Request Rejected",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          "You've rejected the request from ${widget.request['userName']}.",
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text("OK",
                style: GoogleFonts.poppins(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final request = widget.request;
    final bool isAppointment = request['type'] == 'appointment';
    final String userimage = request['userimage'] ?? '';

    // Camera target: show mechanic if available, else user
    final LatLng? cameraTarget = _mechanicLocation ?? _userLocation;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isAppointment ? 'Appointment' : 'Daily Request',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🗺️ MAP with Route
          Expanded(
            flex: 5,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : cameraTarget == null
                    ? Center(
                        child: Text('Location unavailable',
                            style: GoogleFonts.poppins(color: Colors.grey)))
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: cameraTarget,
                          zoom: 14,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        markers: _markers,
                        polylines: _polylines,
                      ),
          ),

          // 🔹 BOTTOM CARD
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // User Info Row (with real profile picture)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: primaryColor.withValues(alpha: 0.12),
                      backgroundImage: userimage.isNotEmpty
                          ? NetworkImage(userimage)
                          : null,
                      child: userimage.isEmpty
                          ? Text(
                              (request['userName'] as String?)?.isNotEmpty == true
                                  ? request['userName'][0]
                                  : '?',
                              style: GoogleFonts.poppins(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['userName'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                isAppointment
                                    ? Icons.event_available_rounded
                                    : Icons.car_crash_rounded,
                                size: 13,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isAppointment ? 'Appointment' : 'Daily Request',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Price
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        request['price'] ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _infoRow(Icons.build_circle_outlined,
                    request['issue'] ?? 'Emergency Assistance', isDark),
                const SizedBox(height: 8),
                _infoRow(Icons.location_on_rounded,
                    request['location'] ?? '', isDark),
                if (request['distance'] != null &&
                    request['distance'] != '') ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.directions_car_filled_rounded,
                      request['distance'], isDark),
                ],
                if (isAppointment && request['scheduledTime'] != null) ...[
                  const SizedBox(height: 8),
                  _infoRow(Icons.calendar_today_rounded,
                      request['scheduledTime'], isDark),
                ],

                const SizedBox(height: 20),

                // Accept / Reject
                if (_actionTaken == null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleReject,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side:
                                const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text("Reject",
                              style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text("Accept",
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                        ),
                      ),
                    ],
                  )
                else
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: (_actionTaken == 'accepted'
                                ? Colors.green
                                : Colors.red)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _actionTaken == 'accepted'
                            ? '✅ You accepted this request'
                            : '❌ You rejected this request',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _actionTaken == 'accepted'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }
}
