import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicBookingRequestScreen extends StatefulWidget {
  const MechanicBookingRequestScreen({super.key});

  @override
  State<MechanicBookingRequestScreen> createState() =>
      _MechanicBookingRequestScreenState();
}

class _MechanicBookingRequestScreenState
    extends State<MechanicBookingRequestScreen>
    with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xFFFB3300);

  TabController? _tabController;

  /// 🔴 Pending Booking Requests
  List<Map<String, dynamic>> bookingRequests = [
    {
      'userName': 'Ali Khan',
      'mobile': '0301-1234567',
      'address': 'Johar Town, Lahore',
      'service': 'Bike Repair',
      'problem': 'Bike start nahi ho rahi',
      'date': '12 Jan 2026',
      'time': '4:30 PM',
      'amount': 1200,
      'status': 'Pending',
    },
    {
      'userName': 'Sarah Ahmed',
      'mobile': '0305-9876543',
      'address': 'Gulshan-e-Iqbal, Karachi',
      'service': 'Car Mechanic',
      'problem': 'Engine overheating',
      'date': '13 Jan 2026',
      'time': '11:00 AM',
      'amount': 2500,
      'status': 'Pending',
    },
  ];

  /// 🟢 Booking History
  List<Map<String, dynamic>> bookingHistory = [
    {
      'userName': 'Usman Ali',
      'address': 'DHA Phase 6, Lahore',
      'service': 'Car Battery Change',
      'date': '08 Jan 2026',
      'time': '2:00 PM',
      'amount': 3000,
      'status': 'Completed',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize TabController safely
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      /// APP BAR WITH TABS
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          'Bookings',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryColor,
                labelStyle:
                    GoogleFonts.poppins(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Requests'),
                  Tab(text: 'History'),
                ],
              )
            : null,
      ),

      /// BODY
      body: _tabController != null
          ? TabBarView(
              controller: _tabController,
              children: [
                _requestsTab(),
                _historyTab(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  /// ================= REQUESTS TAB =================
  Widget _requestsTab() {
    if (bookingRequests.isEmpty) {
      return _emptyView('No booking requests');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookingRequests.length,
      itemBuilder: (context, index) {
        final r = bookingRequests[index];
        return _requestCard(r, index);
      },
    );
  }

  Widget _requestCard(Map<String, dynamic> r, int index) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(r['userName'], r['status']),
          const SizedBox(height: 6),
          _infoRow(Icons.phone, r['mobile']),
          _infoRow(Icons.location_on, r['address']),
          const Divider(),
          _infoRow(Icons.build, r['service']),
          _infoRow(Icons.description, r['problem']),
          const Divider(),
          _infoRow(Icons.calendar_today, '${r['date']} • ${r['time']}'),
          _infoRow(Icons.attach_money, 'PKR ${r['amount']}'),
          const SizedBox(height: 10),

          /// ACTION BUTTONS
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    bookingRequests.removeAt(index);
                  });
                },
                child:
                    const Text('Reject', style: TextStyle(color: Colors.red)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    r['status'] = 'Completed';
                    bookingHistory.insert(0, r);
                    bookingRequests.removeAt(index);
                  });
                },
                child: const Text('Accept'),
              ),
            ],
          )
        ],
      ),
    );
  }

  /// ================= HISTORY TAB =================
  Widget _historyTab() {
    if (bookingHistory.isEmpty) {
      return _emptyView('No booking history');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookingHistory.length,
      itemBuilder: (context, index) {
        final h = bookingHistory[index];
        return _cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleRow(h['userName'], h['status']),
              const SizedBox(height: 6),
              _infoRow(Icons.location_on, h['address']),
              const Divider(),
              _infoRow(Icons.build, h['service']),
              _infoRow(Icons.calendar_today, '${h['date']} • ${h['time']}'),
              _infoRow(Icons.attach_money, 'PKR ${h['amount']}'),
            ],
          ),
        );
      },
    );
  }

  /// ================= REUSABLE WIDGETS =================
  Widget _cardContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: child,
    );
  }

  Widget _titleRow(String title, String status) {
    Color color = status == 'Completed' ? Colors.green : primaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: GoogleFonts.poppins(
                color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.poppins(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _emptyView(String text) {
    return Center(
      child: Text(text, style: GoogleFonts.poppins(fontSize: 16)),
    );
  }
}
