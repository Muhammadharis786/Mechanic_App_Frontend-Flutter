import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MechanicUserMap extends StatefulWidget {
  final String address;
  // Optional: Direct lat/lon from DTO (skip geocoding if provided)
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
  BitmapDescriptor? _customMarker;
  bool _isLoading = true;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadMarker();
    _setupMap();
  }

  Future<void> _loadMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double width = 200.0;
    const double height = 120.0;

    final Paint paint = Paint()..color = const Color(0xFFFB3300);
    final RRect rRect = RRect.fromLTRBR(
        0, 0, width, height - 25, const Radius.circular(14));
    canvas.drawRRect(rRect, paint);

    final Path path = Path();
    path.moveTo(width / 2 - 16, height - 25);
    path.lineTo(width / 2, height);
    path.lineTo(width / 2 + 16, height - 25);
    canvas.drawPath(path, paint);

    TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: 'USER',
      style: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 1.2,
      ),
    );
    painter.layout();
    painter.paint(
        canvas, Offset((width - painter.width) / 2, (height - 25 - painter.height) / 2));

    final img = await pictureRecorder.endRecording().toImage(width.toInt(), height.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    if (mounted) {
      setState(() {
        _customMarker = BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
      });
    }
  }

  Future<void> _setupMap() async {
    try {
      // 1. Get mechanic's current GPS position
      Position mechanicPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      LatLng userLatLng;

      // 2. If lat/lon passed directly from DTO, use them. Otherwise geocode the address.
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

      // 3. Draw road route
      await _getPolyline(mechanicPos, userLatLng);

      if (mounted) {
        setState(() {
          _mechanicLocation = mechanicPos;
          _userLocation = userLatLng;

          _markers.add(Marker(
            markerId: const MarkerId('user_location'),
            position: userLatLng,
            icon: _customMarker ?? BitmapDescriptor.defaultMarker,
            anchor: const Offset(0.5, 1.0),
            infoWindow: InfoWindow(title: 'Customer Address', snippet: widget.address),
          ));

          _markers.add(Marker(
            markerId: const MarkerId('mechanic_location'),
            position: LatLng(mechanicPos.latitude, mechanicPos.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'My Location'),
          ));

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Map error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getPolyline(Position start, LatLng end) async {
    PolylinePoints polylinePoints = PolylinePoints(apiKey: "AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU");
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(start.latitude, start.longitude),
        destination: PointLatLng(end.latitude, end.longitude),
        mode: TravelMode.driving,
      ),
    );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates =
            result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();

        _polylines.add(Polyline(
          polylineId: const PolylineId("route"),
          color: Colors.red,
          points: polylineCoordinates,
          width: 5,
        ));
      } else {
        debugPrint("❌ Map Route Error: ${result.errorMessage}");
        debugPrint("❌ Map Route Status: ${result.status}");
        // Fallback: straight dashed red line
        _polylines.add(Polyline(
          polylineId: const PolylineId("fallback_route"),
          color: Colors.red,
          points: [
            LatLng(start.latitude, start.longitude),
            LatLng(end.latitude, end.longitude),
          ],
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ));
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFB3300),
        title: Text(
          'User Location',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
          ),
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