import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Screens imports
import 'mechanic_bookingrequest.dart';
import 'mechanic_earnings.dart';
import 'mechanic_profile.dart';
import 'mechanic_login.dart';
import 'mechanic_settings.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../authentication/user_session.dart';
import '../homescreen.dart';
import '../verify_screen.dart'; 

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  List<Map<String, dynamic>> requests = [
    {
      'user': 'Ali Khan',
      'service': 'Car Mechanic',
      'status': 'Pending',
      'distance': 2.5,
      'earnings': 1200,
      'timer': 60,
    },
    {
      'user': 'Sarah Ahmed',
      'service': 'Bike Mechanic',
      'status': 'Pending',
      'distance': 3.2,
      'earnings': 800,
      'timer': 60,
    },
  ];

  double totalEarnings = 3500.0;
  double todaysEarnings = 2000.0;
  double mechanicRating = 4.8;
  String mechanicName = "Aslam Mechanic";

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/dashboard");
    try {
      final response = await http.get(url, headers: UserSession().getAuthHeader());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
           if (data['mechanic'] != null) {
             mechanicName = data['mechanic']['name'] ?? mechanicName;
             mechanicRating = (data['mechanic']['averagerating'] as num?)?.toDouble() ?? mechanicRating;
             // Add other fields if available
           }
           if (data['earnings'] != null) {
              totalEarnings = (data['earnings']['total'] as num?)?.toDouble() ?? totalEarnings;
              todaysEarnings = (data['earnings']['today'] as num?)?.toDouble() ?? todaysEarnings;
           }
           // Preserving requests logic for now as API response for requests is unknown/complex to map blind
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none_rounded,
                color: primaryColor, size: 28),
            onPressed: _openNotifications,
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MechanicSettingsScreen(
                    isDarkMode: false,
                    onThemeChanged: (val) {},
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $mechanicName',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$mechanicRating Rating',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.person, color: Colors.grey, size: 35),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, const Color(0xFFFF6A00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Total Earnings', totalEarnings),
                  Container(width: 1, height: 40, color: Colors.white24),
                  _statItem("Today's Profit", todaysEarnings),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Quick Actions',
              style:
                  GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _actionCard('Requests', Icons.pending_actions, Colors.blue, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MechanicBookingRequestScreen()));
                }),
                const SizedBox(width: 15),
                _actionCard('My Wallet', Icons.account_balance_wallet,
                    Colors.green, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MechanicEarningsScreen()));
                }),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              'Recent Jobs',
              style:
                  GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            requests.isEmpty
                ? Center(
                    child: Text("No jobs found",
                        style: GoogleFonts.poppins(color: Colors.grey)))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: requests.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _jobTile(requests[index]),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, double val) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
        Text(
          'Rs. ${val.toStringAsFixed(0)}',
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _actionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, color: color, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jobTile(Map<String, dynamic> r) {
    bool isPending = r['status'] == 'Pending';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPending ? Colors.orange[50] : Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPending ? Icons.access_time_filled : Icons.check_circle,
              color: isPending ? Colors.orange : Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['user'] ?? 'Unknown User',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(r['service'] ?? 'No Service',
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rs. ${r['earnings'] ?? 0}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, color: primaryColor)),
              Text('${r['distance'] ?? 0} km',
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFFDFDFD),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFFDFDFD)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.build_circle, color: primaryColor, size: 50),
                ),
                const SizedBox(height: 10),
                Text(
                  'Mechanic Panel',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _drawerItem(Icons.grid_view_rounded, 'Dashboard', color: primaryColor),
          _drawerItem(Icons.calendar_today_rounded, 'Booking Requests', onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicBookingRequestScreen()));
          }),
          _drawerItem(Icons.account_balance_wallet_rounded, 'Earnings', onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicEarningsScreen()));
          }),
          _drawerItem(Icons.person_outline_rounded, 'Profile', onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicProfileScreen()));
          }),
          const Divider(),
          _drawerItem(Icons.settings_outlined, 'Settings', onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MechanicSettingsScreen(
                  isDarkMode: false,
                  onThemeChanged: (val) {},
                ),
              ),
            );
          }),
          _drawerItem(Icons.logout_rounded, 'Logout', color: Colors.red, onTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MechanicLoginScreen()),
              (route) => false,
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: InkWell(
              onTap: () async {
                if (await UserSession().trySwitchTo('USER')) {
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  }
                } else {
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const VerifyScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Switch to User Mode',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, {Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black54),
      title: Text(
        title,
        style: GoogleFonts.poppins(
            color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 15),
      ),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        List<Map<String, dynamic>> modalRequests = requests
            .map((r) => Map<String, dynamic>.from(r))
            .toList();

        Map<int, Timer?> modalTimers = {};

        return StatefulBuilder(builder: (context, setModalState) {
          for (int i = 0; i < modalRequests.length; i++) {
            if (modalRequests[i]['status'] == 'Pending' &&
                modalTimers[i] == null) {
              modalTimers[i] =
                  Timer.periodic(const Duration(seconds: 1), (timer) {
                if (modalRequests[i]['timer'] > 0) {
                  setModalState(() {
                    modalRequests[i]['timer']--;
                  });
                } else {
                  timer.cancel();
                }
              });
            }
          }

          return PopScope(
            onPopInvoked: (didPop) {
              if (didPop) modalTimers.forEach((_, t) => t?.cancel());
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Text('Service Requests',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      itemCount: modalRequests.length,
                        separatorBuilder: (context, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        var r = modalRequests[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['user'] ?? 'Unknown User',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text(r['service'] ?? 'No Service',
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 8),
                              Text(
                                  'Status: ${r['status']} | Timer: ${r['timer']}s',
                                  style: GoogleFonts.poppins(
                                      color: r['status'] == 'Pending'
                                          ? Colors.orange
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (r['status'] == 'Pending') ...[
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        setModalState(() {
                                          r['status'] = 'Accepted';
                                          modalTimers[index]?.cancel();
                                        });
                                      },
                                      child: const Text('Accept'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        setModalState(() {
                                          r['status'] = 'Rejected';
                                          modalTimers[index]?.cancel();
                                        });
                                      },
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}