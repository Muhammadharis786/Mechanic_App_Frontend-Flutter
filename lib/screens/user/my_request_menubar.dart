import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mech_app/screens/homescreen.dart';

class RequestHistoryScreen extends StatelessWidget {
  const RequestHistoryScreen({super.key});

  final Color primaryColor = const Color(0xFFFB3300);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
        title: Text(
          'Request History',
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor:
                    isDark ? Colors.grey.shade900 : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: primaryColor),
                ),
              ),
              onPressed: () {
                // 👉 Backend dev pagination / full history lagay ga
              },
              child: Text(
                "See All",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dummyRequests.length,
        itemBuilder: (context, index) {
          return RequestHistoryCard(
            data: dummyRequests[index],
            primaryColor: primaryColor,
            isDark: isDark,
          );
        },
      ),
    );
  }
}

// ================= CARD =================
class RequestHistoryCard extends StatelessWidget {
  final RequestModel data;
  final Color primaryColor;
  final bool isDark;

  const RequestHistoryCard({
    super.key,
    required this.data,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: primaryColor.withOpacity(0.15),
                child: Icon(data.icon, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.service,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      data.mechanic,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 16, color: Colors.amber),
                      Text(
                        data.rating.toString(),
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    data.date,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.grey : Colors.grey.shade300),

          _infoRow(Icons.location_on, data.location),
          _infoRow(Icons.build, data.problem),
          _infoRow(Icons.schedule, data.type),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Paid Amount",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey,
                ),
              ),
              Text(
                "Rs ${data.amount}",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                data.status,
                style: GoogleFonts.poppins(
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= MODEL =================
class RequestModel {
  final String service;
  final String mechanic;
  final String problem;
  final String location;
  final String date;
  final String type;
  final int amount;
  final double rating;
  final String status;
  final IconData icon;

  RequestModel({
    required this.service,
    required this.mechanic,
    required this.problem,
    required this.location,
    required this.date,
    required this.type,
    required this.amount,
    required this.rating,
    required this.status,
    required this.icon,
  });
}

// ================= DUMMY DATA =================
final List<RequestModel> dummyRequests = [
  RequestModel(
    service: "Bike Mechanic",
    mechanic: "Ali Bike Mechanic",
    problem: "Engine tuning & oil change",
    location: "Saddar, Karachi",
    date: "12 Jan 2026",
    type: "Instant Request",
    amount: 1800,
    rating: 4.8,
    status: "Completed",
    icon: Icons.motorcycle,
  ),
  RequestModel(
    service: "Car Mechanic (Home Service)",
    mechanic: "Usman Auto Service",
    problem: "Brake inspection",
    location: "Gulshan-e-Iqbal",
    date: "05 Jan 2026",
    type: "Appointment",
    amount: 3500,
    rating: 4.6,
    status: "Completed",
    icon: Icons.directions_car,
  ),
  RequestModel(
    service: "Puncture Repair",
    mechanic: "Kashif Puncture Shop",
    problem: "Rear tyre puncture",
    location: "North Nazimabad",
    date: "28 Dec 2025",
    type: "Instant Request",
    amount: 500,
    rating: 4.4,
    status: "Completed",
    icon: Icons.build_circle,
  ),
];
