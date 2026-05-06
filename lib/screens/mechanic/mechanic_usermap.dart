import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MechanicUserMap extends StatefulWidget {
  final String address;
  final double? userLat;
  final double? userLon;

  const MechanicUserMap({
    Key? key,
    required this.address,
    this.userLat,
    this.userLon,
  }) : super(key: key);

  @override
  State<MechanicUserMap> createState() => _MechanicUserMapState();
}

class _MechanicUserMapState extends State<MechanicUserMap> {
  late GoogleMapController mapController;
  LatLng? _userLocation;
  Position? _mechanicLocation;
  bool _isLoading = true;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _travelTime = "Calculating...";

  @override
  void initState() {
    super.initState();
    _setupMap();
  }

  Future<void> _setupMap() async {
    try {
      Position mechanicPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      LatLng userLatLng;
      if (widget.userLat != null && widget.userLon != null) {
        userLatLng = LatLng(widget.userLat!, widget.userLon!);
      } else {
        List<Location> locations = await locationFromAddress(widget.address);
        if (locations.isEmpty) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        userLatLng = LatLng(locations[0].latitude, locations[0].longitude);
      }

      // Show basic markers immediately
      final LatLng mechLatLng = LatLng(mechanicPos.latitude, mechanicPos.longitude);
      final mechanicIcon = await _createLollipopMarker();
      final userIconInitial = await _createUserDotMarker("Calculating...");

      if (mounted) {
        setState(() {
          _mechanicLocation = mechanicPos;
          _userLocation = userLatLng;
          _markers = {
            Marker(markerId: const MarkerId('mechanic_location'), position: mechLatLng, icon: mechanicIcon, anchor: const Offset(0.5, 1.0)),
            Marker(markerId: const MarkerId('user_location'), position: userLatLng, icon: userIconInitial, anchor: const Offset(0.5, 0.9)),
          };
          _isLoading = false;
        });
      }

      const String apiKey = "AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU";
      
      // Fetch duration & route (async)
      _updateRouteAndDuration(mechLatLng, userLatLng, apiKey, mechanicIcon);

    } catch (e) {
      debugPrint('Map error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRouteAndDuration(LatLng start, LatLng end, String apiKey, BitmapDescriptor mechanicIcon) async {
    String travelTime = "Calculated soon";

    // 1. Fetch Duration
    try {
      final String url = "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$apiKey";
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
          Marker(markerId: const MarkerId('mechanic_location'), position: start, icon: mechanicIcon, anchor: const Offset(0.5, 1.0)),
          Marker(markerId: const MarkerId('user_location'), position: end, icon: userIconUpdated, anchor: const Offset(0.5, 0.9)),
        };
      });
    }

    // 2. Fetch Polyline
    try {
      PolylinePoints polylinePoints = PolylinePoints(apiKey: apiKey);
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
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
                polylineId: const PolylineId("route"),
                color: Colors.red,
                points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                width: 5,
                jointType: JointType.round,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              )
            };
          } else {
            _polylines = {
              Polyline(
                polylineId: const PolylineId("fallback_route"),
                color: Colors.red,
                points: [start, end],
                width: 5,
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
    
    // Draw Pin Line
    final Paint linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(size / 2, size / 2), const Offset(size / 2, size), linePaint);

    // Draw Big Red Circle
    final Paint circlePaint = Paint()..color = Colors.red;
    canvas.drawCircle(const Offset(size / 2, size / 2), 35, circlePaint);

    // Draw White Dot in Center
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

    // 1. Draw Tooltip Box (White)
    final Paint boxPaint = Paint()..color = Colors.white;
    final RRect rRect = RRect.fromLTRBR(20, 0, width - 20, 60, const Radius.circular(12));
    
    // Shadow for tooltip
    canvas.drawRRect(rRect.shift(const Offset(0, 2)), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawRRect(rRect, boxPaint);

    // 2. Draw Tooltip Triangle
    final Path path = Path();
    path.moveTo(width / 2 - 10, 60);
    path.lineTo(width / 2, 75);
    path.lineTo(width / 2 + 10, 60);
    canvas.drawPath(path, boxPaint);

    // 3. Draw Duration Text
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: duration,
      style: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((width - textPainter.width) / 2, (60 - textPainter.height) / 2));

    // 4. Draw User Dot at Bottom
    final Paint dotOuterPaint = Paint()..color = Colors.black87;
    final Paint dotInnerPaint = Paint()..color = Colors.white;
    
    canvas.drawCircle(const Offset(width / 2, height - 30), 16, dotOuterPaint);
    canvas.drawCircle(const Offset(width / 2, height - 30), 12, dotInnerPaint);

    final img = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFB3300),
        title: Text(
          'Track Location',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading || _userLocation == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFB3300)))
          : GoogleMap(
              onMapCreated: (controller) => mapController = controller,
              initialCameraPosition: CameraPosition(
                target: _mechanicLocation != null
                    ? LatLng(_mechanicLocation!.latitude, _mechanicLocation!.longitude)
                    : _userLocation!,
                zoom: 14,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              markers: _markers,
              polylines: _polylines,
            ),
    );
  }
}
