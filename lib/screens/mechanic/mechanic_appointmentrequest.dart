import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicAppointmentRequestScreen extends StatefulWidget {
  const MechanicAppointmentRequestScreen({super.key});

  @override
  State<MechanicAppointmentRequestScreen> createState() =>
      _MechanicAppointmentRequestScreenState();
}

class _MechanicAppointmentRequestScreenState
    extends State<MechanicAppointmentRequestScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  // ✅ Dummy Data: Aap baad mein yahan API ka data use karein gi
  final List<Map<String, dynamic>> requests = [
    {
      "name": "Ahmed Raza",
      "phone": "0300-1234567",
      "location": "Shahrah-e-Faisal near Nursery, Karachi",
      "time": "Today, 02:30 PM",
      "price": "Rs. 1500 - 2000",
      "issue": "Car is not starting (Battery issue)",
      "status": "Pending",
      "distance": "2.4 km away"
    },
    {
      "name": "Hamna Ali",
      "phone": "0333-7654321",
      "location": "DHA Phase 6, Defence, Karachi",
      "time": "Mon, 22 April at 10:00 AM",
      "price": "Rs. 3000",
      "issue": "Brake pad replacement",
      "status": "Pending",
      "distance": "5.1 km away"
    }
  ];

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Appointment Requests",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
                Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: requests.isEmpty
          ? Center(
              child: Text(
                "No new requests at the moment.",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(requests[index], isDark);
              },
            ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ],
        border: isDark ? Border.all(color: Colors.grey.shade800) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 HEADER: User Name, Distance, Avatar
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: Text(
                  (request['name'] as String?)?.isNotEmpty == true
                      ? request['name'][0]
                      : '?',
                  style: GoogleFonts.poppins(
                      color: primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name'],
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.directions_car_filled_rounded,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          request['distance'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request['status'],
                  style: GoogleFonts.poppins(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          // 🔹 BODY: Location, Time, Issue, Price
          _detailRow(Icons.location_on_rounded, "Location", request['location'], isDark),
          const SizedBox(height: 10),
          _detailRow(Icons.access_time_rounded, "Time", request['time'], isDark),
          const SizedBox(height: 10),
          _detailRow(Icons.build_circle_outlined, "Issue", request['issue'], isDark),
          const SizedBox(height: 10),
          _detailRow(Icons.payments_rounded, "Estimated Fare", request['price'], isDark, isHighlight: true),


        ],
      ),
    );
  }

  // 🔹 Custom widget for Information Rows
  Widget _detailRow(IconData icon, String title, String value, bool isDark, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isHighlight ? Colors.green : (isDark ? Colors.grey[400] : Colors.grey[600])),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isHighlight ? Colors.green : (isDark ? Colors.white : Colors.black87),
                  fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}