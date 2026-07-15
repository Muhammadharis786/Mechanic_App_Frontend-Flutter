// ignore_for_file: unused_element

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mech_app/screens/authentication/user_session.dart';
import 'package:mech_app/screens/homescreen.dart';
import 'package:mech_app/screens/user/booking_confirmation_screen.dart';
import 'package:mech_app/screens/user/location_picker_screen.dart';
import 'package:mech_app/screens/user/mechanic_list_book_appointment.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mech_app/widgets/app_back_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

const String _baseUrl =
    'https://mechanicapp-service-621632382478.asia-south1.run.app';

class BookAppointmentScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialLocationName;

  const BookAppointmentScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialLocationName,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  // ── Location ────────────────────────────────────────────────────
  double? _latitude;
  double? _longitude;
  String? _locationName;
  bool _isFetchingCurrentLocation = false;
  bool _isUsingCurrentLocation = false;

  // ── Form ─────────────────────────────────────────────────────────
  String selectedService = "All";
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final TextEditingController addressController = TextEditingController();
  final TextEditingController detailController = TextEditingController();
  Map<String, dynamic>? selectedMechanic;
  bool _isAutoMode = true; // Default to Auto Assign

  // ── Mechanics from API ───────────────────────────────────────────
  List<Map<String, dynamic>> _mechanics = [];
  bool _loadingMechanics = false;
  bool _bookingInProgress = false; // New state for full screen transition
  String? _mechanicsError;

  final List<Map<String, dynamic>> services = [
    {"label": "All", "icon": Icons.handyman_outlined},
    {"label": "Puncher", "icon": Icons.tire_repair_outlined},
    {"label": "Bike Mechanic", "icon": Icons.two_wheeler_outlined},
    {"label": "Car Mechanic", "icon": Icons.directions_car_outlined},
  ];

  List<Map<String, dynamic>> get _filteredMechanics {
    if (selectedService == "All") return _mechanics;
    return _mechanics
        .where((m) => (m['mechanictype'] ?? '').toString() == selectedService)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _latitude = widget.initialLat;
      _longitude = widget.initialLng;
      _locationName = widget.initialLocationName;
      addressController.text = widget.initialLocationName ?? '';
      _saveLocationToPrefs(widget.initialLat!, widget.initialLng!, widget.initialLocationName, isCurrent: false);
      _fetchNearbyMechanics();
    } else {
      _loadSavedLocation();
    }
  }

  @override
  void dispose() {
    addressController.dispose();
    detailController.dispose();
    super.dispose();
  }

  Future<void> _saveLocationToPrefs(double lat, double lng, String? name, {bool isCurrent = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('book_lat', lat);
      await prefs.setDouble('book_lng', lng);
      if (name != null) {
        await prefs.setString('book_loc_name', name);
      } else {
        await prefs.remove('book_loc_name');
      }
      await prefs.setBool('book_is_current', isCurrent);
    } catch (e) {
      debugPrint("Error saving location to prefs: $e");
    }
  }

  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('book_lat');
      final lng = prefs.getDouble('book_lng');
      final locName = prefs.getString('book_loc_name');
      final isCurrent = prefs.getBool('book_is_current') ?? false;

      if (lat != null && lng != null) {
        setState(() {
          _latitude = lat;
          _longitude = lng;
          _locationName = locName;
          addressController.text = locName ?? '';
          _isUsingCurrentLocation = isCurrent;
        });
        _fetchNearbyMechanics();
      }
    } catch (e) {
      debugPrint("Error loading saved location: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isFetchingCurrentLocation) return;
    setState(() {
      _isFetchingCurrentLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location services are disabled. Please enable them.")),
        );
        setState(() => _isFetchingCurrentLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permissions are denied.")),
          );
          setState(() => _isFetchingCurrentLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions are permanently denied.")),
        );
        setState(() => _isFetchingCurrentLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placeMarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String finalLabel = "Karachi";
      if (placeMarks.isNotEmpty) {
        final p = placeMarks.first;
        final label = [
          p.subLocality,
          p.locality,
        ]
            .where((item) => item != null && item.isNotEmpty)
            .join(', ');

        if (label.isNotEmpty) {
          finalLabel = label;
        } else if (p.name != null && p.name!.isNotEmpty) {
          finalLabel = p.name!;
        }
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationName = finalLabel;
        addressController.text = finalLabel;
        _mechanics = [];
        selectedMechanic = null;
        _mechanicsError = null;
        _isFetchingCurrentLocation = false;
        _isUsingCurrentLocation = true;
      });

      await _saveLocationToPrefs(position.latitude, position.longitude, finalLabel, isCurrent: true);
      _fetchNearbyMechanics();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location updated to: $finalLabel")),
      );
    } catch (e) {
      debugPrint("Error fetching current location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch location: $e")),
      );
      setState(() {
        _isFetchingCurrentLocation = false;
      });
    }
  }

  // ── Open Map Picker ──────────────────────────────────────────────
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      final lat = result['latitude'] as double;
      final lng = result['longitude'] as double;
      final locName = result['locationName'] as String?;
      setState(() {
        _latitude = lat;
        _longitude = lng;
        _locationName = locName;
        addressController.text = _locationName ?? '';
        _mechanics = [];
        selectedMechanic = null;
        _mechanicsError = null;
        _isUsingCurrentLocation = false;
      });
      await _saveLocationToPrefs(lat, lng, locName, isCurrent: false);
      _fetchNearbyMechanics();
    }
  }

  // ── POST /api/user/bookappointment/nearbymechanics ──────────────
  Future<void> _fetchNearbyMechanics() async {
    if (_latitude == null || _longitude == null) return;
    setState(() {
      _loadingMechanics = true;
      _mechanicsError = null;
    });
    try {
      final url = Uri.parse(
          '$_baseUrl/api/user/bookappointment/nearbymechanics');
      final response = await http.post(
        url,
        headers: {
          ...UserSession().getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': _latitude,
          'longitude': _longitude,
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body);
        setState(() {
          _mechanics = raw.map((m) {
            // Normalize ALL keys to lowercase to be safe
            final map = (m as Map<String, dynamic>)
                .map((k, v) => MapEntry(k.toLowerCase(), v));

            // Ensure 'id' is populated from any possible source
            map['id'] = map['id'] ?? map['userid'] ?? map['mechanicid'] ?? 0;
            return map;
          }).toList();

          // Ensure sorting by Subscription Tier: Ultra Premium > Premium > Free
          _mechanics.sort((a, b) {
            int getPlanWeight(Map<String, dynamic> mech) {
               final plan = (mech['subscriptionplan'] ?? 'FREE').toString().toUpperCase();
               if (plan == 'ULTRA_PREMIUM') return 3;
               if (plan == 'PREMIUM') return 2;
               return 1;
            }
            final wA = getPlanWeight(a);
            final wB = getPlanWeight(b);
            if (wA != wB) return wB.compareTo(wA);
            return 0;
          });

          _loadingMechanics = false;

          // 🔍 DEBUG: Print each mechanic's subscription plan
          for (final m in _mechanics) {
            debugPrint('🔧 Mechanic: ${m['name']} | subscriptionplan: ${m['subscriptionplan']}');
          }

          // Pre-select first mechanic if manual booking flow was intended or let user pick
          if (_mechanics.isNotEmpty && selectedMechanic == null) {
            // we don't auto-select here, let user choose
          }
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _mechanicsError = 'Mechanic Not available in this region';
          _loadingMechanics = false;
        });
      } else {
        setState(() {
          _mechanicsError = 'Could not load mechanics (${response.statusCode})';
          _loadingMechanics = false;
        });
      }
    } catch (e) {
      setState(() {
        _mechanicsError = 'Network error. Please try again.';
        _loadingMechanics = false;
      });
    }
  }

  // ── Booking Final Logic  ─────────────────────────────────────────
  Future<void> _bookAppointment({Map<String, dynamic>? mechanic}) async {
    if (_latitude == null || _longitude == null) return;
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select Date and Time")));
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);

    if (selectedDateOnly.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot book an appointment for a past date")));
      return;
    }

    if (selectedTime!.hour < 8 || selectedTime!.hour > 21 || (selectedTime!.hour == 21 && selectedTime!.minute > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointments can only be booked between 8:00 AM till 9:00 PM")));
      return;
    }

    if (selectedDateOnly.isAtSameMomentAs(today)) {
      if (selectedTime!.hour < now.hour ||
          (selectedTime!.hour == now.hour && selectedTime!.minute < now.minute)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cannot select a time in the past for today")));
        return;
      }
    }

    setState(() => _bookingInProgress = true); 

    try {
      final isManual = mechanic != null;
      final endpoint = isManual
          ? '$_baseUrl/api/user/manual/bookappointment'
          : '$_baseUrl/api/user/auto/bookappointment';
      final mechanicType = (mechanic?['mechanictype'] ?? '').toString().trim();
      
      // If service is "All", and we're manual booking, take mechanic's type. 
      // If auto booking and "All", we should have shown dialog (handled in build), 
      // but as a fallback default to Bike Mechanic.
      final String resolvedServiceType;
      if (selectedService == "All") {
        if (isManual && mechanicType.isNotEmpty) {
          resolvedServiceType = mechanicType;
        } else {
          resolvedServiceType = "Bike Mechanic";
        }
      } else {
        resolvedServiceType = selectedService;
      }

      // Formatting
      final dateStr = selectedDate!.toIso8601String().split('T')[0];
      final timeStr =
          "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00";

      final Map<String, dynamic> body = {
        "serviceType": resolvedServiceType,
        "latitude": _latitude,
        "longitude": _longitude,
        "problemDescription":
            detailController.text.isNotEmpty ? detailController.text : "Standard service check",
        "address": addressController.text,
        "appointmentDate": dateStr,
        "appointmentTime": timeStr,
      };

      if (isManual && mechanic != null) {
        // Use the 'id' key which we normalized in _fetchNearbyMechanics
        body["id"] = mechanic['id'] ?? 0;
      }

      print("📤 Booking Payload: $body");

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          ...UserSession().getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      setState(() => _loadingMechanics = false);

      setState(() => _bookingInProgress = false);
      if (response.statusCode == 200) {
        final rawBody = response.body.trim();
        dynamic decoded;

        try {
          decoded = jsonDecode(rawBody);
        } catch (_) {
          // Auto booking endpoint may return plain text appointment ID (non-JSON).
          decoded = rawBody;
        }
        Map<String, dynamic>? bookingResponse;

        Map<String, dynamic> normalizeBookingMap(Map<String, dynamic> source) {
          final normalized = <String, dynamic>{};

          final appointmentId = source['appointmentId'] ??
              source['appointmentid'] ??
              source['id'];
          final serviceType = source['serviceType'] ?? source['servicetype'];
          final latitude = source['latitude'] ?? source['lat'];
          final longitude = source['longitude'] ?? source['lng'] ?? source['lon'];
          final problemDescription = source['problemDescription'] ??
              source['problemdescription'] ??
              source['issue'];
          final appointmentDate =
              source['appointmentDate'] ?? source['appointmentdate'];
          final appointmentTime =
              source['appointmentTime'] ?? source['appointmenttime'];
          final address = source['address'] ?? source['location'];

          normalized['appointmentId'] = appointmentId?.toString() ?? '--';
          normalized['serviceType'] = serviceType ?? resolvedServiceType;
          normalized['latitude'] = latitude ?? _latitude;
          normalized['longitude'] = longitude ?? _longitude;
          normalized['problemDescription'] = problemDescription ??
              (detailController.text.isNotEmpty
                  ? detailController.text
                  : "Standard service check");
          normalized['address'] = address ?? addressController.text;
          normalized['appointmentDate'] = appointmentDate ?? dateStr;
          normalized['appointmentTime'] = appointmentTime ?? timeStr;

          final mechanicName = source['mechname'];
          final mechanicType = source['mechtype'] ?? source['serviceType'];
          final mechanicImage = source['mechimage'];
          final mechanicRating = source['mechrating'];
          final mechanicDistance = source['distance'];
          final mechanicExperience = source['mechexperience'];

          if (source['mechanic'] is Map<String, dynamic>) {
            normalized['mechanic'] = source['mechanic'];
          } else if (mechanicName != null ||
              mechanicType != null ||
              mechanicImage != null) {
            normalized['mechanic'] = {
              'name': mechanicName ?? 'Auto Expert',
              'mechanictype': mechanicType ?? 'Mechanical Specialist',
              'mechanicimgurl': mechanicImage,
              'averageRating': mechanicRating,
              'distance': mechanicDistance,
              'experience': mechanicExperience,
            };
          } else {
            normalized['mechanic'] = isManual ? mechanic : null;
          }

          return normalized;
        }

        if (decoded is Map<String, dynamic>) {
          bookingResponse = normalizeBookingMap(decoded);
        } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          bookingResponse =
              normalizeBookingMap(Map<String, dynamic>.from(decoded.first as Map));
        } else if (decoded is num || decoded is String) {
          // Backend may return only appointmentId in auto flow.
          bookingResponse = {
            "appointmentId": decoded.toString(),
            "serviceType": resolvedServiceType,
            "appointmentDate": dateStr,
            "appointmentTime": timeStr,
            "address": addressController.text,
            "problemDescription": detailController.text.isNotEmpty
                ? detailController.text
                : "Standard service check",
            "latitude": _latitude,
            "longitude": _longitude,
            "mechanic": isManual ? mechanic : null,
          };
        }

        if (bookingResponse == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Unexpected booking response format. Please try again."),
            ),
          );
          return;
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(bookingData: bookingResponse!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Booking failed: ${response.statusCode}")));
      }
    } catch (e) {
      setState(() => _loadingMechanics = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Network error: $e")));
    }
  }

  Future<void> _refresh() async {
    await _fetchNearbyMechanics();
  }

  // ── Auto assign ──────────────────────────────────────────────────
  void _autoAssignMechanic() {
    _bookAppointment(mechanic: null); // Null means auto-assign flow
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 1,
        leading: AppBackButton(
          onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => HomeScreen())),
        ),
        title: Text(
          "Book Appointment",
          style: GoogleFonts.getFont('Bricolage Grotesque',
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildMainBody(isDark),
          if (_loadingMechanics && !_isAutoMode && _mechanics.isEmpty) // Initial loading
             _loadingOverlay("Finding Mechanics..."),
          if (_bookingInProgress)
             _loadingOverlay("Securing your appointment..."),
        ],
      ),
    );
  }

  Widget _buildMainBody(bool isDark) {
    return RefreshIndicator(
        onRefresh: _refresh,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeToggle(isDark),
              const SizedBox(height: 20),
              // ── Location Section ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildLocationCard(isDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: _buildCurrentLocationCard(isDark),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Service dropdown ────────────────────────────────
              _sectionTitle("Select Service"),
              const SizedBox(height: 12),
              _buildServiceFilters(isDark),
              const SizedBox(height: 20),

              // ── Mechanics section ───────────────────────────────
              _sectionTitleWithSeeAll(
                "Nearby Mechanics",
                "See All",
                () async {
                  if (selectedService == "All") {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Please select a specific service to choose a mechanic")),
                    );
                    return;
                  }
                  if (_filteredMechanics.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("No mechanics found for this service")),
                    );
                    return;
                  }
                  final selected = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MechanicListScreenn(
                        serviceType: selectedService,
                        mechanics: _filteredMechanics,
                        showViewOption: true,
                        selectedMechanicId: selectedMechanic?['phonenumber'],
                      ),
                    ),
                  );
                  if (selected != null) {
                    setState(() => selectedMechanic = selected);
                  }
                },
              ),
              const SizedBox(height: 12),

              _buildMechanicsList(isDark),
              const SizedBox(height: 20),

              // ── Service detail ──────────────────────────────────
              _sectionTitle("Service Detail"),
              const SizedBox(height: 8),
              _inputField(
                controller: detailController,
                hint: "Describe your problem briefly",
                icon: Icons.build_outlined,
                isDark: isDark,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ── Date & Time Row ─────────────────────────────────
              Row(
                children: [
                  Expanded(child: _dateTile(isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _timeTile(isDark)),
                ],
              ),
              const SizedBox(height: 30),

              // ── Confirm button ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (_latitude == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Please select your location")));
                      return;
                    }
                    if (!_isAutoMode && selectedMechanic == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Please choose a mechanic first")));
                      return;
                    }
                    
                    if (_isAutoMode) {
                       if (selectedService == "All") {
                        _showAutoAssignServiceDialog(isDark);
                      } else {
                        _autoAssignMechanic();
                      }
                    } else {
                      _bookAppointment(mechanic: selectedMechanic);
                    }
                  },
                  child: Text(
                    _isAutoMode ? "Find Mechanic" : "Book with Selected Mechanic",
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
    );
  }

  Widget _loadingOverlay(String message) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              message,
              style: GoogleFonts.getFont('Bricolage Grotesque',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Location card (tap to open map) ──────────────────────────────
  Widget _buildLocationCard(bool isDark) {
    return GestureDetector(
      onTap: _openLocationPicker,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: (_latitude != null && !_isUsingCurrentLocation) ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.location_pin, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _latitude == null ? "Set Location" : "Set Your Location",
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _locationName ?? "Tap to pick",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                        fontSize: 10,
                        color: _latitude != null
                            ? (isDark ? Colors.white70 : Colors.black87)
                            : Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              (_latitude != null && !_isUsingCurrentLocation)
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: (_latitude != null && !_isUsingCurrentLocation) ? primaryColor : Colors.grey.shade400,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationCard(bool isDark) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: GestureDetector(
        onTap: _getCurrentLocation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: (_isFetchingCurrentLocation || _isUsingCurrentLocation) ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: (_isFetchingCurrentLocation || _isUsingCurrentLocation)
                ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8)]
                : [],
          ),
          child: Center(
            child: _isFetchingCurrentLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.my_location,
                        color: (_isFetchingCurrentLocation || _isUsingCurrentLocation)
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Use Current Location",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.getFont('Bricolage Grotesque',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (_isFetchingCurrentLocation || _isUsingCurrentLocation)
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Mechanics list (horizontal scroll) ───────────────────────────
  Widget _buildMechanicsList(bool isDark) {
    if (_latitude == null) {
      return _emptyState(
        icon: Icons.map_outlined,
        message: "Select your location first\nto find nearby mechanics",
      );
    }
    if (_loadingMechanics) {
      return _buildSkeletonLoading(isDark);
    }
    if (_mechanicsError != null) {
      return _emptyState(
        icon: Icons.wifi_off_rounded,
        message: _mechanicsError!,
        onRetry: _fetchNearbyMechanics,
      );
    }
    if (_mechanics.isEmpty) {
      return _emptyState(
        icon: Icons.engineering_outlined,
        message: "No mechanics found in this region.\nTry a different location.",
      );
    }
    if (_filteredMechanics.isEmpty) {
      return _emptyState(
        icon: Icons.search_off_outlined,
        message: "No $selectedService found nearby.\nTry selecting another service.",
      );
    }
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filteredMechanics.length,
        itemBuilder: (context, index) {
          final mechanic = _filteredMechanics[index];
          final isSelected = selectedMechanic != null &&
              selectedMechanic!['phonenumber'] == mechanic['phonenumber'];
          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 12),
            child: _mechanicCard(mechanic, isDark, isSelected),
          );
        },
      ),
    );
  }

  Widget _emptyState(
      {required IconData icon,
      required String message,
      VoidCallback? onRetry}) {
    return Container(
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 30),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Bricolage Grotesque',
                fontSize: 12,
                color: Colors.grey.shade500),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: Text("Retry",
                  style: TextStyle(
                      fontFamily: 'Bricolage Grotesque', color: primaryColor)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mechanicCard(
      Map<String, dynamic> mechanic, bool isDark, bool isSelected) {
    final name = mechanic['name'] as String? ?? 'Unknown';
    final rating =
        (mechanic['averagerating'] as num?)?.toStringAsFixed(1) ?? '5.0';
    final distance =
        (mechanic['distance'] as num?)?.toStringAsFixed(1) ?? '--';
    final isActive = mechanic['isactive'] as bool? ?? false;
    final isEngaged = mechanic['isengaged'] as bool? ?? false;
    final imgUrl = mechanic['mechanicimgurl'] as String?;
    final mechId = mechanic['id']?.toString() ?? '??';

    Color statusColor;
    String statusLabel;
    if (!isActive) {
      statusColor = Colors.grey;
      statusLabel = 'Offline';
    } else if (isEngaged) {
      statusColor = Colors.orange;
      statusLabel = 'Busy';
    } else {
      statusColor = Colors.green;
      statusLabel = 'Available';
    }

    final isPremium = (mechanic['subscriptionplan']?.toString().toUpperCase() == 'PREMIUM');
    final isUltra = (mechanic['subscriptionplan']?.toString().toUpperCase() == 'ULTRA_PREMIUM');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (isSelected && !_isAutoMode)
                ? primaryColor
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                    imgUrl != null ? NetworkImage(imgUrl) : null,
                child: imgUrl == null
                    ? Icon(Icons.engineering, color: primaryColor, size: 20)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.getFont('Bricolage Grotesque',
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                        if (isUltra) ...[
                          const SizedBox(width: 4),
                          const Tooltip(
                            message: "Verified Pro",
                            triggerMode: TooltipTriggerMode.tap,
                            child: Icon(Icons.verified, color: Colors.blue, size: 14),
                          ),
                        ],
                      ],
                    ),
                    if (isPremium || isUltra) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB3300).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFB3300).withOpacity(0.3)),
                        ),
                        child: Text(
                          "RECOMMENDED",
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFB3300),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      mechanic['mechanictype'] ?? 'Mechanical Specialist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(rating,
                      style: const TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 10,
                          fontWeight: FontWeight.w400)),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.work_history_outlined,
                      size: 11, color: primaryColor.withOpacity(0.6)),
                  const SizedBox(width: 2),
                  Text("${mechanic['experience'] ?? '0'} yrs",
                      style: const TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 10,
                          fontWeight: FontWeight.w400)),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 11, color: primaryColor),
                  const SizedBox(width: 2),
                  Text("$distance km",
                      style: const TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 10,
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!_isAutoMode)
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () => setState(() => selectedMechanic = mechanic),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(isSelected ? "Selected" : "Select",
                        style: const TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "Auto-Assign",
                    style: TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 9,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 3),
                    Text(statusLabel,
                        style: TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Widget _buildModeToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _toggleButton(
                  label: "Auto Assign",
                  isSelected: _isAutoMode,
                  isDark: isDark,
                  isRecommended: true,
                  onTap: () => setState(() => _isAutoMode = true),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _toggleButton(
                  label: "Choose Mechanic",
                  isSelected: !_isAutoMode,
                  isDark: isDark,
                  onTap: () => setState(() => _isAutoMode = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(
      {required String label,
      required bool isSelected,
      required bool isDark,
      bool isRecommended = false,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: primaryColor.withOpacity(0.3), blurRadius: 8)
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.getFont('Bricolage Grotesque',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ),
          ),
          if (isRecommended)
            Positioned(
              top: -6,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : primaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "RECOMMENDED",
                  style: GoogleFonts.getFont('Bricolage Grotesque',
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? primaryColor : Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: GoogleFonts.getFont('Bricolage Grotesque',
          fontWeight: FontWeight.w700,
          fontSize: 15));

  Widget _sectionTitleWithSeeAll(
          String title, String seeAllText, VoidCallback onSeeAll) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: GoogleFonts.getFont('Bricolage Grotesque',
                fontWeight: FontWeight.w700,
                fontSize: 15)),
        InkWell(
          onTap: onSeeAll,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              seeAllText,
              style: TextStyle(
                  fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceFilters(bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final service = services[index];
          final label = service['label'] as String;
          final icon = service['icon'] as IconData;
          final isSelected = selectedService == label;

          return GestureDetector(
            onTap: () => setState(() {
              selectedService = label;
              // No _fetchNearbyMechanics() here to avoid flickers
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.grey[900] : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(22),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Remove the old _dropdown helper if no longer used
  // Widget _dropdown(...) { ... }

  Widget _inputField(
          {required TextEditingController controller,
          required String hint,
          required IconData icon,
          required bool isDark,
          int maxLines = 1}) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.getFont('Bricolage Grotesque', fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryColor),
          hintText: hint,
          hintStyle: GoogleFonts.getFont('Bricolage Grotesque', color: Colors.grey),
          filled: true,
          fillColor: isDark ? Colors.grey[900] : Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      );



  Widget _dateTile(bool isDark) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        horizontalTitleGap: 8,
        tileColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(Icons.calendar_today_outlined, color: primaryColor),
        title: Text(
          selectedDate == null
              ? "Choose Date"
              : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
          style: GoogleFonts.getFont('Bricolage Grotesque', fontSize: 13),
        ),
        onTap: () async {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final date = await showDatePicker(
            context: context,
            firstDate: today,
            lastDate: DateTime(2030),
            initialDate: (selectedDate != null && !selectedDate!.isBefore(today)) ? selectedDate! : today,
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
                textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(foregroundColor: primaryColor)),
              ),
              child: child!,
            ),
          );
          if (date != null) {
            final isToday = date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
            
            if (selectedTime != null) {
              if (selectedTime!.hour < 8 || selectedTime!.hour > 21 || (selectedTime!.hour == 21 && selectedTime!.minute > 0)) {
                setState(() {
                  selectedDate = date;
                  selectedTime = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Time has been reset because appointments are only between 8:00 AM and 9:00 PM")),
                );
                return;
              }
              if (isToday) {
                if (selectedTime!.hour < now.hour || 
                    (selectedTime!.hour == now.hour && selectedTime!.minute < now.minute)) {
                  setState(() {
                    selectedDate = date;
                    selectedTime = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Time has been reset because it is in the past for today")),
                  );
                  return;
                }
              }
            }
            setState(() => selectedDate = date);
          }
        },
      );

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour;
    final minute = tod.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return "$hour12:$minuteStr $period";
  }

  Widget _timeTile(bool isDark) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        horizontalTitleGap: 8,
        tileColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(Icons.access_time_outlined, color: primaryColor),
        title: Text(
          selectedTime == null ? "Choose Time" : _formatTimeOfDay(selectedTime!),
          style: GoogleFonts.getFont('Bricolage Grotesque', fontSize: 13),
        ),
        onTap: () => _showCustomTimePickerDialog(context, isDark),
      );

  Future<void> _showCustomTimePickerDialog(BuildContext context, bool isDark) async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a date first")),
      );
      return;
    }

    final now = DateTime.now();
    final isToday = selectedDate!.year == now.year &&
        selectedDate!.month == now.month &&
        selectedDate!.day == now.day;

    final List<TimeOfDay> slots = [
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 10, minute: 0),
      const TimeOfDay(hour: 11, minute: 0),
      const TimeOfDay(hour: 12, minute: 0),
      const TimeOfDay(hour: 13, minute: 0),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 15, minute: 0),
      const TimeOfDay(hour: 16, minute: 0),
      const TimeOfDay(hour: 17, minute: 0),
      const TimeOfDay(hour: 18, minute: 0),
      const TimeOfDay(hour: 19, minute: 0),
      const TimeOfDay(hour: 20, minute: 0),
      const TimeOfDay(hour: 21, minute: 0),
    ];

    await showDialog(
      context: context,
      builder: (context) {
        final dialogBg = isDark ? Colors.grey[900] : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Select Appointment Time",
            textAlign: TextAlign.center,
            style: GoogleFonts.getFont('Bricolage Grotesque',
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "You can book appointment between 8-AM till 9-PM",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.getFont('Bricolage Grotesque',
                      fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.1,
                    ),
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      final isValid = !isToday || slot.hour > now.hour;
                      final isSelected = selectedTime != null &&
                          selectedTime!.hour == slot.hour &&
                          selectedTime!.minute == slot.minute;

                      final hr = slot.hour;
                      final period = hr >= 12 ? 'PM' : 'AM';
                      var hr12 = hr % 12;
                      if (hr12 == 0) hr12 = 12;
                      final slotText = "$hr12:00 $period";

                      return GestureDetector(
                        onTap: isValid
                            ? () {
                                setState(() {
                                  selectedTime = slot;
                                });
                                Navigator.pop(context);
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? primaryColor : Colors.transparent,
                              width: 2.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Opacity(
                            opacity: isValid ? 1.0 : 0.35,
                            child: Text(
                              slotText,
                              style: GoogleFonts.getFont('Bricolage Grotesque',
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? primaryColor : textColor),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: GoogleFonts.getFont('Bricolage Grotesque',
                    color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _successDialog() => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title:
            Icon(Icons.check_circle_outline_rounded, color: primaryColor, size: 50),
        content: Text(
          "Your appointment has been booked successfully with ${selectedMechanic!['name'] ?? selectedMechanic!['phonenumber'] ?? 'the mechanic'}!",
          textAlign: TextAlign.center,
          style: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.w400),
        ),
      );

  // ── Skeleton Loading (Shimmer) ──────────────────────────────────
  Widget _buildSkeletonLoading(bool isDark) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 12),
            child: _skeletonCard(isDark),
          );
        },
      ),
    );
  }

  Widget _skeletonCard(bool isDark) {
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[200]!;
    final highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 80,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Container(
                  width: 60,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Auto Assign Service Selection ───────────────────────────────
  void _showAutoAssignServiceDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Select Service Type",
          style: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _serviceOption(context, "Bike Mechanic", Icons.two_wheeler_outlined),
            _serviceOption(
                context, "Car Mechanic", Icons.directions_car_outlined),
            _serviceOption(context, "Puncher", Icons.tire_repair_outlined),
          ],
        ),
      ),
    );
  }

  Widget _serviceOption(BuildContext context, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(
        label,
        style: GoogleFonts.getFont('Bricolage Grotesque',
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        setState(() => selectedService = label);
        _autoAssignMechanic();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
