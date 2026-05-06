import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mech_app/screens/homescreen.dart';

class RequestHistoryScreen extends StatefulWidget {
  const RequestHistoryScreen({super.key});

  @override
  State<RequestHistoryScreen> createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("History updated")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final emergencyRequests =
        dummyRequests.where((r) => r.type == "Instant Request").toList();
    final appointmentRequests =
        dummyRequests.where((r) => r.type == "Appointment").toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
          title: const Text(
            'Request History',
            style: TextStyle(
              fontFamily: 'YandexSansText',
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 18,
            ),
          ),
          bottom: TabBar(
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: isDark ? Colors.white70 : Colors.grey,
            labelStyle: const TextStyle(
                fontFamily: 'YandexSansText',
                fontWeight: FontWeight.bold,
                fontSize: 15),
            unselectedLabelStyle: const TextStyle(
                fontFamily: 'YandexSansText',
                fontWeight: FontWeight.normal,
                fontSize: 14),
            tabs: const [
              Tab(text: "Emergency"),
              Tab(text: "Appointments"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Emergency / Road Assistance
            RefreshIndicator(
              onRefresh: _refresh,
              color: primaryColor,
              child: emergencyRequests.isEmpty
                  ? Center(
                      child: Text(
                        "No emergency requests yet",
                        style: TextStyle(
                            fontFamily: 'YandexSansText',
                            color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: emergencyRequests.length,
                      itemBuilder: (context, index) {
                        return RequestHistoryCard(
                          data: emergencyRequests[index],
                          primaryColor: primaryColor,
                          isDark: isDark,
                        );
                      },
                    ),
            ),
            // Tab 2: Appointments
            RefreshIndicator(
              onRefresh: _refresh,
              color: primaryColor,
              child: appointmentRequests.isEmpty
                  ? Center(
                      child: Text(
                        "No appointments yet",
                        style: TextStyle(
                            fontFamily: 'YandexSansText',
                            color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: appointmentRequests.length,
                      itemBuilder: (context, index) {
                        return RequestHistoryCard(
                          data: appointmentRequests[index],
                          primaryColor: primaryColor,
                          isDark: isDark,
                        );
                      },
                    ),
            ),
          ],
        ),
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
                child: Icon(data.icon, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.service,
                      style: const TextStyle(
                        fontFamily: 'YandexSansText',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      data.mechanic,
                      style: TextStyle(
                        fontFamily: 'YandexSansText',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
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
                      const Icon(Icons.star_outline_rounded,
                          size: 16, color: Colors.amber),
                      Text(
                        data.rating.toString(),
                        style: TextStyle(
                          fontFamily: 'YandexSansText',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    data.date,
                    style: const TextStyle(
                      fontFamily: 'YandexSansText',
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.grey : Colors.grey.shade300),

          _infoRow(Icons.location_on_outlined, data.location),
          _infoRow(Icons.build_outlined, data.problem),
          _infoRow(Icons.schedule_outlined, data.type),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Paid Amount",
                style: TextStyle(
                  fontFamily: 'YandexSansText',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white70 : Colors.grey,
                ),
              ),
              Text(
                "Rs ${data.amount}",
                style: const TextStyle(
                  fontFamily: 'YandexSansText',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Color(0xFFFB3300),
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
                style: const TextStyle(
                  fontFamily: 'YandexSansText',
                  color: Colors.green,
                  fontWeight: FontWeight.w400,
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
              style: TextStyle(
                fontFamily: 'YandexSansText',
                fontSize: 13,
                fontWeight: FontWeight.w400,
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
    icon: Icons.motorcycle_outlined,
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
    icon: Icons.directions_car_outlined,
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
    icon: Icons.build_circle_outlined,
  ),
];
