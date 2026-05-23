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
      _fetchNearbyMechanics();
    }
  }

  @override
  void dispose() {
    addressController.dispose();
    detailController.dispose();
    super.dispose();
  }

  // ── Open Map Picker ──────────────────────────────────────────────
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _latitude = result['latitude'] as double;
        _longitude = result['longitude'] as double;
        _locationName = result['locationName'] as String?;
        addressController.text = _locationName ?? '';
        _mechanics = [];
        selectedMechanic = null;
        _mechanicsError = null;
      });
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
          _loadingMechanics = false;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
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
              // ── Location map card ───────────────────────────────
              _buildLocationCard(isDark),
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

              // ── Date ───────────────────────────────────────────
              _sectionTitle("Select Date"),
              _dateTile(isDark),
              const SizedBox(height: 16),

              // ── Time ───────────────────────────────────────────
              _sectionTitle("Select Time"),
              _timeTile(isDark),
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
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _latitude != null ? primaryColor : Colors.grey.shade300,
              width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.location_pin, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _latitude == null ? "Set Your Location" : "Your Location",
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _locationName ?? "Tap to pick on map",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                        fontSize: 12,
                        color: _latitude != null
                            ? Colors.black87
                            : Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(
              _latitude != null
                  ? Icons.check_circle_rounded
                  : Icons.arrow_forward_ios_rounded,
              color: _latitude != null ? primaryColor : Colors.grey.shade400,
              size: 18,
            ),
          ],
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
      height: 180,
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
    final phone = mechanic['phonenumber'] as String? ?? '';
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (isSelected && !_isAutoMode) ? primaryColor : Colors.transparent, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                    imgUrl != null ? NetworkImage(imgUrl) : null,
                child: imgUrl == null
                    ? Icon(Icons.engineering, color: primaryColor, size: 22)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.getFont('Bricolage Grotesque',
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                        Text(
                          "#$mechId",
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                              fontSize: 10,
                              color: primaryColor.withOpacity(0.7),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      mechanic['mechanictype'] ?? 'Mechanical Specialist',
                      style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(rating,
                            style: const TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 10,
                                fontWeight: FontWeight.w400)),
                        const SizedBox(width: 6),
                        Icon(Icons.work_history_outlined,
                            size: 12, color: primaryColor.withOpacity(0.6)),
                        const SizedBox(width: 2),
                        Text("${mechanic['experience'] ?? '0'} yrs exp",
                            style: const TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 10,
                                fontWeight: FontWeight.w400)),
                        const SizedBox(width: 6),
                        Icon(Icons.location_on_outlined,
                            size: 13, color: primaryColor),
                        Text("$distance km",
                            style: const TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 10,
                                fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ],
                ),
              ),
              // Status dot
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 3),
                    Text(statusLabel,
                        style: TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 10,
                            color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!_isAutoMode)
                ElevatedButton(
                  onPressed: () => setState(() => selectedMechanic = mechanic),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isSelected ? "Selected" : "Select",
                      style: const TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Available for Auto-Assign",
                    style: TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: phone.isNotEmpty ? () => _callMechanic(phone) : null,
                icon: const Icon(Icons.call_outlined,
                    size: 14, color: Colors.white),
                label: const Text("Call",
                    style: TextStyle(color: Colors.white, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
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
          String title, String seeAllText, VoidCallback onSeeAll) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.getFont('Bricolage Grotesque',
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          TextButton(
            onPressed: onSeeAll,
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.white),
              overlayColor: MaterialStateProperty.all(Colors.deepOrange.shade100),
            ),
            child: Text(seeAllText,
                style: GoogleFonts.getFont('Bricolage Grotesque',
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      );

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

  void _callMechanic(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Cannot call mechanic")));
    }
  }

  Widget _dateTile(bool isDark) => ListTile(
        tileColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(Icons.calendar_today_outlined, color: primaryColor),
        title: Text(
          selectedDate == null
              ? "Choose Date"
              : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
          style: GoogleFonts.getFont('Bricolage Grotesque', fontSize: 14),
        ),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            firstDate: DateTime.now(),
            lastDate: DateTime(2030),
            initialDate: DateTime.now(),
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
          if (date != null) setState(() => selectedDate = date);
        },
      );

  Widget _timeTile(bool isDark) => ListTile(
        tileColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(Icons.access_time_outlined, color: primaryColor),
        title: Text(
          selectedTime == null ? "Choose Time" : selectedTime!.format(context),
          style: GoogleFonts.getFont('Bricolage Grotesque', fontSize: 14),
        ),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
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
          if (time != null) setState(() => selectedTime = time);
        },
      );

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
