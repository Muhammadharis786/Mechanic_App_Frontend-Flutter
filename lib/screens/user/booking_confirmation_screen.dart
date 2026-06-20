import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/map_theme_helper.dart';
import 'package:mech_app/screens/homescreen.dart';
import 'package:mech_app/widgets/app_back_button.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const BookingConfirmationScreen({super.key, required this.bookingData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFB3300);
    final bgColor = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF7F8FA);

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
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Booking Confirmed",
          style: GoogleFonts.getFont('Bricolage Grotesque',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
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
              _buildSuccessHero(
                isDark: isDark,
                primary: primaryColor,
                bookingId: bookingId.toString(),
              ),
              const SizedBox(height: 22),

              // ── Mechanic Info Card ───────────────────────────────
              if (hasMechanic)
                _buildMechanicSection(mechanic, primaryColor, isDark)
              else
                _buildAutoAssignWaiting(primaryColor, isDark),

              const SizedBox(height: 18),

              // ── Booking Details ──────────────────────────────────
              _buildDetailSection(
                isDark: isDark,
                service: serviceType,
                date: appDate,
                time: appTime,
                address: address,
                note: note,
              ),

              const SizedBox(height: 18),

              // ── Map Snippet (Mock for now) ───────────────────────
              _buildMapSnippet(context, bookingData, isDark),

              const SizedBox(height: 34),

              // ── Done Button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => HomeScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "Back to Home",
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
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

  Widget _buildSuccessHero({
    required bool isDark,
    required Color primary,
    required String bookingId,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1D1D1F), const Color(0xFF272728)]
              : [Colors.white, const Color(0xFFFFF4F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.green,
              size: 44,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Booking Confirmed",
            style: GoogleFonts.getFont('Bricolage Grotesque',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Your appointment request was successfully placed.",
            textAlign: TextAlign.center,
            style: GoogleFonts.getFont('Bricolage Grotesque',
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: primary.withOpacity(isDark ? 0.16 : 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "Booking ID: $bookingId",
              style: GoogleFonts.getFont('Bricolage Grotesque',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicSection(Map<String, dynamic> mechanic, Color primary, bool isDark) {
    final name = mechanic['name'] ?? mechanic['phonenumber'] ?? 'Auto Expert';
    final ratingNum = (mechanic['averageRating'] as num?)?.toDouble() ?? 5.0;
    final rating = ratingNum.toStringAsFixed(1);
    final imgUrl = mechanic['mechanicimgurl'];
    final double? dist = (mechanic['distance'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFF0F0F2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Assigned Mechanic",
            style: GoogleFonts.getFont('Bricolage Grotesque',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
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
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mechanic['mechanictype'] ?? 'Mechanical Specialist',
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                        fontSize: 13,
                        color: primary.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF202124),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.work_history_outlined, color: Colors.grey[600], size: 14),
                        const SizedBox(width: 4),
                        Text(
                          "${mechanic['experience'] ?? '5'} yrs exp",
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        if (dist != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on, color: Colors.grey, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            "${dist.toStringAsFixed(1)} km",
                            style: const TextStyle(
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
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

  Widget _buildAutoAssignWaiting(Color primary, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1F1C) : Colors.deepOrange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircularProgressIndicator(strokeWidth: 2, color: primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "We're notifying all nearby mechanics. You'll hear from them soon!",
              style: GoogleFonts.getFont('Bricolage Grotesque',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
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
    final surfaceColor = isDark ? const Color(0xFF1A1B1E) : Colors.white;
    final cardColor = isDark ? const Color(0xFF222327) : const Color(0xFFF8F9FB);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFF0F0F2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Appointment Details",
            style: GoogleFonts.getFont('Bricolage Grotesque',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Everything is set. Review your appointment info below.",
            style: GoogleFonts.getFont('Bricolage Grotesque',
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 14),
          _detailRow(
            isDark: isDark,
            cardColor: cardColor,
            icon: Icons.handyman_outlined,
            title: "Service",
            value: service.toUpperCase(),
          ),
          const SizedBox(height: 10),
          _detailRow(
            isDark: isDark,
            cardColor: cardColor,
            icon: Icons.calendar_month,
            title: "Date & Time",
            value: "$date | $time",
          ),
          const SizedBox(height: 10),
          _detailRow(
            isDark: isDark,
            cardColor: cardColor,
            icon: Icons.location_on_outlined,
            title: "Meeting Point",
            value: address,
          ),
          const SizedBox(height: 10),
          _detailRow(
            isDark: isDark,
            cardColor: cardColor,
            icon: Icons.notes_rounded,
            title: "Problem Note",
            value: note,
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required bool isDark,
    required Color cardColor,
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFB3300).withOpacity(isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFB3300),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.getFont('Bricolage Grotesque',
                    color: isDark ? Colors.white70 : Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.getFont('Bricolage Grotesque',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF202124),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSnippet(BuildContext context, Map<String, dynamic> data, bool isDark) {
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenMapScreen(lat: lat, lng: lng, address: data['address']),
          ),
        );
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? const Color(0xFF1A1B1E) : Colors.grey[200],
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: IgnorePointer(
                child: GoogleMap(
                  onMapCreated: (c) => MapThemeHelper.applyMapTheme(c, context),
                  initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 15),
                  markers: {Marker(markerId: const MarkerId('pos'), position: LatLng(lat, lng))},
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFB3300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fullscreen, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "VIEW FULL MAP",
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenMapScreen extends StatelessWidget {
  final double lat;
  final double lng;
  final String? address;

  const FullScreenMapScreen({super.key, required this.lat, required this.lng, this.address});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          address ?? "Appointment Location",
          style: GoogleFonts.getFont('Bricolage Grotesque', fontSize: 14),
        ),
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 1,
        leading: const AppBackButton(),
      ),
      body: GoogleMap(
        onMapCreated: (c) => MapThemeHelper.applyMapTheme(c, context),
        initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 16),
        markers: {
          Marker(
            markerId: const MarkerId('appointment_pos'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: address ?? "Meeting Point"),
          ),
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapToolbarEnabled: true,
      ),
    );
  }
}
