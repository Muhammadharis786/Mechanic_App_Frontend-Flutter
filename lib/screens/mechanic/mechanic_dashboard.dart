import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

// Screens imports
import 'mechanic_bookingrequest.dart';
import 'mechanic_earnings.dart';
import 'mechanic_profile.dart';
import 'mechanic_login.dart';
import 'mechanic_settings.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../authentication/user_session.dart'; // Farz hai ke is file mein getPhoneNumber( ) aur getAuthHeader() hain
import '../homescreen.dart';
import '../role_selection_screen.dart';
import '../../services/websocket_service.dart';

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  // Hardcoded requests, jaisa aapke original code mein tha
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

  // --- TABDEELI #1: State Variables ko API ke mutabiq update kiya ---
  bool _isLoading = true;
  double totalEarnings = 0;
  double todaysEarnings = 0; // Note: API se yeh field nahi aa raha
  double mechanicRating = 0;
  String mechanicName = "Mechanic";
  String mechanicImageUrl = ''; // Profile image ka URL save karne ke liye
  
  late WebSocketService _webSocketService;
  int _notificationCount = 0;
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
          _notifications.insert(0, data);
        });
        _showNotificationOverlay(data);
      },
    );
    // Use the ID strictly from UserSession saved at Login
    _webSocketService.connect(UserSession().userId!);
  }

  void _showNotificationOverlay(Map<String, dynamic> data) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("New Service Request!", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("User: ${data['username'] ?? 'Unknown'} (ID: ${data['userid']})"),
          ],
        ),
        backgroundColor: primaryColor,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: "View",
          textColor: Colors.white,
          onPressed: () => _openLiveNotifications(),
        ),
      ),
    );
  }

  void _openLiveNotifications() {
    setState(() => _notificationCount = 0);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _buildNotificationList(),
    );
  }

  Widget _buildNotificationList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Notifications", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text("No new requests", style: GoogleFonts.poppins(color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final n = _notifications[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text("Service Request", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    subtitle: Text("User: ${n['username']} (ID: ${n['userid']})"),
                    leading: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.1), child: Icon(Icons.build_outlined, color: primaryColor)),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    super.dispose();
  }

  // --- TABDEELI #2: API call ko theek kiya ---
  Future<void> _fetchDashboardData() async {
    // Farz hai ke UserSession se phone number mil jayega
    
    debugPrint("🔄 Mechanic Dashboard: Starting to fetch data, _isLoading = $_isLoading");

    // API URL mein phone number as a query parameter bhejein
    // **IMPORTANT**: Agar aap physical device par test kar rahe hain to 'localhost' ke bajaye apne computer ka IP address likhein
    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/dashboard" );

    try {
      // Basic Auth header UserSession se aayega
      final response = await http.get(url, headers: UserSession( ).getAuthHeader());  

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // setState ke andar UI update karein
        setState(() {
          // API se aane wale data ko state variables mein save karein
          mechanicName = data['name'] ?? mechanicName;
          mechanicRating = (data['averageRating'] as num?)?.toDouble() ?? mechanicRating;
          totalEarnings = (data['totalearning'] as num?)?.toDouble() ?? totalEarnings;

          // Image URL ko state variable mein save karein
          mechanicImageUrl = data['mechanicimgurl'] ?? '';
          _isLoading = false;
          debugPrint("✅ Mechanic Dashboard: Data loaded successfully, _isLoading = $_isLoading");
          
          // Capture numeric ID if present
          if (data.containsKey('id')) {
            UserSession().setUserId(data['id']);
          }
        });
      } else {
        // Agar server se error aaye (jaise 404 Not Found ya 401 Unauthorized)
        debugPrint("Failed to load dashboard data. Status code: ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
        setState(() {
          _isLoading = false;
          debugPrint("❌ Mechanic Dashboard: Error loading data, _isLoading = $_isLoading");
        });
      }
    } catch (e) {
      // Connection error ya doosre masail ke liye
      debugPrint("Error fetching dashboard data: $e");
      setState(() {
        _isLoading = false;
        debugPrint("❌ Mechanic Dashboard: Exception occurred, _isLoading = $_isLoading");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded,
                    color: primaryColor, size: 28),
                onPressed: _openLiveNotifications,
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
          const SizedBox(width: 10),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const _SkeletonMechanicDashboard()
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dashboard',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        IconButton(
                          onPressed: _fetchDashboardData,
                          icon: Icon(Icons.refresh_rounded, color: primaryColor),
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
                          _statItem("Today's Earnings", todaysEarnings),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'Quick Actions',
                      style:
                          GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _actionCard('Requests', Icons.pending_actions, Colors.blue, theme, () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MechanicBookingRequestScreen()));
                        }),
                        const SizedBox(width: 15),
                        _actionCard('My Wallet', Icons.account_balance_wallet,
                            Colors.green, theme, () {
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
                          GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color),
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
                                _jobTile(requests[index], theme),
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  // Baaki ka code (widgets, drawer, etc.) bilkul waisa hi hai, usmein koi tabdeeli nahi ki.

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
      String title, IconData icon, Color color, ThemeData theme, VoidCallback onTap) {
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

  Widget _jobTile(Map<String, dynamic> r, ThemeData theme) {
    bool isPending = r['status'] == 'Pending';
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100),
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
                        fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.titleMedium?.color)),
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
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
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
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withOpacity(0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    backgroundImage: mechanicImageUrl.isNotEmpty ? NetworkImage(mechanicImageUrl) : null,
                    child: mechanicImageUrl.isEmpty ? Icon(Icons.person, color: primaryColor, size: 35) : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mechanicName,
                        style: GoogleFonts.poppins(
                          color: theme.textTheme.titleLarge?.color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "$mechanicRating Rating",
                            style: GoogleFonts.poppins(
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                _drawerItem(Icons.grid_view_outlined, 'Overview', isDark: isDark, isSelected: true, onTap: () {
                   Navigator.pop(context);
                }),
                _drawerItem(Icons.pending_actions_outlined, 'Requests', isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicBookingRequestScreen()));
                }),
                _drawerItem(Icons.account_balance_wallet_outlined, 'Earnings', isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicEarningsScreen()));
                }),
                _drawerItem(Icons.person_outline_rounded, 'Profile', isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicProfileScreen()));
                }),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, thickness: 1),
                ),
                
                _drawerItem(Icons.settings_outlined, 'Settings', isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MechanicSettingsScreen(),
                    ),
                  );
                }),
                _drawerItem(Icons.logout_outlined, 'Logout', isDark: isDark, isLogout: true, onTap: () async {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(color: Colors.black.withOpacity(0.3)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 const CircularProgressIndicator(color: Color(0xFFFB3300)),
                                 const SizedBox(height: 16),
                                 Text("Logging out...", 
                                  style: GoogleFonts.poppins(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.none,
                                    color: isDark ? Colors.white : Colors.black
                                  )
                                 )
                               ],
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  await Future.delayed(const Duration(seconds: 1)); 
                  await UserSession().logout();

                  if (context.mounted) {
                    Navigator.pop(context); 
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                      (route) => false,
                    );
                  }
                }),
              ],
            ),
          ),

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
                      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.05),
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
                      'Switch to User Mode',
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

  Widget _drawerItem(IconData icon, String title, 
      {bool isLogout = false, required bool isDark, bool isSelected = false, VoidCallback? onTap}) {
    
    final Color itemColor = isLogout ? Colors.red : (isDark ? Colors.white70 : Colors.grey.shade700);
    final Color selectedBgColor = isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.1);
    final Color selectedTextColor = primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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

  void _openPendingRequests() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
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
                          fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
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
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['user'] ?? 'Unknown User',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: theme.textTheme.titleMedium?.color)),
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

// ================= SKELETON LOADING =================
class _SkeletonMechanicDashboard extends StatelessWidget {
  const _SkeletonMechanicDashboard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[850]! : Colors.grey.shade300,
        highlightColor: isDark ? Colors.grey[800]! : Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 24,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 25),
            
            // Earnings Card Skeleton
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 30),
            
            // Quick Actions Title
            Container(
              width: 120,
              height: 20,
              color: Colors.white,
            ),
            const SizedBox(height: 15),
            
            // Action Cards Skeleton
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            
            // Recent Jobs Title
            Container(
              width: 100,
              height: 20,
              color: Colors.white,
            ),
            const SizedBox(height: 15),
            
            // Job Cards Skeleton
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
