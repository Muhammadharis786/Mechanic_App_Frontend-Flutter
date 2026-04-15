import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'mechanic_bookingrequest.dart';
import 'mechanic_earnings.dart';
import 'mechanic_profile.dart';
import 'mechanic_settings.dart';
import 'mechanic_notification.dart';
import 'mechanic_services.dart';
import 'mechanic_appointmentrequest.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../authentication/user_session.dart';
import '../role_selection_screen.dart';
import '../../services/websocket_service.dart'; // Re-adding websocket

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  final Color primaryColor = const Color(0xFFE64A19);
  final Color accentOrange = const Color(0xFFFF6D00);

  bool _isLoading = true;

  double totalEarnings = 0;
  double todaysEarnings = 0;
  int totalServices = 0;
  int todaysServices = 0;
  double mechanicRating = 0;
  String mechanicName = "Mechanic";
  String mechanicImageUrl = '';

  late WebSocketService _webSocketService;
  int _notificationCount = 0;
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _initWebSocket();
  }

  void _initWebSocket() {
    if (UserSession().userId == null) {
      debugPrint("❌ Mechanic Dashboard: User ID is null, cannot connect to WebSocket");
      return;
    }

    _webSocketService = WebSocketService(
      onNotificationReceived: (data) {
        setState(() {
          _notificationCount++;
          _notifications.insert(0, {
            'type': 'road',
            'id': data['userid']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'userName': data['username'] ?? 'Unknown User',
            'location': data['userlocname'] ?? 'Location not provided',
            'time': data['eta'] != null ? 'ETA: ${data['eta']}' : "Just now",
            'issue': 'Emergency Roadside Assistance',
            'price': data['price'] != null ? 'Rs. ${data['price']}' : 'Rs. 1,200',
            'distance': data['distance'] != null ? '${data['distance']} km away' : '',
            'userimage': data['userimage'] ?? '',
            'lat': data['lat'],
            'lon': data['lon'],
            'isRead': false,
          });
        });
        _showNotificationOverlay(data);
      },
    );
    // Use the ID strictly from UserSession saved at Login
    _webSocketService.connect(UserSession().userId!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showNotificationOverlay(Map<String, dynamic> data) {
    _removeOverlay(); // Purana overlay pehle hata do

    final String userName = data['username'] ?? 'New Request';
    final String location = data['userlocname'] ?? 'Nearby location';
    final String userimage = data['userimage'] ?? '';
    final String distance  = data['distance'] != null ? '${data['distance']} km away' : '';

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Row(
              children: [
                // User Image
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: userimage.isNotEmpty
                      ? NetworkImage(userimage)
                      : null,
                  child: userimage.isEmpty
                      ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔔 New Service Request!',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                      Text(userName,
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
                      if (distance.isNotEmpty)
                        Text(distance,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                      Text(location,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // View Button
                GestureDetector(
                  onTap: () {
                    _removeOverlay();
                    setState(() => _notificationCount = 0);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MechanicNotificationScreen(liveRequests: _notifications)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('View', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // 5 seconds baad auto-remove
    Future.delayed(const Duration(seconds: 5), _removeOverlay);
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    _removeOverlay();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/dashboard");

    try {
      final response =
          await http.get(url, headers: UserSession().getAuthHeader());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          mechanicName = data['name'] ?? mechanicName;
          mechanicRating =
              (data['averageRating'] as num?)?.toDouble() ?? mechanicRating;
          totalEarnings =
              (data['totalearning'] as num?)?.toDouble() ?? totalEarnings;
          todaysEarnings =
              (data['todaysEarnings'] as num?)?.toDouble() ??
                  todaysEarnings;
          totalServices =
              (data['totalServices'] as num?)?.toInt() ?? totalServices;
          mechanicImageUrl = data['mechanicimgurl'] ?? '';
          todaysServices =
              (data['todaysServices'] as num?)?.toInt() ??
                  todaysServices;

          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ??
                theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
      ),
      drawer: _buildDrawer(isDark, theme),
      body: _isLoading
          ? const _SkeletonMechanicDashboard()
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    /// HEADER 
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, $mechanicName 👋',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.titleLarge?.color,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() => _notificationCount = 0);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => MechanicNotificationScreen(liveRequests: _notifications)));
                              },
                              icon: Icon(Icons.notifications_outlined, color: primaryColor, size: 28),
                            ),
                            if (_notificationCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    '$_notificationCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    /// OVERVIEW
                    Text(
                      'Overview',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 14),

                    /// VERTICAL CARDS
                    Column(
                      children: [
                        _statCard(
                          label: "Today's Services",
                          value: todaysServices.toString(),
                          icon: Icons.build_circle_rounded,
                          accentColor: primaryColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),

                        _statCard(
                          label: "Today's Earnings",
                          value:
                              'Rs. ${todaysEarnings.toStringAsFixed(0)}',
                          icon: Icons.trending_up_rounded,
                          accentColor: const Color(0xFF1E88E5),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),

                        _statCard(
                          label: 'Total Earnings',
                          value:
                              'Rs. ${totalEarnings.toStringAsFixed(0)}',
                          icon:
                              Icons.account_balance_wallet_rounded,
                          accentColor: const Color(0xFF43A047),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),

                        _statCard(
                          label: 'Total Services',
                          value: totalServices.toString(),
                          icon: Icons.handyman_rounded,
                          accentColor: const Color(0xFF9C27B0),
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  /// STAT CARD
  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: isDark ? 0.30 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark ? Border.all(color: Colors.grey.shade800, width: 1) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= DRAWER STYLED =================
  Widget _drawerItem(IconData icon, String title, BuildContext context, 
      {bool isLogout = false, required bool isDark, bool isSelected = false, VoidCallback? onTap}) {
    
    final Color itemColor = isLogout ? Colors.red : (isDark ? Colors.white70 : Colors.black87);
    final Color selectedBgColor = isDark ? primaryColor.withValues(alpha: 0.15) : primaryColor.withValues(alpha: 0.1);
    final Color selectedTextColor = primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? selectedBgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon, 
          color: isSelected ? selectedTextColor : itemColor, 
          size: 24
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: isSelected ? selectedTextColor : itemColor,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minLeadingWidth: 20,
      ),
    );
  }

  // Updated elegant drawer
  Drawer _buildDrawer(bool isDark, ThemeData theme) {
    return Drawer(
      backgroundColor: theme.drawerTheme.backgroundColor ??
          (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: mechanicImageUrl.isNotEmpty
                        ? NetworkImage(mechanicImageUrl)
                        : const AssetImage('assets/images/m1.jpg') as ImageProvider,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoading ? "Loading..." : mechanicName,
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Mechanic Account",
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, 
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _drawerItem(Icons.dashboard_customize_rounded, "Dashboard", context, isDark: isDark, isSelected: true, onTap: () {
                  Navigator.pop(context);
                }),
                _drawerItem(Icons.calendar_today_rounded, "Appointment Requests", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicAppointmentRequestScreen()));
                }),
                _drawerItem(Icons.event_note_rounded, "Booking Requests", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicBookingRequestScreen()));
                }),
                _drawerItem(Icons.account_balance_wallet_rounded, "Earnings", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicEarningsScreen()));
                }),
                _drawerItem(Icons.build_rounded, "Services", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicServicesScreen()));
                }),
                _drawerItem(Icons.person_outline_rounded, "Profile", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicProfileScreen()));
                }),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, thickness: 1),
                ),
                
                _drawerItem(Icons.settings_outlined, "Settings", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicSettingsScreen()));
                }),
                _drawerItem(Icons.logout_rounded, "Logout", context, isDark: isDark, isLogout: true, onTap: () async {
                  final nav = Navigator.of(context);
                  await UserSession().logout();
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                    (route) => false,
                  );
                }),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: InkWell(
              onTap: () async {
                final nav = Navigator.of(context);
                // Switch backend role cache logic
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.05),
                      blurRadius: 10, offset: const Offset(0, 4)
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Return to User',
                      style: GoogleFonts.poppins(
                          color: primaryColor, 
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
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
}

class _SkeletonMechanicDashboard extends StatelessWidget {
  const _SkeletonMechanicDashboard();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: List.generate(
            4,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}