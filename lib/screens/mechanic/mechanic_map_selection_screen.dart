import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MechanicMapSelectionScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MechanicMapSelectionScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MechanicMapSelectionScreen> createState() => _MechanicMapSelectionScreenState();
}

class _MechanicMapSelectionScreenState extends State<MechanicMapSelectionScreen> {
  GoogleMapController? _mapController;
  LatLng _centerPosition = const LatLng(24.8607, 67.0011);
  bool _isLoading = false;
  String _currentAddress = "Move map to select location";
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placeList = [];
  final String _googleApiKey = "AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU";
  String _sessionToken = '1234567890';

  final Color primaryColor = const Color(0xFFFB3300);

  @override
  void initState() {
    super.initState();
    _sessionToken = const Uuid().v4();
    if (widget.initialLat != null && widget.initialLng != null) {
      _centerPosition = LatLng(widget.initialLat!, widget.initialLng!);
      _getAddressFromLatLng(_centerPosition);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _centerPosition = LatLng(position.latitude, position.longitude);
      });
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_centerPosition),
      );
      _getAddressFromLatLng(_centerPosition);
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}".replaceAll(RegExp(r'^, |, $'), '');
        });
      }
    } catch (e) {
      debugPrint("Error geocoding: $e");
    }
  }

  Future<void> _searchAndMove(String address) async {
    if (address.isEmpty) return;
    setState(() {
      _isLoading = true;
      _placeList = [];
    });
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        LatLng newPos = LatLng(loc.latitude, loc.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));
        setState(() {
          _centerPosition = newPos;
        });
        _getAddressFromLatLng(newPos);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error finding location: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _getSuggestion(String input) async {
    if (input.isEmpty) {
      setState(() => _placeList = []);
      return;
    }
    String request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_googleApiKey&sessiontoken=$_sessionToken';
    
    try {
      var response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        setState(() {
          _placeList = json.decode(response.body)['predictions'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching predictions: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Select Location",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _centerPosition,
              zoom: 14.0,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onCameraMove: (CameraPosition position) {
              _centerPosition = position.target;
            },
            onCameraIdle: () {
              _getAddressFromLatLng(_centerPosition);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            // Dark mode map styling could be added here if JSON exists
          ),
          
          // Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Icon(Icons.location_on_outlined, color: primaryColor, size: 50),
            ),
          ),
          
          // Search Bar & Suggestions
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black45 : Colors.black12,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color),
                    textInputAction: TextInputAction.search,
                    onChanged: _getSuggestion,
                    onSubmitted: _searchAndMove,
                    decoration: InputDecoration(
                      hintText: "Search location...",
                      hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white38 : Colors.grey),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      suffixIcon: IconButton(
                        icon: _isLoading 
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                            : Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _placeList = []);
                        },
                      ),
                    ),
                  ),
                ),
                if (_placeList.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _placeList.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: Icon(Icons.location_on_outlined, color: primaryColor, size: 20),
                          title: Text(
                            _placeList[index]["description"],
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            _searchController.text = _placeList[index]["description"];
                            _searchAndMove(_searchController.text);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          // Current Location Button
          Positioned(
            bottom: 150,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'my_location_btn',
              backgroundColor: isDark ? Colors.grey[850] : Colors.white,
              onPressed: _getCurrentLocation,
              child: Icon(Icons.my_location_outlined, color: primaryColor),
            ),
          ),
          
          // Bottom Info & Confirm
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black54 : Colors.black12,
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: primaryColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        "Selected Location",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentAddress,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context, {
                        'latitude': _centerPosition.latitude,
                        'longitude': _centerPosition.longitude,
                        'address': _currentAddress,
                      });
                    },
                    child: Text(
                      "Confirm Location",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
