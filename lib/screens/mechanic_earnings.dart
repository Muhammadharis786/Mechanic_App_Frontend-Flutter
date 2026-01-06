import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicEarningsScreen extends StatefulWidget {
  const MechanicEarningsScreen({super.key});

  @override
  State<MechanicEarningsScreen> createState() =>
      _MechanicEarningsScreenState();
}

class _MechanicEarningsScreenState extends State<MechanicEarningsScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  // Dummy data for completed bookings
  List<Map<String, dynamic>> completedBookings = [
    {
      'userName': 'Ali Khan',
      'service': 'Bike Repair',
      'amount': 1200,
      'date': '12 Jan 2026',
    },
    {
      'userName': 'Sarah Ahmed',
      'service': 'Car Mechanic',
      'amount': 2500,
      'date': '13 Jan 2026',
    },
    {
      'userName': 'Usman Ali',
      'service': 'Car Battery Change',
      'amount': 3000,
      'date': '13 Jan 2026',
    },
  ];

  // Dummy pending bookings count
  int pendingBookings = 2;

  String today = '13 Jan 2026'; // example today date

  @override
  Widget build(BuildContext context) {
    // ✅ Type-safe calculations
    int totalEarnings = completedBookings.fold(
        0, (sum, b) => sum + (b['amount'] as int));
    int todaysEarnings = completedBookings
        .where((b) => b['date'] == today)
        .fold(0, (sum, b) => sum + (b['amount'] as int));
    int completedCount = completedBookings.length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          'Earnings',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Summary Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _summaryCard('Total Earnings', 'PKR $totalEarnings', Colors.green),
                _summaryCard('Today', 'PKR $todaysEarnings', Colors.blue),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _summaryCard('Completed', '$completedCount', Colors.green),
                _summaryCard('Pending', '$pendingBookings', Colors.orange),
              ],
            ),
            const SizedBox(height: 20),

            // Completed Bookings List Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Completed Bookings',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Completed Bookings List
            Expanded(
              child: completedBookings.isEmpty
                  ? Center(
                      child: Text(
                        'No completed bookings',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: completedBookings.length,
                      itemBuilder: (context, index) {
                        final b = completedBookings[index];
                        return _bookingCard(b);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Summary Card Widget
  Widget _summaryCard(String title, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // Completed Booking Card Widget
  Widget _bookingCard(Map<String, dynamic> b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b['userName'],
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(b['service'], style: GoogleFonts.poppins(fontSize: 14)),
          const SizedBox(height: 4),
          Text('PKR ${b['amount']}', style: GoogleFonts.poppins(fontSize: 14)),
          const SizedBox(height: 4),
          Text(b['date'],
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
