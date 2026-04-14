import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'homescreen.dart'; 
import 'authentication/user_session.dart'; 

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
      _statusMessage = "Getting location...";
    });

    try {
      LocationPermission permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permission is required");
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() => _statusMessage = "Saving location...");
      await _updateLocationOnServer(position.latitude, position.longitude);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _showSnackBar("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Detect current theme
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey[400] : Colors.black54;
    final buttonColor = const Color(0xFFFB3300);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_rounded, size: 90, color: buttonColor),
              const SizedBox(height: 20),
              Text('Enable Location', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 12),
              Text(_statusMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: subTextColor)),
              const SizedBox(height: 35),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : handleLocationPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
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