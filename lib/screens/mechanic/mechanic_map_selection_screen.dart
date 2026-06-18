import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// ────────────────────────────────────────────────────────────────
//  Simple greyscale map style – no rivers, trees, or POI colors
// ────────────────────────────────────────────────────────────────
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

class MechanicMapSelectionScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MechanicMapSelectionScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MechanicMapSelectionScreen> createState() => _MechanicMapSelectionScreenState();
}

class _MechanicMapSelectionScreenState extends State<MechanicMapSelectionScreen>
    with TickerProviderStateMixin {
  // ── Colors ──────────────────────────────────────────────────────
  static const Color _primary = Color(0xFFFB3300);

  // ── Map ─────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng _markerPos = const LatLng(24.8607, 67.0011); // Karachi default
  bool _isDragging = false;
  String? _locationLabel;

  // ── Spinner animation ────────────────────────────────────────────
  late AnimationController _spinController;

  // ── Search ───────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<dynamic> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;

  // ── Reverse-geocode debounce ─────────────────────────────────────
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

    if (widget.initialLat != null && widget.initialLng != null) {
      _markerPos = LatLng(widget.initialLat!, widget.initialLng!);
      _reverseGeocode(_markerPos);
    } else {
      _getUserLocation();
    }
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

  // ── Get user's GPS location ──────────────────────────────────────
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
      setState(() => _markerPos = newPos);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 14));
      _reverseGeocode(newPos);
    } catch (_) {}
  }

  // ── Reverse geocode via Places API ──────────────────────────────
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

  // ── Places Autocomplete ──────────────────────────────────────────
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
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 14));
        _searchFocus.unfocus();
      }
    } catch (_) {}
  }

  // ── Confirm and pop ──────────────────────────────────────────────
  void _confirm() {
    Navigator.pop(context, {
      'latitude': _markerPos.latitude,
      'longitude': _markerPos.longitude,
      'address': _locationLabel ?? '',
    });
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────
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

          // ── Center lollipop marker ──────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMarkerWidget(),
                // Lollipop stick
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Shadow dot under stick
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

          // ── Tooltip above marker ─────────────────────────────────
          if (_locationLabel != null && !_isDragging)
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 80),
                child: _buildTooltip(_locationLabel!),
              ),
            ),

          // ── Top bar: back + search ──────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                if (_showSuggestions) _buildSuggestionsList(),
              ],
            ),
          ),

          // ── My location FAB ─────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 120,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _getUserLocation,
              child: Icon(Icons.my_location_rounded, color: _primary),
            ),
          ),

          // ── Confirm button ───────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(
                  fontFamily: 'YandexSansText',
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

  // ── Lollipop head (with spinner border when dragging) ────────────
  Widget _buildMarkerWidget() {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spinning dashed border when dragging
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
          // White circle background
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

  // ── Tooltip chip ─────────────────────────────────────────────────
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
          fontFamily: 'YandexSansText',
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Back button
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
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFFFB3300), size: 18),
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
                    fontFamily: 'YandexSansText', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search location...',
                  hintStyle: TextStyle(
                      fontFamily: 'YandexSansText',
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
                  setState(() {}); // for suffix icon
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggestions dropdown ─────────────────────────────────────────
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
                                fontFamily: 'YandexSansText',
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
                                  fontFamily: 'YandexSansText',
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

// ── Dashed circle painter for spinner ────────────────────────────
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
