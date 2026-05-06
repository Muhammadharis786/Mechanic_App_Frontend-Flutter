// Merged Version: API Logic + Design Updates

import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mech_app/main.dart';
import 'package:mech_app/screens/mechanic/mechanic_login.dart';
import 'package:mech_app/screens/mechanic/mechanic_dashboard.dart';
import 'package:mech_app/screens/user/book_appointments_menubar.dart';
import 'package:mech_app/screens/user/my_request_menubar.dart';
import 'package:mech_app/screens/user/settings_menubar.dart';
import 'package:mech_app/screens/user/view_detail.dart';
import 'package:mech_app/screens/user/user_profile.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import './authentication/service_chat_screen.dart';
import './authentication/user_session.dart';
import 'auto_assign.dart';
import 'mechanic_list_screen.dart';
import 'role_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key} );

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  
  // State variables
  String _userName = "Loading...";
  int? _userId;
  String _userImgUrl = "";
  bool _isLoading = true;
  List<Map<String, dynamic>> nearbyMechanics = [];
  String? _mechanicsMessage;

  // ---- Filter State ----
  String _selectedFilter = "All";
  final List<String> _filterOptions = ["All", "Puncher", "Bike Mechanic", "Car Mechanic"];

  List<Map<String, dynamic>> get _filteredMechanics {
    if (_selectedFilter == "All") return nearbyMechanics;
    return nearbyMechanics
        .where((m) => (m['MechanicType'] ?? '').toString() == _selectedFilter)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/dashboard" );

    try {
      final headers = UserSession().getAuthHeader();
      debugPrint('ðŸ”‘ Auth Header: ${headers['Authorization']}');
      debugPrint('ðŸ”‘ UserSession: email=${UserSession().email}, userType=${UserSession().userType}');
      
      final response = await http.get(
        url,
        headers: headers,
      );

      debugPrint('ðŸ“¡ Dashboard Response Status: ${response.statusCode}');
      debugPrint('ðŸ“¡ Dashboard Response Body: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Handle both flat and nested response formats
        final user = data['user'] ?? data; // If no 'user' key, data itself is the user object
        debugPrint('âœ… Dashboard data parsed. User: ${user['username']}');
        
        setState(() {
          if (user['username'] != null || user['userid'] != null) {
            _userName = user['username'] ?? "User";
            _userId = user['userid'];
            _userImgUrl = user['userimgurl'] ?? "";
            UserSession().userId = user['userid'];
          }
          
          if (data['mechanics'] != null) {
            if (data['mechanics'] is String) {
              _mechanicsMessage = data['mechanics'];
              nearbyMechanics = [];
            } else if (data['mechanics'] is List) {
              _mechanicsMessage = null;
              nearbyMechanics = List<Map<String, dynamic>>.from(
                (data['mechanics'] as List).map((m) => {
                  "id": m['id'] ?? 0,
                  "name": m['name'] ?? "Unknown Mechanic",
                  "averagerating": (m['averagerating'] as num?)?.toDouble() ?? 0.0,
                  "distance": (m['distance'] as num?)?.toDouble() ?? 0.0,
                  "isactive": m['isactive'] ?? false, 
                  "mechanicimgurl": m['mechanicimgurl'] ?? "assets/images/m1.jpg",
                  "phonenumber": m['phonenumber'] ?? "",
                  "MechanicType": m['MechanicType'] ?? "N/A",
                  "experience": m['experience'] ?? 0,
                  "isengaged": m['isengaged'] ?? false,
                  "mechaniclocname": m['mechaniclocname'] ?? "",
                  "latitude": (m['latitude'] is String) ? double.tryParse(m['latitude']) ?? 0.0 : (m['latitude'] as num?)?.toDouble() ?? 0.0,
                  "longitude": (m['longitude'] is String) ? double.tryParse(m['longitude']) ?? 0.0 : (m['longitude'] as num?)?.toDouble() ?? 0.0,
                })
              );
            }
          }
          _isLoading = false;
        });
      } else {
        debugPrint("âŒ Failed to fetch dashboard: ${response.statusCode}");
        debugPrint("âŒ Response body: ${response.body}");
        setState(() {
          _userName = "USER";
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard: $e");
      setState(() {
        _userName = "USER";
        _isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      drawer: _buildDrawer(context, isDark),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 1,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: primaryColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello ",
              style: TextStyle(fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily, fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
            _isLoading
                ? Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(
                      width: 100,
                      height: 20,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _userName,
                    style: TextStyle(
                        fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                        fontSize: 18, 
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black),
                  ),
            if (!_isLoading && _userId != null)
              Text(
                "ID: $_userId",
                style: TextStyle(fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily, fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),

      body: _isLoading 
          ? const _SkeletonHomeBody()
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -------- Auto Assign --------
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                            colors: [primaryColor, Colors.deepOrange]),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Need a Mechanic Now?",
                              style: TextStyle(
                                  fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Text("Nearest mechanic will be auto assigned",
                              style: TextStyle(fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily, color: Colors.white70, fontWeight: FontWeight.w400)),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AutoAssignScreen()),
                              );
                            },
                            child: Text("Auto Assign Mechanic",
                                style: TextStyle(
                                    fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFFFB3300))),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // -------- Nearby Mechanics --------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Nearby Mechanics",
                            style: TextStyle(
                                fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                fontSize: 20, 
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black)),
                        if (_mechanicsMessage == null)
                          InkWell(
                            onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MechanicListScreen(
                                      serviceType: _selectedFilter == "All" ? "Nearby Mechanics" : _selectedFilter,
                                      mechanics: _filteredMechanics,
                                      showViewOption: true,
                                    ),
                                  ),
                                );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[850] : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                "See All",
                                style: TextStyle(
                                    fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          )
                      ],
                    ),

                    // -------- Filter Chips --------
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filterOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final label = _filterOptions[index];
                          final isSelected = _selectedFilter == label;
                          final IconData chipIcon;
                          switch (label) {
                            case 'Puncher':
                              chipIcon = Icons.tire_repair_outlined;
                              break;
                            case 'Bike Mechanic':
                              chipIcon = Icons.two_wheeler_outlined;
                              break;
                            case 'Car Mechanic':
                              chipIcon = Icons.directions_car_outlined;
                              break;
                            default:
                              chipIcon = Icons.handyman_outlined;
                          }
                          return GestureDetector(
                            onTap: () => setState(() => _selectedFilter = label),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor
                                    : (isDark ? Colors.grey[850] : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                                    : [],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    chipIcon,
                                    size: 14,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_mechanicsMessage != null || _filteredMechanics.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.handyman_outlined, 
                              size: 44, 
                              color: isDark ? Colors.white54 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _mechanicsMessage ?? (_selectedFilter == "All"
                                  ? "No mechanics available right now"
                                  : "No $_selectedFilter mechanics nearby"),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white54 : Colors.grey,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      )
                    else 
                      SizedBox(
                        height: 165,
                        child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filteredMechanics.length,
                            itemBuilder: (context, index) {
                              return _NearbyMechanicCompactCard(
                                mechanic: _filteredMechanics[index],
                                primaryColor: primaryColor,
                                isDark: isDark,
                              );
                            },
                          ),
                      ),

                    const SizedBox(height: 30),

                    // -------- Service Categories --------
                    Text("Service Categories",
                        style: TextStyle(
                            fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                            fontSize: 20, 
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 16),

                    _serviceCard(context, "Bike Mechanic", 2 ,'assets/images/bike.jpg', isDark),
                    const SizedBox(height: 16),
                    _serviceCard(context, "Car Mechanic", 3,'assets/images/car.jpg', isDark),
                    const SizedBox(height: 16),   
                     
                    _serviceCard(context, "Puncher", 4, 'assets/images/puncherr.jpg', isDark),
                  ],
                ),
              ),
            ),
    );
  }

  // ================= SERVICE CARD =================
  Widget _serviceCard(BuildContext context, String title, int id, String image, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServiceChatScreen(serviceType: title, id: id)),
        );
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
        ),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
              color: Colors.white,
              fontSize: 26, // Increased size slightly to compensate for tight spacing
              fontWeight: FontWeight.w900, // Make it as bold as possible
              // TIGHT character spacing like Yango
              height: 1.0, 
            ),
          ),
        ),
      ),
    );
  }

  // ================= DRAWER =================
  Drawer _buildDrawer(BuildContext context, bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24, right: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _userImgUrl.isNotEmpty && _userImgUrl.startsWith('http')
                        ? NetworkImage(_userImgUrl)
                        : const AssetImage('assets/images/user.jpg') as ImageProvider,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoading ? "Loading..." : _userName,
                        style: TextStyle(
                          fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "User Account",
                        style: TextStyle(
                          fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                          color: Colors.white.withOpacity(0.8), 
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
                _drawerItem(Icons.grid_view_outlined, "DashBoard", context, isDark: isDark, isSelected: true, onTap: () {
                  Navigator.pop(context);
                }),
                _drawerItem(Icons.person_outline_rounded, "My Profile", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen()));
                }),
                _drawerItem(Icons.history_outlined, "Request History", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RequestHistoryScreen()), (route) => false);
                }),
                _drawerItem(Icons.calendar_today_outlined, "Book Appointments", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const BookAppointmentScreen()), (route) => false);
                }),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, thickness: 1),
                ),
                
                _drawerItem(Icons.settings_outlined, "Settings", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SettingsMenuBar()), (route) => false);
                }),
                _drawerItem(Icons.logout_outlined, "Logout", context, isDark: isDark, isLogout: true, onTap: () async {
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
                                   style: TextStyle(
                                     fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                     fontSize: 14, 
                                     fontWeight: FontWeight.w400,
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
                if (await UserSession().trySwitchTo('MECHANIC')) {
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
                      (route) => false,
                    );
                  }
                } else {
                  if (context.mounted) {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const MechanicLoginScreen())
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
                    Icon(Icons.swap_horiz_outlined, color: primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Return to Mechanic',
                      style: TextStyle(
                          fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                          color: Color(0xFFFB3300), 
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
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

  Widget _drawerItem(IconData icon, String title, BuildContext context, 
      {bool isLogout = false, required bool isDark, bool isSelected = false, VoidCallback? onTap}) {
    
    final Color itemColor = isLogout ? Colors.red : (isDark ? Colors.white70 : Colors.black87);
    final Color selectedBgColor = isDark ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.1);
    final Color selectedTextColor = primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? selectedBgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isSelected ? selectedTextColor : itemColor),
        title: Text(title, style: TextStyle(
          fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
          color: isSelected ? selectedTextColor : itemColor,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400
        )),
      ),
    );
  }
}

