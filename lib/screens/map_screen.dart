// map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final String serviceType;

  const MapScreen({super.key, required this.serviceType});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {

  final List<Marker> _markers = [
    const Marker(
      markerId: MarkerId('mechanic1'),
      position: LatLng(24.8607, 67.0011),
      infoWindow: InfoWindow(title: "Mechanic 1"),
    ),
    const Marker(
      markerId: MarkerId('mechanic2'),
      position: LatLng(24.8700, 67.0100),
      infoWindow: InfoWindow(title: "Mechanic 2"),
    ),
    const Marker(
      markerId: MarkerId('mechanic3'),
      position: LatLng(24.8550, 67.0200),
      infoWindow: InfoWindow(title: "Mechanic 3"),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.serviceType} Mechanic Location"),
        backgroundColor: Colors.deepOrange,
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(24.8607, 67.0011),
          zoom: 12,
        ),
        markers: Set<Marker>.of(_markers),
        onMapCreated: (controller) {
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
