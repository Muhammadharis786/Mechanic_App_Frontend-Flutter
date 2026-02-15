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
import 'verify_screen.dart';

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
  bool _isLoading = true;
  File? _profileImage;
  List<Map<String, dynamic>> nearbyMechanics = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/dashboard" );

    try {
      final response = await http.get(
        url,
        headers: UserSession( ).getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          if (data['user'] != null) {
            _userName = data['user']['username'] ?? "User";
            _userId = data['user']['userid'];
            UserSession().userId = data['user']['userid'];
          }
          
          if (data['mechanics'] != null) {
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
          _isLoading = false;
        });
      } else {
        debugPrint("Failed to fetch dashboard: ${response.statusCode}");
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      drawer: _buildDrawer(context, isDark),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 1,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: primaryColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hello 👋",
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
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
                    style: GoogleFonts.poppins(
                        fontSize: 18, 
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black),
                  ),
            if (!_isLoading && _userId != null)
              Text(
                "ID: $_userId",
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),

      body: _isLoading 
          ? const _SkeletonHomeBody()
          : SingleChildScrollView(
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
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text("Nearest mechanic will be auto assigned",
                            style: GoogleFonts.poppins(color: Colors.white70)),
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
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500)),
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
                          style: GoogleFonts.poppins(
                              fontSize: 20, 
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black)),
                      InkWell(
                        onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MechanicListScreen(
                                  serviceType: "Nearby Mechanics",
                                  mechanics: nearbyMechanics,
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
                            style: GoogleFonts.poppins(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 165,
                    child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: nearbyMechanics.length,
                        itemBuilder: (context, index) {
                          return _NearbyMechanicCompactCard(
                            mechanic: nearbyMechanics[index],
                            primaryColor: primaryColor,
                            isDark: isDark,
                          );
                        },
                      ),
                  ),

                  const SizedBox(height: 30),

                  // -------- Service Categories --------
                  Text("Service Categories",
                      style: GoogleFonts.poppins(
                          fontSize: 20, 
                          fontWeight: FontWeight.w600,
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
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ================= DRAWER =================
  Drawer _buildDrawer(BuildContext context, bool isDark) {
    return Drawer(
      child: Container(
        color: isDark ? Colors.grey[900] : Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.white),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: _profileImage != null
                              ? FileImage(_profileImage!)
                              : const AssetImage('assets/images/user.jpg') as ImageProvider,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                            child: const Icon(Icons.add, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isLoading ? "Loading..." : _userName,
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "User",
                    style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            _drawerItem(Icons.dashboard_customize_rounded, "DashBoard", context,
                onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                  context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
            }),
            _drawerItem(Icons.person_rounded, "My Profile", context, onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const UserProfileScreen()));
            }),
            _drawerItem(Icons.build_circle_rounded, "Request History", context, onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                   context, MaterialPageRoute(builder: (_) => const RequestHistoryScreen()), (route) => false);
            }),
            _drawerItem(Icons.book_online, "Book Appointments", context, onTap: () {
              Navigator.pop(context);
               Navigator.pushAndRemoveUntil(
                  context, MaterialPageRoute(builder: (_) => const BookAppointmentScreen()), (route) => false);
            }),
            const Divider(),
            _drawerItem(Icons.settings_rounded, "Settings", context, onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                  context, MaterialPageRoute(builder: (_) => const SettingsMenuBar()), (route) => false);
            }),
            _drawerItem(Icons.logout_rounded, "Logout", context, isLogout: true, onTap: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(color: Colors.black.withOpacity(0.3)),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Logging out..",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
              await UserSession().logout();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                    context, MaterialPageRoute(builder: (_) => const VerifyScreen()), (route) => false);
              }
            }),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: () async {
                  if (await UserSession().trySwitchTo('MECHANIC')) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()), (route) => false);
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicLoginScreen()));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                ),
                child: Text(
                  "Switch to Mechanic Mode",
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _drawerItem(IconData icon, String title, BuildContext context,
      {bool isLogout = false, VoidCallback? onTap}) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : primaryColor),
      title: Text(
        title,
        style: GoogleFonts.poppins(
            fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
      ),
      onTap: onTap ?? () => Navigator.pop(context),
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
                            return Icon(Icons.person, size: 24, color: Colors.grey.shade400);
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
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, 
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 2),
                    Text(mechanic['MechanicType'],
                        style: GoogleFonts.poppins(
                            color: isDark ? Colors.white70 : Colors.grey.shade600, 
                            fontSize: 12)),
                    const SizedBox(height: 4),         
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        Text("${mechanic['averagerating']}",
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on, size: 14, color: primaryColor),
                        Text("${mechanic['distance']} km",
                            style: GoogleFonts.poppins(
                                fontSize: 12,
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
                style: GoogleFonts.poppins(
                    color: color,
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
