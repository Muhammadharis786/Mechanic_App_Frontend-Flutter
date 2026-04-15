import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicBookingRequestScreen extends StatefulWidget {
  const MechanicBookingRequestScreen({super.key});

  @override
  State<MechanicBookingRequestScreen> createState() =>
      _MechanicBookingRequestScreenState();
}

class _MechanicBookingRequestScreenState
    extends State<MechanicBookingRequestScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  // 🔹 Dummy booking records — replace with API data later
  final List<Map<String, dynamic>> bookingRecords = [
    {
      'userName': 'Ali Khan',
      'location': 'Johar Town, Lahore',
      'requestTime': '12 Jan 2026 • 4:30 PM',
      'amount': 'Rs. 1,200',
      'status': 'Completed',
    },
    {
      'userName': 'Sarah Ahmed',
      'location': 'Gulshan-e-Iqbal, Karachi',
      'requestTime': '13 Jan 2026 • 11:00 AM',
      'amount': 'Rs. 2,500',
      'status': 'Rejected',
    },
    {
      'userName': 'Usman Tariq',
      'location': 'DHA Phase 5, Islamabad',
      'requestTime': '14 Jan 2026 • 2:00 PM',
      'amount': 'Rs. 3,000',
      'status': 'Completed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Booking Requests',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
                Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: bookingRecords.isEmpty
          ? Center(
              child: Text(
                'No booking records found.',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: bookingRecords.length,
              itemBuilder: (context, index) {
                return _buildRecordCard(bookingRecords[index], isDark);
              },
            ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record, bool isDark) {
    final String status = record['status'];

    Color statusColor;
    IconData statusIcon;

    if (status == 'Completed') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
    } else {
      // Rejected
      statusColor = Colors.red;
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark ? Border.all(color: Colors.grey.shade800) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Top Row: Avatar + Name + Status Badge
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: primaryColor.withValues(alpha: 0.12),
                child: Text(
                  (record['userName'] as String?)?.isNotEmpty == true
                      ? record['userName'][0]
                      : '?',
                  style: GoogleFonts.poppins(
                    color: primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  record['userName'],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // 🔹 Detail Rows
          _detailRow(
            Icons.location_on_rounded,
            "Location",
            record['location'],
            isDark,
          ),
          const SizedBox(height: 10),
          _detailRow(
            Icons.access_time_rounded,
            "Request Time",
            record['requestTime'],
            isDark,
          ),
          const SizedBox(height: 10),
          _detailRow(
            Icons.payments_rounded,
            "Amount",
            record['amount'],
            isDark,
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isHighlight
              ? Colors.green
              : (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
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
                  fontWeight:
                      isHighlight ? FontWeight.w700 : FontWeight.w500,
                  color: isHighlight
                      ? Colors.green
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}