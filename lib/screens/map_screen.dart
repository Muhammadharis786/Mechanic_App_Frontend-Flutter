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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.serviceType} Mechanic Location"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Static Image Placeholder (Simulating Map)
          Image.asset(
            'assets/images/google_map.jpg', // Ensure this asset exists or use a network image/container
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.map, size: 80, color: Colors.grey),
                ),
              );
            },
          ),
          
          // 2. Overlay for "Finding Mechanics"
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.deepOrange),
                  const SizedBox(height: 12),
                  Text(
                    "Finding nearby ${widget.serviceType}...",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Please wait while we locate available mechanics.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
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
