import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
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
      // 1. Get positions
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      Position? mechPos;
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        mechPos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      }

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

      if (!mounted || userLatLng == null || mechPos == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Show basic markers immediately
      final LatLng mechLatLng = LatLng(mechPos.latitude, mechPos.longitude);
      final mechanicIcon = await _createLollipopMarker();
      final userIconInitial = await _createUserDotMarker("Calculating...");

      if (mounted) {
        setState(() {
          _userLocation = userLatLng;
          _mechanicLocation = mechLatLng;
          _markers = {
            Marker(markerId: const MarkerId('mechanic_loc'), position: mechLatLng, icon: mechanicIcon, anchor: const Offset(0.5, 1.0)),
            Marker(markerId: const MarkerId('user_loc'), position: userLatLng!, icon: userIconInitial, anchor: const Offset(0.5, 0.9)),
          };
          _isLoading = false;
        });
      }

      const String apiKey = "AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU";
      
      // 3. Fetch duration & route (async, won't block UI if fails)
      _updateRouteAndDuration(mechLatLng, userLatLng, apiKey, mechanicIcon);

    } catch (e) {
      debugPrint('Map setup error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRouteAndDuration(LatLng start, LatLng end, String apiKey, BitmapDescriptor mechanicIcon) async {
    String travelTime = "Route error";
    
    // Fetch duration
    try {
      final url = "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$apiKey";
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          travelTime = data['routes'][0]['legs'][0]['duration']['text'];
        }
      }
    } catch (e) {
      debugPrint("❌ Duration Fetch Error: $e");
    }

    // Update markers with real time
    final userIconUpdated = await _createUserDotMarker(travelTime);
    if (mounted) {
      setState(() {
        _markers = {
          Marker(markerId: const MarkerId('mechanic_loc'), position: start, icon: mechanicIcon, anchor: const Offset(0.5, 1.0)),
          Marker(markerId: const MarkerId('user_loc'), position: end, icon: userIconUpdated, anchor: const Offset(0.5, 0.9)),
        };
      });
    }

    // Fetch Polyline
    try {
      PolylinePoints pp = PolylinePoints(apiKey: apiKey);
      PolylineResult result = await pp.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(start.latitude, start.longitude),
          destination: PointLatLng(end.latitude, end.longitude),
          mode: TravelMode.driving,
        ),
      );
      
      if (mounted) {
        setState(() {
          if (result.points.isNotEmpty) {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                color: Colors.red,
                width: 5,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
              )
            };
          } else {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('fallback'),
                color: Colors.red,
                width: 4,
                points: [start, end],
                patterns: [PatternItem.dash(20), PatternItem.gap(10)],
              )
            };
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Polyline Fetch Error: $e");
    }
  }

  Future<BitmapDescriptor> _createLollipopMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 120.0;
    
    final Paint linePaint = Paint()..color = Colors.red..strokeWidth = 4..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(size / 2, size / 2), const Offset(size / 2, size), linePaint);

    final Paint circlePaint = Paint()..color = Colors.red;
    canvas.drawCircle(const Offset(size / 2, size / 2), 35, circlePaint);

    final Paint dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), 8, dotPaint);

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createUserDotMarker(String duration) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double width = 240.0;
    const double height = 180.0;

    final Paint boxPaint = Paint()..color = Colors.white;
    final RRect rRect = RRect.fromLTRBR(20, 0, width - 20, 60, const Radius.circular(12));
    canvas.drawRRect(rRect.shift(const Offset(0, 2)), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawRRect(rRect, boxPaint);

    final Path path = Path();
    path.moveTo(width / 2 - 10, 60);
    path.lineTo(width / 2, 75);
    path.lineTo(width / 2 + 10, 60);
    canvas.drawPath(path, boxPaint);

    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: duration,
      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((width - textPainter.width) / 2, (60 - textPainter.height) / 2));

    final Paint dotOuterPaint = Paint()..color = Colors.black87;
    final Paint dotInnerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(width / 2, height - 30), 16, dotOuterPaint);
    canvas.drawCircle(const Offset(width / 2, height - 30), 12, dotInnerPaint);

    final img = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
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
