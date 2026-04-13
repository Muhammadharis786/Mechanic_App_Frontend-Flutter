import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import 'mechanic_dashboard.dart';
import '../authentication/user_session.dart';

class MechanicLocationScreen extends StatefulWidget {
  const MechanicLocationScreen({super.key});

  @override
  State<MechanicLocationScreen> createState() => _MechanicLocationScreenState();
}

class _MechanicLocationScreenState extends State<MechanicLocationScreen> {
  bool _isLoading = false;
  String _statusMessage = 'Enable location to receive nearby service requests.';

  Future<void> _updateLocationOnServer(double lat, double lng) async {
    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/currentlocation");

    try {
      final response = await http.post(
        url,
        headers: UserSession().getAuthHeader(),
        body: jsonEncode({
          "longitude": lng.toString(),
          "latitude": lat.toString(),
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Mechanic Location updated on server");
      } else {
        debugPrint("❌ Server Error: ${response.statusCode}");
        debugPrint("Response Check: ${response.body}");
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Network Error: $e");
      rethrow;
    }
  }

  Future<void> handleLocationPermission() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Getting location...";
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Location services are disabled. Please enable them.");
        setState(() => _isLoading = false);
        return;
      }

      // Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permissions are denied");
          setState(() => _isLoading = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permissions are permanently denied, we cannot request permissions.");
        setState(() => _isLoading = false);
        return;
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition();
      
      // Save to database
      setState(() => _statusMessage = "Saving location...");
      await _updateLocationOnServer(position.latitude, position.longitude);

      // Navigate to mechanic dashboard
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
      );
    } catch (e) {
      _showSnackBar("Error: $e");
      setState(() {
        _isLoading = false;
        _statusMessage = "Allow location access to continue using the app.";
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_outlined, size: 90, color: Color(0xFFFB3300)),
              const SizedBox(height: 20),
              Text(
                'Enable Location', 
                style: GoogleFonts.poppins(
                  fontSize: 26, 
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.titleLarge?.color
                )
              ),
              const SizedBox(height: 12),
              Text(
                _statusMessage, 
                textAlign: TextAlign.center, 
                style: GoogleFonts.poppins(
                  fontSize: 15, 
                  color: isDark ? Colors.white70 : Colors.black54
                )
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : handleLocationPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFB3300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : Text(
                          'Allow Access', 
                          style: GoogleFonts.poppins(
                            fontSize: 17, 
                            fontWeight: FontWeight.w600, 
                            color: Colors.white
                          )
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
