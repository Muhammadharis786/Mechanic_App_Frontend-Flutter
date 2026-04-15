import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'mechanic_request_detail.dart';

class MechanicNotificationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> liveRequests;
  
  const MechanicNotificationScreen({super.key, required this.liveRequests});

  @override
  State<MechanicNotificationScreen> createState() =>
      _MechanicNotificationScreenState();
}

class _MechanicNotificationScreenState
    extends State<MechanicNotificationScreen>
    with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xFFFB3300);
  late TabController _tabController;

  // 🔹 Road Request Notifications (Emergency)
  List<Map<String, dynamic>> roadRequests = [];

  // 🔹 Appointment Notifications
  final List<Map<String, dynamic>> appointmentRequests = [
    {
      'id': 'appt_001',
      'type': 'appointment',
      'userName': 'Ahmed Raza',
      'location': 'DHA Phase 6, Karachi',
      'time': '30 min ago',
      'issue': 'Brake pad replacement',
      'price': 'Rs. 2,500',
      'scheduledTime': 'Mon, 22 Apr at 10:00 AM',
      'isRead': true,
    },
    {
      'id': 'appt_002',
      'type': 'appointment',
      'userName': 'Hamna Ali',
      'location': 'Bahria Town, Islamabad',
      'time': '1 hr ago',
      'issue': 'Oil change & general service',
      'price': 'Rs. 3,000',
      'scheduledTime': 'Tue, 23 Apr at 02:00 PM',
      'isRead': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    roadRequests = widget.liveRequests;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flash_on_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('Daily Requests'),
                  if (roadRequests.any((r) => r['isRead'] == false)) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    )
                  ]
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available_rounded, size: 16),
                  const SizedBox(width: 6),
                  const Text('Appointments'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationList(roadRequests, isDark),
          _buildNotificationList(appointmentRequests, isDark),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> list, bool isDark) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No notifications yet.',
          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildNotificationCard(list[index], isDark);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif, bool isDark) {
    final bool isUnread = notif['isRead'] == false;
    final bool isRoad = notif['type'] == 'road';
    final String userimage = notif['userimage'] ?? '';
    final String userName = notif['userName'] ?? '';

    return GestureDetector(
      onTap: () {
        setState(() => notif['isRead'] = true);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MechanicRequestDetailScreen(request: notif),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark
                  ? primaryColor.withValues(alpha: 0.08)
                  : primaryColor.withValues(alpha: 0.04))
              : (isDark ? Colors.grey[850] : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: isUnread
              ? Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1)
              : (isDark ? Border.all(color: Colors.grey.shade800) : null),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 🔹 User Profile Image (like Facebook/WhatsApp)
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: userimage.isNotEmpty
                      ? NetworkImage(userimage)
                      : null,
                  child: userimage.isEmpty
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            color: primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                // Small type badge at bottom-right
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isRoad ? Colors.red : Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      isRoad ? Icons.flash_on_rounded : Icons.event_available_rounded,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // 🔹 Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        notif['time'] ?? '',
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif['issue'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 13, color: Colors.grey),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          notif['location'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (notif['distance'] != null && notif['distance'] != '') ...[
                        const SizedBox(width: 6),
                        Text(
                          notif['distance'],
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
