import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:mech_app/screens/authentication/user_session.dart';

const String _mapStyle = '''
[
  {"featureType":"all","elementType":"labels.text.fill","stylers":[{"color":"#444444"}]},
  {"featureType":"landscape","elementType":"all","stylers":[{"color":"#f2f2f2"}]},
  {"featureType":"poi","elementType":"all","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"all","stylers":[{"saturation":-100},{"lightness":45}]},
  {"featureType":"water","elementType":"all","stylers":[{"color":"#c9d9e8"}]}
]
''';

const String _googleApiKey = 'AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with TickerProviderStateMixin {
  static const Color _primary = Color(0xFFFB3300);

  GoogleMapController? _mapController;

  LatLng _markerPos = const LatLng(24.8607, 67.0011);
  String? _locationLabel;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;
  bool _isLoading = false;
  late String _sessionToken;

  Timer? _debounce;
  Timer? _geoDebounce;

  bool _isDragging = false;

  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();

    _spinController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();

    _sessionToken = Uuid().v4();
    _getUserLocation();
    _fetchSuggestions('');

    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) {
        _fetchSuggestions(_searchCtrl.text);
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _geoDebounce?.cancel();
    super.dispose();
  }

  // ───────────────────────── GPS ─────────────────────────
  Future<void> _getUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      final latLng = LatLng(pos.latitude, pos.longitude);

      setState(() => _markerPos = latLng);

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 15),
      );
    } catch (e) {
      debugPrint("GPS error: $e");
    }
  }

  // ───────────────────────── SEARCH ─────────────────────────
  Future<void> _fetchSuggestions(String input) async {
    var query = input.trim();

    // Use Karachi as default query to show area suggestions even before typing
    if (query.isEmpty) {
      query = 'Karachi';
    }

    setState(() => _isLoading = true);

    try {
      // Karachi coordinates: 24.8607°N, 67.0011°E
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&key=$_googleApiKey'
          '&components=country:pk'
          '&language=en'
          '&locationbias=circle:50000@24.8607,67.0011'
          '&sessiontoken=$_sessionToken';

      debugPrint('🔍 Searching: $query');
      debugPrint('API URL: $url');

      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final status = data['status'];
        final preds = data['predictions'] ?? [];

        debugPrint('✅ API status: $status');
        debugPrint('✅ Found ${preds.length} suggestions');

        if (mounted) {
          setState(() {
            _suggestions = preds;
            _showSuggestions = preds.isNotEmpty;
            _isLoading = false;
          });
        }

        if (status != 'OK' && status != 'ZERO_RESULTS') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Google Places Error: $status'),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        debugPrint('❌ API Error: ${res.statusCode}');
        debugPrint('Response: ${res.body}');
        if (mounted) {
          setState(() {
            _suggestions = [];
            _showSuggestions = false;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Google Autocomplete request failed.'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Autocomplete error: $e");
      if (mounted) {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Autocomplete error. Please check your API key.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ───────────────────────── SELECT ─────────────────────────
  Future<void> _selectSuggestion(dynamic p) async {
    if (!mounted) return;

    final placeId = p['place_id'];
    final desc = p['description'];
    final messenger = ScaffoldMessenger.of(context);

    _searchFocus.unfocus();
    setState(() => _isLoading = true);

    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=geometry,formatted_address'
          '&key=$_googleApiKey'
          '&sessiontoken=$_sessionToken';

      debugPrint('📍 Getting details for: $placeId');
      
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final status = data['status'];

        debugPrint('📍 Details API status: $status');

        if (status == 'OK') {
          final loc = data['result']['geometry']['location'];
          final target = LatLng(loc['lat'], loc['lng']);

          if (mounted) {
            setState(() {
              _markerPos = target;
              _locationLabel = desc;
              _searchCtrl.text = desc;
              _suggestions = [];
              _showSuggestions = false;
              _isLoading = false;
            });

            debugPrint('✅ Location updated: ${loc['lat']}, ${loc['lng']}');
          }

          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(target, 16),
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📍 Location selected: $desc'),
                duration: Duration(seconds: 2),
                backgroundColor: Color(0xFFFB3300),
              ),
            );
          }
        } else {
          debugPrint('❌ Place Details Error: $status');
          throw Exception(status);
        }
      } else {
        debugPrint('❌ Details API Error: ${res.statusCode}');
        throw Exception('Failed to get location details');
      }
    } catch (e) {
      debugPrint("❌ Select error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ Error: Could not load location. Please try again.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _sessionToken = Uuid().v4();
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    try {
      final placeMarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placeMarks.isNotEmpty) {
        final p = placeMarks.first;
        final label = [
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country,
        ]
            .where((item) => item != null && item.isNotEmpty)
            .join(', ');

        if (mounted) {
          setState(() {
            _locationLabel = label.isNotEmpty ? label : 'Selected location';
          });
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  // ───────────────────────── CONFIRM ─────────────────────────
  Future<void> _confirm() async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_locationLabel == null || _locationLabel!.isEmpty) {
      await _reverseGeocode(_markerPos);
    }

    if (_locationLabel == null || _locationLabel!.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('⚠️ Please select a location first'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    UserSession().latitude = _markerPos.latitude;
    UserSession().longitude = _markerPos.longitude;
    UserSession().locationName = _locationLabel ?? '';

    debugPrint('✅ Location Saved:');
    debugPrint('  Name: $_locationLabel');
    debugPrint('  Latitude: ${_markerPos.latitude}');
    debugPrint('  Longitude: ${_markerPos.longitude}');

    navigator.pop({
      "latitude": _markerPos.latitude,
      "longitude": _markerPos.longitude,
      "locationName": _locationLabel ?? ''
    });
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAP
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _markerPos, zoom: 14),
            onMapCreated: (c) {
              _mapController = c;
              c.setMapStyle(_mapStyle);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onCameraMove: (pos) => _markerPos = pos.target,
            onCameraMoveStarted: () {
              setState(() => _isDragging = true);
              _searchFocus.unfocus();
            },
            onCameraIdle: () async {
              setState(() => _isDragging = false);
              await _reverseGeocode(_markerPos);
            },
            onTap: (latLng) async {
              setState(() => _markerPos = latLng);
              await _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
              await _reverseGeocode(latLng);
            },
          ),

          // CENTER PIN
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(Icons.location_on, size: 42, color: _primary),
                  ),
                ],
              ),
            ),
          ),

          // SEARCH BAR
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 400),
                        () => _fetchSuggestions(v),
                      );
                    },
                    decoration: InputDecoration(
                      hintText: "Search location in Karachi...",
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFFB3300)),
                      suffixIcon: _isLoading 
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB3300)),
                              ),
                            ),
                          )
                        : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFFFB3300), width: 2),
                      ),
                    ),
                  ),
                ),

                // SUGGESTIONS LIST
                if (_showSuggestions && _suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    constraints: const BoxConstraints(maxHeight: 320),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _suggestions.length,
                      separatorBuilder: (context, i) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = _suggestions[i];
                        final description = item['description'] ?? 'Unknown Location';
                        final mainText = item['structured_formatting']?['main_text'] ?? '';

                        return InkWell(
                          onTap: () {
                            debugPrint('📍 Selecting: $description');
                            _selectSuggestion(item);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFFFB3300), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mainText.isNotEmpty ? mainText : description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      if (description != mainText)
                                        Text(
                                          description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else if (_showSuggestions && _isLoading)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFB3300)),
                    ),
                  )
              ],
            ),
          ),

          // SELECTED LOCATION CARD
          if (_locationLabel != null && _locationLabel!.isNotEmpty)
            Positioned(
              left: 16,
              right: 72,
              bottom: 108,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: _primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationLabel!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // MY LOCATION
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _getUserLocation,
              child: Icon(Icons.my_location, color: _primary),
            ),
          ),

          // CONFIRM BUTTON
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: ElevatedButton(
              onPressed: _isDragging ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text("Confirm Location", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