// ================= SKELETON LOADING =================
class _SkeletonHomeBody extends StatelessWidget {
  const _SkeletonHomeBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Column(
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  height: 30,
                  width: 150,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 165,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 245,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= MECHANIC CARD (UPDATED) =================
class _NearbyMechanicCompactCard extends StatelessWidget {
  final Map<String, dynamic> mechanic;
  final Color primaryColor;
  final bool isDark;

  const _NearbyMechanicCompactCard({
    required this.mechanic,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = mechanic['mechanicimgurl']?.toString() ?? '';

    return Container(
      width: 245,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // ===== YEH HISSA TABDEEL HUA HAI =====
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey.shade200,
                child: ClipOval(
                  child: imageUrl.startsWith('http' )
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Error ko console mein print karein
                            debugPrint('Image Load Error for ${mechanic['name']}: $error');
                            return Icon(Icons.person_outline_rounded, size: 24, color: Colors.grey.shade400);
                          },
                        )
                      : Image.asset( // Fallback agar URL nahi hai
                          'assets/images/m1.jpg',
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                        ),
                ),
              ),
              // =====================================
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mechanic['name'],
                        style: TextStyle(
                            fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                            fontWeight: FontWeight.w700, 
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 2),
                    Text(mechanic['MechanicType'],
                        style: TextStyle(
                            fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                            color: isDark ? Colors.white70 : Colors.grey.shade600, 
                            fontSize: 12,
                            fontWeight: FontWeight.w400)),
                    const SizedBox(height: 4),         
                    Row(
                      children: [
                        const Icon(Icons.star_outline_rounded, size: 14, color: Colors.amber),
                        Text("${mechanic['averagerating']}",
                            style: TextStyle(
                                fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_outlined, size: 14, color: primaryColor),
                        Text("${mechanic['distance']} km",
                            style: TextStyle(
                                fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: mechanic['isactive'] ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _actionButton(Icons.call_rounded, "Call", Colors.green, () async {
                final phone = mechanic['phonenumber'] as String?;
                if (phone != null && phone.isNotEmpty) {
                  final Uri launchUri = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(launchUri)) {
                    await launchUrl(launchUri);
                  }
                }
              }),
              _actionButton(Icons.remove_red_eye_rounded, "View", primaryColor, () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MechanicDetailScreen(
                      mechanic: Mechanic(
                        id: mechanic['id'].toString(),
                        name: mechanic['name'],
                        mechanictype : mechanic['MechanicType'],
                        avatarUrl: mechanic['mechanicimgurl'],
                        rating: (mechanic['averagerating'] as num).toDouble(),
                        distanceKm: (mechanic['distance'] as num).toDouble(),
                        isOnline: mechanic['isactive'] ?? false,
                        phone: mechanic['phonenumber'] ?? "",
                        lat: mechanic['latitude'] ?? 0.0,
                        lng: mechanic['longitude'] ?? 0.0,
                        experienceYears: mechanic['experience'] ?? 0,
                        mechanicLocName: mechanic['mechaniclocname'] ?? "Unknown Location",
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}



