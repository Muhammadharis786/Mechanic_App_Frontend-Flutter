import 'dart:convert';
import 'dart:async';
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
        _showSnackBar("Permissions permanently denied. Please enable them in settings.");
        setState(() => _isLoading = false);
        return;
      }

      // 3. Location fetch with fallback and timeout
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        setState(() => _statusMessage = "Getting location...");

        Position? position;
        
        try {
          // Try getting last known position first (very fast)
          position = await Geolocator.getLastKnownPosition();
          
          // If last known is null or we want fresh data, try current position with timeout
          position = await Geolocator.getCurrentPosition(
            locationSettings:  AndroidSettings(
              accuracy: LocationAccuracy.high,
              // Try without forceLocationManager first as it can hang on some devices
              forceLocationManager: false, 
            ),
          ).timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint("Primary location fetch failed: $e. Trying fallback...");
          
          // Fallback: Try with forceLocationManager: true if the first one failed/timed out
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings:  AndroidSettings(
                accuracy: LocationAccuracy.low, // Lower accuracy is often faster
                forceLocationManager: true,
              ),
            ).timeout(const Duration(seconds: 15));
          } catch (fallbackError) {
            debugPrint("Fallback location fetch failed: $fallbackError");
          }
        }

        if (position != null) {
          setState(() => _statusMessage = "Saving location...");
          await _updateLocationOnServer(position.latitude, position.longitude);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          _showSnackBar("Could not get location. Please ensure GPS is on and you are in an open area.");
        }
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
