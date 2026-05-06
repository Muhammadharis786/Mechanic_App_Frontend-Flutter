import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mech_app/screens/homescreen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const BookingConfirmationScreen({super.key, required this.bookingData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFB3300);

    // Parse data from bookingData
    final bookingId = bookingData['appointmentId'] ?? '--';
    final serviceType = bookingData['serviceType'] ?? 'General Service';
    final appDate = bookingData['appointmentDate'] ?? '--';
    final appTime = bookingData['appointmentTime'] ?? '--';
    final address = bookingData['address'] ?? 'Specified Location';
    final note = bookingData['problemDescription'] ?? 'No special instructions';
    
    final mechanic = bookingData['mechanic'];
    final bool hasMechanic = mechanic != null;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: const Text("Confirmation", style: TextStyle(fontFamily: 'YandexSansText', fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Success Header ───────────────────────────────────
              const Center(
                child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
              ),
              const SizedBox(height: 12),
              const Text(
                "Booking Confirmed!",
                style: TextStyle(
                  fontFamily: 'YandexSansDisplay',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Booking ID: $bookingId",
                style: const TextStyle(
                  fontFamily: 'YandexSansText',
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),

              // ── Mechanic Info Card ───────────────────────────────
              if (hasMechanic)
                _buildMechanicSection(mechanic, primaryColor, isDark)
              else
                _buildAutoAssignWaiting(primaryColor),

              const SizedBox(height: 24),

              // ── Booking Details ──────────────────────────────────
              _buildDetailSection(
                isDark: isDark,
                service: serviceType,
                date: appDate,
                time: appTime,
                address: address,
                note: note,
              ),

              const SizedBox(height: 30),

              // ── Map Snippet (Mock for now) ───────────────────────
              _buildMapSnippet(bookingData, isDark),

              const SizedBox(height: 40),

              // ── Done Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => HomeScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Back to Home",
                    style: TextStyle(fontFamily: 'YandexSansText', color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMechanicSection(Map<String, dynamic> mechanic, Color primary, bool isDark) {
    final name = mechanic['name'] ?? mechanic['phonenumber'] ?? 'Auto Expert';
    final rating = (mechanic['averageRating'] ?? 5.0).toString();
    final imgUrl = mechanic['mechanicimgurl'];
    final double? dist = (mechanic['distance'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: primary.withOpacity(0.1),
                backgroundImage: imgUrl != null ? NetworkImage(imgUrl) : null,
                child: imgUrl == null ? Icon(Icons.person, color: primary, size: 30) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontFamily: 'YandexSansText', fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(rating, style: const TextStyle(fontFamily: 'YandexSansText', fontSize: 14)),
                        if (dist != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on, color: Colors.grey, size: 14),
                          const SizedBox(width: 2),
                          Text("${dist.toStringAsFixed(1)} km away",
                              style: const TextStyle(fontFamily: 'YandexSansText', fontSize: 12, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoAssignWaiting(Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircularProgressIndicator(strokeWidth: 2, color: primary),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              "We're notifying all nearby mechanics. You'll hear from them soon!",
              style: TextStyle(fontFamily: 'YandexSansText', fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required bool isDark,
    required String service,
    required String date,
    required String time,
    required String address,
    required String note,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow(Icons.handyman_outlined, "Service", service.toUpperCase()),
          const Divider(height: 24),
          _detailRow(Icons.calendar_month, "Date | Time", "$date | $time"),
          const Divider(height: 24),
          _detailRow(Icons.location_on_outlined, "Meeting Point", address),
          const Divider(height: 24),
          _detailRow(Icons.notes_rounded, "Problem Note", note),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFFB3300), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'YandexSansText', color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontFamily: 'YandexSansText', fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapSnippet(Map<String, dynamic> data, bool isDark) {
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) return const SizedBox.shrink();

    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.grey[850] : Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 15),
          markers: {Marker(markerId: const MarkerId('pos'), position: LatLng(lat, lng))},
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
        ),
      ),
    );
  }
}
