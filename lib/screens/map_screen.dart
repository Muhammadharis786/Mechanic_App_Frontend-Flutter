// map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';

class MapScreen extends StatefulWidget {
  final String serviceType;

  const MapScreen({super.key, required this.serviceType});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  String darkMapStyle = '';

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    darkMapStyle = await rootBundle.loadString('assets/map/map_style_dark.json ');
  }

  void _onMapCreated(GoogleMapController controller) {
  mapController = controller;
  _setMapStyle(); // 👈 yahan call karo
}
void _setMapStyle() {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  if (mapController == null) return;

  if (isDark) {
    mapController!.setMapStyle(darkMapStyle);
  } else {
    mapController!.setMapStyle(null);
  }
}

 @override
void didChangeDependencies() {
  super.didChangeDependencies();
  _setMapStyle(); // 👈 theme change pe auto update
}
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text("${widget.serviceType} Mechanic Location"),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // ✅ REAL GOOGLE MAP
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(24.8607, 67.0011), // Karachi
              zoom: 14,
            ),
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
          ),

          // Overlay Card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.deepOrange),
                  const SizedBox(height: 12),
                  Text(
                    "Finding nearby ${widget.serviceType}...",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Please wait while we locate available mechanics.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.grey,
                      fontSize: 13,
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
}