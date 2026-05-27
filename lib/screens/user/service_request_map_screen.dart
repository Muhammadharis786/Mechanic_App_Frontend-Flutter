import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../authentication/user_session.dart';

const String _mapStyle = '''
[
  {"featureType":"all","elementType":"labels.text.fill","stylers":[{"color":"#444444"}]},
  {"featureType":"landscape","elementType":"all","stylers":[{"color":"#f2f2f2"}]},
  {"featureType":"poi","elementType":"all","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"all","stylers":[{"saturation":-100},{"lightness":45}]},
  {"featureType":"road.highway","elementType":"all","stylers":[{"visibility":"simplified"}]},
  {"featureType":"road.arterial","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","elementType":"all","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"all","stylers":[{"color":"#c9d9e8"},{"visibility":"on"}]}
]
''';

const String _googleApiKey = 'AIzaSyBpyZg2i30gOLUKK0furYdGDbWXe4lqpkU';

class ServiceRequestMapScreen extends StatefulWidget {
  final String serviceType;
  final String userNotes;

  const ServiceRequestMapScreen({
    super.key,
    required this.serviceType,
    required this.userNotes,
  });

  @override
  State<ServiceRequestMapScreen> createState() => _ServiceRequestMapScreenState();
}

class _ServiceRequestMapScreenState extends State<ServiceRequestMapScreen>
    with TickerProviderStateMixin {
  
  static const Color _primary = Color(0xFFFB3300);

  GoogleMapController? _mapController;
  LatLng _markerPos = const LatLng(24.8607, 67.0011); 
  bool _isDragging = false;
  String? _locationLabel;
  bool _isLoading = false;

  late AnimationController _spinController;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<dynamic> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;
  Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });

    _initializePosition();
  }

  void _initializePosition() {
    final savedLat = UserSession().latitude;
    final savedLng = UserSession().longitude;

    if (savedLat != null && savedLng != null) {
      _markerPos = LatLng(savedLat, savedLng);
    }
    _getUserLocation();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    _geocodeDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final newPos = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _markerPos = newPos);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 14));
        _reverseGeocode(newPos);
      }
    } catch (_) {}
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${pos.latitude},${pos.longitude}&key=$_googleApiKey';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final name = data['results'][0]['formatted_address'] as String;
          if (mounted) setState(() => _locationLabel = name);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$_googleApiKey&language=en';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _suggestions = data['predictions'] ?? [];
            _showSuggestions = _suggestions.isNotEmpty;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _selectSuggestion(dynamic prediction) async {
    final placeId = prediction['place_id'];
    final description = prediction['description'] as String;
    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_googleApiKey';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final loc = data['result']['geometry']['location'];
        final newPos = LatLng(loc['lat'], loc['lng']);
        setState(() {
          _markerPos = newPos;
          _locationLabel = description;
          _suggestions = [];
          _showSuggestions = false;
          _searchCtrl.text = description;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));
        _searchFocus.unfocus();
      }
    } catch (_) {}
  }

  String _mapServiceCategory(String category) {
    if (category.toLowerCase().contains("bike")) return "BIKE";
    if (category.toLowerCase().contains("car")) return "CAR";
    if (category.toLowerCase().contains("puncher")) return "PUNCHER";
    return "OTHER";
  }

  Future<void> _sendServiceRequest() async {
    if (_locationLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the location to resolve.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final String mappedServiceType = _mapServiceCategory(widget.serviceType);
    final String userPhoneNumber = UserSession().email ?? "";

    final payload = {
      "serviceType": mappedServiceType,
      "userNotes": widget.userNotes,
      "userphonenumber": userPhoneNumber,
      "userLatitude": _markerPos.latitude,
      "userLongitude": _markerPos.longitude,
      "locationName": _locationLabel
    };

    try {
      final response = await http.post(
        Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/create"),
        headers: {
          'Content-Type': 'application/json',
          ...UserSession().getAuthHeader(),
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text('Service Request Sent Successfully!'), 
               backgroundColor: Colors.green.shade600
             ),
           );
           // Pop to Home Screen
           Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Failed: ${response.body}')),
           );
        }
      }
    } catch(e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Request Error: $e')),
         );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) {
              _mapController = c;
              c.setMapStyle(_mapStyle);
            },
            initialCameraPosition: CameraPosition(
              target: _markerPos,
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            onCameraMoveStarted: () {
              setState(() {
                _isDragging = true;
                _locationLabel = null;
              });
            },
            onCameraMove: (pos) {
              setState(() => _markerPos = pos.target);
            },
            onCameraIdle: () {
              setState(() => _isDragging = false);
              _geocodeDebounce?.cancel();
              _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
                _reverseGeocode(_markerPos);
              });
            },
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMarkerWidget(),
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 10,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

          if (_locationLabel != null && !_isDragging)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: _buildTooltip(_locationLabel!),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                if (_showSuggestions) _buildSuggestionsList(),
              ],
            ),
          ),

          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _getUserLocation,
              child: const Icon(Icons.my_location_rounded, color: _primary),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendServiceRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: _isLoading 
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Text(
                'Send Request',
                style: TextStyle(
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerWidget() {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isDragging)
            AnimatedBuilder(
              animation: _spinController,
              builder: (_, __) => Transform.rotate(
                angle: _spinController.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(56, 56),
                  painter: _DashedCirclePainter(color: _primary),
                ),
              ),
            ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: _isDragging ? Colors.transparent : _primary,
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.location_pin,
              color: _primary,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Bricolage Grotesque',
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 6)
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.black87, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8)
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                style: const TextStyle(
                    fontFamily: 'Bricolage Grotesque', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search location...',
                  hintStyle: TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      color: Colors.grey.shade500,
                      fontSize: 13),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: _primary, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _suggestions = [];
                              _showSuggestions = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    _fetchSuggestions(v);
                  });
                  setState(() {});
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _suggestions.take(5).map((p) {
              final desc = p['description'] as String;
              final main = p['structured_formatting']?['main_text'] as String?
                  ?? desc;
              final secondary =
                  p['structured_formatting']?['secondary_text'] as String?;
              return InkWell(
                onTap: () => _selectSuggestion(p),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: _primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              main,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (secondary != null)
                              Text(
                                secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Bricolage Grotesque',
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const dashCount = 10;
    const dashAngle = math.pi * 2 / dashCount;
    const gapFraction = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final start = dashAngle * i;
      final sweep = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
