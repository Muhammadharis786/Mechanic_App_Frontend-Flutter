import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../widgets/app_back_button.dart';
import '../../utils/map_theme_helper.dart';

class AppointmentTrackingMap extends StatefulWidget {
  final double userLat;
  final double userLng;
  final double? mechLat;
  final double? mechLng;
  final String? mechanicName;
  final String? address;

  const AppointmentTrackingMap({
    super.key,
    required this.userLat,
    required this.userLng,
    this.mechLat,
    this.mechLng,
    this.mechanicName,
    this.address,
  });

  @override
  State<AppointmentTrackingMap> createState() => _AppointmentTrackingMapState();
}

class _AppointmentTrackingMapState extends State<AppointmentTrackingMap> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  
  // API Key from mechanic_usermap.dart
  final String _apiKey = "AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU";

  // Refined Yango Map Style (Clean, Minimalist, Light Grey/White with building structures)
  final String _mapStyle = jsonEncode([
    {
      "featureType": "all",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#616161"}]
    },
    {
      "featureType": "all",
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#f5f5f5"}]
    },
    {
      "featureType": "administrative.land_parcel",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#bdbdbd"}]
    },
    {
      "featureType": "landscape",
      "elementType": "geometry",
      "stylers": [{"color": "#f5f5f5"}, {"lightness": 20}]
    },
    {
      "featureType": "landscape.man_made",
      "elementType": "geometry",
      "stylers": [{"color": "#e0e0e0"}]
    },
    {
      "featureType": "poi",
      "elementType": "geometry",
      "stylers": [{"color": "#eeeeee"}]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#757575"}]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [{"color": "#e5e5e5"}]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#9e9e9e"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#ffffff"}]
    },
    {
      "featureType": "road.arterial",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#757575"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [{"color": "#dadada"}]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#616161"}]
    },
    {
      "featureType": "road.local",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#9e9e9e"}]
    },
    {
      "featureType": "transit.line",
      "elementType": "geometry",
      "stylers": [{"color": "#e5e5e5"}]
    },
    {
      "featureType": "transit.station",
      "elementType": "geometry",
      "stylers": [{"color": "#eeeeee"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#c9c9c9"}]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#9e9e9e"}]
    },
    {
      "featureType": "landscape.natural.landcover",
      "elementType": "geometry",
      "stylers": [{"color": "#f5f5f5"}]
    },
    {
      "featureType": "landscape.natural.terrain",
      "elementType": "geometry",
      "stylers": [{"color": "#f5f5f5"}]
    },
    {
      "featureType": "landscape.man_made",
      "elementType": "labels.text.fill",
      "stylers": [{"color": "#616161"}]
    },
    {
      "featureType": "landscape.man_made",
      "elementType": "labels.text.stroke",
      "stylers": [{"color": "#f5f5f5"}]
    }
  ]);

  @override
  void initState() {
    super.initState();
    _initMapElements();
  }

  void _initMapElements() async {
    final userLocationIcon = await _createUserLocationIcon();
    final destinationIcon = await _createYangoMarker();
    final whiteDot = await _createWhiteDotIcon();

    if (mounted) {
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: LatLng(widget.userLat, widget.userLng),
            icon: userLocationIcon,
            anchor: const Offset(0.5, 0.5),
          ),
        );

        if (widget.mechLat != null && widget.mechLng != null) {
          _markers.add(
            Marker(
              markerId: const MarkerId('mechanic_location'),
              position: LatLng(widget.mechLat!, widget.mechLng!),
              icon: destinationIcon,
              anchor: const Offset(0.5, 0.5), // Center for circle marker
            ),
          );
          
          // Initial fallback path
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('fallback_path'),
              points: [LatLng(widget.userLat, widget.userLng), LatLng(widget.mechLat!, widget.mechLng!)],
              color: const Color(0xFF2B21F5),
              width: 6,
              patterns: [PatternItem.dash(15), PatternItem.gap(10)],
            ),
          );

          _fetchRoadWisePath(whiteDot);
        }
      });
    }
  }

  Future<void> _fetchRoadWisePath(BitmapDescriptor whiteDot) async {
    if (widget.mechLat == null || widget.mechLng == null) return;

    try {
      PolylinePoints polylinePoints = PolylinePoints(apiKey: _apiKey);
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(widget.userLat, widget.userLng),
          destination: PointLatLng(widget.mechLat!, widget.mechLng!),
          mode: TravelMode.driving,
        ),
      );

      if (mounted && result.points.isNotEmpty) {
        setState(() {
          _polylines.clear();
          final List<LatLng> points = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('tracking_path'),
              points: points,
              color: const Color(0xFF2B21F5),
              width: 8,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          );

          // Add white dots at turns
          for (int i = 0; i < points.length; i++) {
            _markers.add(
              Marker(
                markerId: MarkerId('turn_$i'),
                position: points[i],
                icon: whiteDot,
                anchor: const Offset(0.5, 0.5),
                zIndex: 1,
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint("⚠️ Path Fetch Error: $e");
    }
  }

  Future<BitmapDescriptor> _createYangoMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0;

    // Red Circle (Yango Style)
    final Paint pinPaint = Paint()..color = Colors.red;
    canvas.drawCircle(const Offset(size / 2, size / 2), 30, pinPaint);
    
    // White dot inside
    canvas.drawCircle(const Offset(size / 2, size / 2), 10, Paint()..color = Colors.white);

    // Stem (Line below)
    final Paint stemPaint = Paint()..color = Colors.red..strokeWidth = 4..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(size / 2, size / 2 + 30), const Offset(size / 2, size / 2 + 60), stemPaint);

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createUserLocationIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 60.0;

    // Black Border
    final Paint borderPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), 12, borderPaint);

    // White Inner Circle
    final Paint centerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), 9, centerPaint);

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createWhiteDotIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 20.0;

    final Paint paint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(size / 2, size / 2), 6, paint);

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    MapThemeHelper.applyMapTheme(controller, context);
    _fitBounds();
  }

  void _fitBounds() {
    if (widget.mechLat == null || widget.mechLng == null) return;

    final LatLng sw = LatLng(
      widget.userLat < widget.mechLat! ? widget.userLat : widget.mechLat!,
      widget.userLng < widget.mechLng! ? widget.userLng : widget.mechLng!,
    );
    final LatLng ne = LatLng(
      widget.userLat > widget.mechLat! ? widget.userLat : widget.mechLat!,
      widget.userLng > widget.mechLng! ? widget.userLng : widget.mechLng!,
    );
    
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 80));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_mapController != null) {
      MapThemeHelper.applyMapTheme(_mapController!, context);
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Tracking Mechanic",
          style: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? Colors.white : Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: isDark ? Colors.black54 : Colors.white70,
            child: const AppBackButton(),
          ),
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(widget.userLat, widget.userLng), zoom: 17), // Increased zoom for building details
        markers: _markers,
        polylines: _polylines,
        circles: _circles,
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        padding: const EdgeInsets.only(top: 100),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFB3300),
        child: const Icon(Icons.my_location, color: Colors.white),
        onPressed: () => _fitBounds(),
      ),
    );
  }
}
