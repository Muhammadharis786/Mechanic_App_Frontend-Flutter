import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../authentication/user_session.dart';
import '../../widgets/app_back_button.dart';

class UserNotificationScreen extends StatefulWidget {
  const UserNotificationScreen({super.key});

  @override
  State<UserNotificationScreen> createState() => _UserNotificationScreenState();
}

class _UserNotificationScreenState extends State<UserNotificationScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  static const String _baseUrl =
      'https://mechanicapp-service-621632382478.asia-south1.run.app';

  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/appointments/allnotifications'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        setState(() {
          _notifications = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('❌ Error fetching user notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Notifications',
          style: GoogleFonts.getFont('Bricolage Grotesque',
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? Colors.white70 : Colors.black54),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : _notifications.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(
                          _notifications[index], isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(dynamic notif, bool isDark) {
    final Map<String, dynamic> n =
        notif is Map ? Map<String, dynamic>.from(notif) : {};

    final String type = n['type']?.toString() ?? '';
    final String message = n['message']?.toString() ?? '';
    final String appointmentId = n['appointmentid']?.toString() ?? '';
    final bool isRead = n['isread'] == true || n['read'] == true;
    final String createdAt = n['created_at']?.toString() ?? n['createdAt']?.toString() ?? '';

    final _NotifStyle style = _getNotifStyle(type);

    return InkWell(
      onTap: () async {
        if (!isRead) {
          // Mark as read locally
          setState(() {
            notif['isread'] = true;
            notif['read'] = true;
          });

          // Call API
          try {
            final notifId = n['notificationid'] ?? n['notificationId'];
            if (notifId != null) {
              await http.get(
                Uri.parse('$_baseUrl/api/user/appointments/isread/$notifId'),
                headers: UserSession().getAuthHeader(),
              );
            }
          } catch (e) {
            debugPrint('❌ Error marking read: $e');
          }
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
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: style.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (appointmentId.isNotEmpty &&
                          appointmentId != 'null') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[800]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            appointmentId,
                            style: GoogleFonts.getFont('Bricolage Grotesque',
                                fontSize: 11,
                                color: primaryColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(Icons.access_time_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(
                        _formatTime(createdAt),
                        style: GoogleFonts.getFont('Bricolage Grotesque',
                            fontSize: 11, color: Colors.grey),
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
      case 'APPOINTMENT_ACCEPTED':
        return _NotifStyle(
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          title: 'Appointment Accepted',
        );
      case 'APPOINTMENT_REJECTED':
        return _NotifStyle(
          icon: Icons.cancel_rounded,
          color: Colors.red,
          title: 'Appointment Rejected',
        );
      case 'APPOINTMENT_CANCELLED':
        return _NotifStyle(
          icon: Icons.remove_circle_rounded,
          color: Colors.orange,
          title: 'Appointment Cancelled',
        );
      case 'APPOINTMENT_COMPLETED':
        return _NotifStyle(
          icon: Icons.task_alt_rounded,
          color: Colors.blue,
          title: 'Appointment Completed',
        );
      case 'MECHANIC_ON_THE_WAY':
        return _NotifStyle(
          icon: Icons.directions_car_rounded,
          color: Colors.teal,
          title: 'Mechanic On The Way',
        );
      case 'APPOINTMENT_EXPIRED':
        return _NotifStyle(
          icon: Icons.timer_off_rounded,
          color: Colors.grey,
          title: 'Appointment Expired',
        );
      case 'APPOINTMENT_REMINDER':
        return _NotifStyle(
          icon: Icons.alarm_rounded,
          color: Colors.amber,
          title: 'Appointment Reminder',
        );
      case 'PAYMENT_SUCCESS':
        return _NotifStyle(
          icon: Icons.payments_rounded,
          color: Colors.green,
          title: 'Payment Successful',
        );
      case 'PAYMENT_FAILED':
        return _NotifStyle(
          icon: Icons.money_off_rounded,
          color: Colors.red,
          title: 'Payment Failed',
        );
      case 'REVIEW_RECEIVED':
        return _NotifStyle(
          icon: Icons.star_rounded,
          color: Colors.amber,
          title: 'Review Received',
        );
      default:
        return _NotifStyle(
          icon: Icons.notifications_rounded,
          color: Colors.blueGrey,
          title: 'Notification',
        );
    }
  }

  String _formatTime(String rawTime) {
    if (rawTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawTime).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month]}';
    } catch (_) {
      return rawTime;
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.getFont('Bricolage Grotesque',
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _NotifStyle {
  final IconData icon;
  final Color color;
  final String title;
  const _NotifStyle(
      {required this.icon, required this.color, required this.title});
}
