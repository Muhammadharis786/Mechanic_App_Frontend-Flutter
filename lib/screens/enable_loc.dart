import 'dart:convert';
import 'dart:async'; // Required for Timer
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
 
import 'homescreen.dart'; 
import 'user_session.dart'; 

class EnableLocationScreen extends StatefulWidget {
  const EnableLocationScreen({super.key});

  @override
  State<EnableLocationScreen> createState() => _EnableLocationScreenState();
}

class _EnableLocationScreenState extends State<EnableLocationScreen> {
  bool _isLoading = false;
  String _statusMessage = 'Allow location access to continue using the app.';

  // API Call to update location on server
  Future<void> _updateLocationOnServer(double lat, double lng) async {
    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/current/location");

    try {
      final response = await http.post(
        url,
        headers: UserSession().getAuthHeader(), 
        body: jsonEncode({
          "latitude": lat,
          "longitude": lng,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Location updated on server");
      } else {
        debugPrint("❌ Server Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Network Error: $e");
    }
  }

  Future<void> handleLocationPermission() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Checking permissions...";
    });

    try {
      // 1. Service check
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        setState(() => _isLoading = false);
        return;
      }

      // 2. Permission check
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permission denied");
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Permissions permanently denied");
        setState(() => _isLoading = false);
        return;
      }

      // 3. Simple location fetch
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        setState(() => _statusMessage = "Getting location...");

        AndroidSettings androidSettings = AndroidSettings(
          accuracy: LocationAccuracy.high, // Changed to high for generally better results without loop
          forceLocationManager: true,
        );

        Position position = await Geolocator.getCurrentPosition(
            locationSettings: androidSettings);

        setState(() => _statusMessage = "Saving location...");
        await _updateLocationOnServer(position.latitude, position.longitude);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_rounded, size: 90, color: Color(0xFFFB3300)),
              const SizedBox(height: 20),
              const Text('Enable Location', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.black54)),
              const SizedBox(height: 35),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : handleLocationPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFB3300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Allow', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 