import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  LatLng _centerPosition = const LatLng(24.8607, 67.0011); // Default to Karachi or Pakistan
  bool _isLoading = false;
  String _currentAddress = "Move map to select location";
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _placeList = [];
  final String _googleApiKey = "AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU"; // Using the API key from AndroidManifest.xml
  String _sessionToken = '1234567890'; // Default, will be reset in initState

  final Color primary = const Color(0xFFFB3300);

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
      // Handle error
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _currentAddress = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}".replaceAll(RegExp(r'^, |, $'), '');
          // clean up trailing or leading commas if some fields are empty
        });
      }
    } catch (e) {
      // Ignore or log error
    }
  }

  Future<void> _searchAndMove(String address) async {
    if (address.isEmpty) return;
    setState(() {
      _isLoading = true;
      _placeList = []; // Hide suggestions when searching
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
      setState(() {
        _placeList = [];
      });
      return;
    }
    String request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_googleApiKey&sessiontoken=$_sessionToken';
    
    // Public cors-anywhere returns 403 by default without visiting /corsdemo.
    // Try hitting API directly first. If Web fails CORS, browser console will mention it.
    // In production, you would use a backend or allow your domain in Google Cloud Console.
    /*
    if (kIsWeb) {
      request = 'https://cors-anywhere.herokuapp.com/' + request;
    }
    */
    
    try {
      var response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        setState(() {
          _placeList = json.decode(response.body)['predictions'];
        });
      } else {
        throw Exception('Failed to load predictions. Status Code: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      debugPrint("Error fetching predictions: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Select Location", style: GoogleFonts.poppins()),
        backgroundColor: primary,
        foregroundColor: Colors.white,
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
          ),
          
          // Center Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40.0), // Adjust to center the pin correctly
              child: Icon(Icons.location_on, color: primary, size: 50),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      _getSuggestion(value);
                    },
                    onSubmitted: _searchAndMove,
                    decoration: InputDecoration(
                      hintText: "Search location...",
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _placeList = [];
                          });
                        },
                      ),
                    ),
                  ),
                ),
                if (_placeList.isNotEmpty)
                  Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _placeList.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                            title: Text(
                              _placeList[index]["description"],
                              style: GoogleFonts.poppins(fontSize: 14),
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
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: Icon(Icons.my_location, color: primary),
            ),
          ),
          
          // Bottom Info & Confirm
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      Icon(Icons.place, color: primary, size: 20),
                      const SizedBox(width: 8),
                      Text("Selected Location", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_currentAddress, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        // Return the selected location data
                        Navigator.pop(context, {
                          'latitude': _centerPosition.latitude,
                          'longitude': _centerPosition.longitude,
                          'address': _currentAddress,
                        });
                      },
                      child: Text("Confirm Location", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
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
