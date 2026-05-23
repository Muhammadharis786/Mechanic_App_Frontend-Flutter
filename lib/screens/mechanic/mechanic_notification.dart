import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'mechanic_appointmentrequest.dart';
import 'mechanic_request_detail.dart';
import '../authentication/user_session.dart';
import '../../utils/time_utils.dart';

class MechanicNotificationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> dailyRequests;
  final List<Map<String, dynamic>> appointmentRequests;
  final int initialTabIndex;
  final VoidCallback? onReadUpdate;
  
  const MechanicNotificationScreen({
    super.key,
    required this.dailyRequests,
    required this.appointmentRequests,
    this.initialTabIndex = 0,
    this.onReadUpdate,
  });

  @override
  State<MechanicNotificationScreen> createState() =>
      _MechanicNotificationScreenState();
}

class _MechanicNotificationScreenState
    extends State<MechanicNotificationScreen>
    with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xFFFB3300);
  static const String _baseUrl =
      'https://mechanicapp-service-621632382478.asia-south1.run.app';
  
  late TabController _tabController;
  Timer? _refreshTimer;
  bool _isLoading = false;
  bool _hasFetchedOnce = false;

  List<dynamic> roadRequests = [];
  List<dynamic> appointmentNotifications = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    
    // Initialize with passed data but mark that we haven't fetched fresh data yet
    roadRequests = widget.dailyRequests;
    appointmentNotifications = widget.appointmentRequests;

    _fetchNotifications();

    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (mounted) _fetchNotifications();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/mechanic/appointments/allnotifications'),
        headers: UserSession().getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          if (mounted) {
            setState(() {
              appointmentNotifications = decoded;
              _isLoading = false;
              _hasFetchedOnce = true;
            });
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching mechanic notifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Only show unread count if we have fetched fresh data or if the initial data has unread items
    final int unreadCount = appointmentNotifications.where((r) => r['read'] == false || r['isread'] == false).length;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Notifications',
          style: GoogleFonts.getFont('Bricolage Grotesque',
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: primaryColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.w500, fontSize: 13),
          tabs: [
            Tab(text: 'DAILY'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('APPOINTMENTS'),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    _tabBadge(unreadCount),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading && !_hasFetchedOnce
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList(roadRequests, isDark),
                _buildNotificationList(appointmentNotifications, isDark),
              ],
            ),
    );
  }

  Widget _buildNotificationList(List<dynamic> list, bool isDark) {
    if (list.isEmpty && _hasFetchedOnce) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 64, color: isDark ? Colors.white12 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: GoogleFonts.getFont('Bricolage Grotesque', color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: list.length,
        itemBuilder: (context, index) {
          return _buildNotificationCard(list[index], isDark);
        },
      ),
    );
  }

  Widget _tabBadge(int count) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNotificationCard(dynamic notifData, bool isDark) {
    final Map<String, dynamic> notif = Map<String, dynamic>.from(notifData);
    final bool isRead = notif['read'] == true || notif['isread'] == true;
    final String type = notif['type']?.toString() ?? 'GENERAL_NOTIFICATION';
    final String message = notif['message']?.toString() ?? '';
    final String appointmentId = notif['appointmentId']?.toString() ?? notif['appointmentid']?.toString() ?? '';
    final String createdAt = notif['createdAt']?.toString() ?? notif['created_at']?.toString() ?? '';

    final _NotifStyle style = _getNotifStyle(type);

    return InkWell(
      onTap: () async {
        if (!isRead) {
          setState(() {
            notifData['read'] = true;
            notifData['isread'] = true;
          });
          widget.onReadUpdate?.call();
          final notificationId = notif['notificationId']?.toString() ?? notif['id']?.toString() ?? '';
          if (notificationId.isNotEmpty) {
            _markRead(notificationId);
          }
        }

        // Navigate based on type or just general appointment screen
        if (type == 'ROAD_REQUEST' || notif['type'] == 'road') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MechanicRequestDetailScreen(request: notif),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MechanicAppointmentRequestScreen(
                requests: const [], // Will fetch its own
                onReadUpdate: widget.onReadUpdate,
              ),
            ),
          ).then((_) => _fetchNotifications());
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead
              ? (isDark ? Colors.grey[900] : Colors.white)
              : (isDark ? style.color.withOpacity(0.08) : style.color.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(18),
          border: isRead
              ? Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200)
              : Border.all(color: style.color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: style.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: style.color, size: 22),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          style.title,
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                            fontSize: 14,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (appointmentId.isNotEmpty && appointmentId != 'null') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            appointmentId,
                            style: GoogleFonts.getFont('Bricolage Grotesque',
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(
                        TimeAgo.format(createdAt),
                        style: GoogleFonts.getFont('Bricolage Grotesque', fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NotifStyle _getNotifStyle(String type) {
    switch (type) {
      case 'ROAD_REQUEST':
        return _NotifStyle(icon: Icons.flash_on_rounded, color: Colors.red, title: 'Roadside Request');
      case 'APPOINTMENT_REQUEST':
        return _NotifStyle(icon: Icons.calendar_today_rounded, color: Colors.blue, title: 'Appointment Request');
      case 'APPOINTMENT_ACCEPTED':
        return _NotifStyle(icon: Icons.check_circle_rounded, color: Colors.green, title: 'Request Accepted');
      case 'APPOINTMENT_REJECTED':
        return _NotifStyle(icon: Icons.cancel_rounded, color: Colors.red, title: 'Request Rejected');
      case 'APPOINTMENT_CANCELLED':
        return _NotifStyle(icon: Icons.remove_circle_rounded, color: Colors.orange, title: 'Request Cancelled');
      case 'APPOINTMENT_COMPLETED':
        return _NotifStyle(icon: Icons.task_alt_rounded, color: Colors.blue, title: 'Service Completed');
      case 'APPOINTMENT_EXPIRED':
        return _NotifStyle(icon: Icons.timer_off_rounded, color: Colors.grey, title: 'Request Expired');
      case 'APPOINTMENT_REMINDER':
        return _NotifStyle(icon: Icons.alarm_rounded, color: Colors.amber, title: 'Service Reminder');
      case 'MECHANIC_ON_THE_WAY':
        return _NotifStyle(icon: Icons.directions_car_rounded, color: Colors.teal, title: 'Mechanic On The Way');
      case 'PAYMENT_SUCCESS':
        return _NotifStyle(icon: Icons.payments_rounded, color: Colors.green, title: 'Payment Success');
      case 'PAYMENT_FAILED':
        return _NotifStyle(icon: Icons.money_off_rounded, color: Colors.red, title: 'Payment Failed');
      case 'REVIEW_RECEIVED':
        return _NotifStyle(icon: Icons.star_rounded, color: Colors.amber, title: 'Review Received');
      default:
        return _NotifStyle(icon: Icons.notifications_rounded, color: Colors.blueGrey, title: 'Notification');
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await http.get(
        Uri.parse('$_baseUrl/api/mechanic/appointments/isread/$id'),
        headers: UserSession().getAuthHeader(),
      );
    } catch (e) {
      debugPrint("❌ Mark read error: $e");
    }
  }
}

class _NotifStyle {
  final IconData icon;
  final Color color;
  final String title;
  const _NotifStyle({required this.icon, required this.color, required this.title});
}
