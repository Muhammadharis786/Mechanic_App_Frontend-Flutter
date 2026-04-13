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

  late TabController _tabController;

  List<Map<String, dynamic>> bookingRequests = [];
  List<Map<String, dynamic>> bookingHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  void _loadInitialData() {
    // Simulate fetching data from server
    bookingRequests = [
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
  }

  Future<void> _refreshRequests() async {
    // Simulate API refresh delay
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      // Reset the list to initial data for demo
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 1,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          'Bookings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: theme.unselectedWidgetColor,
          indicatorColor: primaryColor,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _refreshRequests,
            child: _requestsTab(theme),
          ),
          _historyTab(theme),
        ],
      ),
    );
  }

  Widget _requestsTab(ThemeData theme) {
    if (bookingRequests.isEmpty) {
      return ListView(
        children: [_emptyView('No booking requests', theme)],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookingRequests.length,
      itemBuilder: (context, index) {
        final r = bookingRequests[index];
        return _requestCard(r, index, theme);
      },
    );
  }

  Widget _historyTab(ThemeData theme) {
    if (bookingHistory.isEmpty) {
      return ListView(
        children: [_emptyView('No booking history', theme)],
      );
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
              _titleRow(h['userName'], h['status'], theme),
              const SizedBox(height: 8),
              _infoRow(Icons.location_on_outlined, h['address'], theme),
              const Divider(),
              _infoRow(Icons.build_outlined, h['service'], theme),
              _infoRow(Icons.description_outlined, h['service'], theme),
              _infoRow(Icons.calendar_today_outlined,
                  '${h['date']} • ${h['time']}', theme),
              _infoRow(Icons.attach_money_outlined, 'Rs. ${h['amount']}', theme),
            ],
          ),
        );
      },
    );
  }

  Widget _cardContainer({required Widget child}) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _titleRow(String title, String status, ThemeData theme) {
    Color color;

    switch (status) {
      case 'Completed':
        color = Colors.green;
        break;
      case 'Rejected':
        color = primaryColor;
        break;
      default:
        color = primaryColor;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: GoogleFonts.poppins(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r, int index, ThemeData theme) {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleRow(r['userName'], r['status'], theme),
          const SizedBox(height: 10),
          _infoRow(Icons.phone_outlined, r['mobile'], theme),
          _infoRow(Icons.location_on, r['address'], theme),
          const Divider(),
          _infoRow(Icons.build_circle_outlined, r['service'], theme),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: primaryColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r['problem'],
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          _infoRow(Icons.calendar_today, '${r['date']} • ${r['time']}', theme),
          _infoRow(Icons.attach_money, 'Rs. ' + r['amount'].toString(), theme),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      r['status'] = 'Rejected';
                      bookingHistory.insert(0, r);
                      bookingRequests.removeAt(index);
                    });
                  },
                  child: Text('Reject',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      r['status'] = 'Completed';
                      bookingHistory.insert(0, r);
                      bookingRequests.removeAt(index);
                    });
                  },
                  child: Text('Accept',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyView(String text, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 100),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}