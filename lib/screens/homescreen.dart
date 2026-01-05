import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mech_app/screens/view_detail.dart';
import 'mechanic_list_screen.dart';
import 'auto_assign.dart';
import 'package:mech_app/screens/mechanic_login.dart';
import 'service_chat_screen.dart'; 
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_session.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'verify_screen.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  
  String _userName = "Loading...";
  bool _isLoading = true;

  List<Map<String, dynamic>> nearbyMechanics = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    // Using 10.0.2.2 for Android Emulator to access localhost
    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/dashboard");

    try {
      final response = await http.get(
        url,
        headers: UserSession().getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          // Parsing nested user object
          if (data['user'] != null) {
            _userName = data['user']['username'] ?? "User";
          }
          
          // Parsing mechanics list from response
          if (data['mechanics'] != null) {
             nearbyMechanics = List<Map<String, dynamic>>.from(
              (data['mechanics'] as List).map((m) => {
                "id": m['id'] ?? 0, // ID might not be in the DTO, check if needed or use index/random
                "name": m['name'] ?? "Unknown Mechanic",
                "rating": (m['averagerating'] as num?)?.toDouble() ?? 0.0,
                "distance": (m['distance'] as num?)?.toDouble() ?? 0.0,
                "available": m['isactive'] ?? false, 
                // Use API image if available, else fallback to asset
                "image": m['mechanicimgurl'] != null ? m['mechanicimgurl'] : "assets/images/m1.jpg", 
                "phone": m['phonenumber'] ?? "",
                "type": m['MechanicType'] ?? "", 
                "experience": m['experience'] ?? 0,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.white,
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
              "Hi 👋",
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
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
          ],
        ),
      ),

      // ================= BODY =================
      // ================= BODY =================
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
                              fontSize: 20, fontWeight: FontWeight.w600)),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MechanicListScreen(
                                serviceType: "Nearby Mechanics",
                                mechanics: nearbyMechanics, 
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                          );
                        },
                      ),
                  ),

                  const SizedBox(height: 30),

                  // -------- Service Categories --------
                  Text("Service Categories",
                      style: GoogleFonts.poppins(
                          fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),

                  _serviceCard(context, "Bike Mechanic", 2 ,'assets/images/bike.jpg' ),
                  const SizedBox(height: 16),
                  _serviceCard(context, "Car Mechanic", 3,'assets/images/car.jpg'),
                  const SizedBox(height: 16),
                  _serviceCard(context, "Puncher",4, 'assets/images/puncherr.jpg'),
                ],
              ),
            ),
    );
  }

  // ================= SERVICE CARD =================
  Widget _serviceCard(BuildContext context,   String title,  int id , String image) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        // 🔴 Navigate to ServiceChatScreen instead of MechanicListScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceChatScreen(serviceType: title , id:id),
          ),
        );
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image:
              DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
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
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ================= DRAWER =================
  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundImage: AssetImage('assets/images/user.jpg'),
                ),
                const SizedBox(height: 10),
                Text(
                  _isLoading ? "Loading..." : _userName,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                Text("User",
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          _drawerItem(Icons.home_rounded, "Home", context),
          _drawerItem(Icons.person_rounded, "My Profile", context),
          _drawerItem(Icons.build_circle_rounded, "My Requests", context),
          _drawerItem(Icons.chat_rounded, "Chats", context),
          _drawerItem(Icons.history_rounded, "History", context),
          const Divider(),
          _drawerItem(Icons.settings_rounded, "Settings", context),
          _drawerItem(
            Icons.logout_rounded,
            "Logout",
            context,
            isLogout: true,
            onTap: () async {
              // 1. Close the drawer first
              Navigator.pop(context);

               // 2. Show Blur Dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return Stack(
                    children: [
                      // Backdrop Filter for Blur
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ),
                      ),
                      // Center Loader & Text
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

              // 3. Simulate delay or call API
              await UserSession().logout(); 

              // 4. Close Dialog & Navigate
              if (context.mounted) {
                // Pop the dialog
                Navigator.pop(context); 

                // Navigate to VerifyScreen cleanly
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const VerifyScreen()),
                  (route) => false,
                );
              }
            },
          ),

          const SizedBox(height: 8),
          // ====== SWITCH TO MECHANIC MODE BUTTON AT BOTTOM ======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () {
                   Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MechanicLoginScreen()),
                      );
                // TODO: Navigate to Mechanic Registration screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              ),
              child: Text(
                "Switch to Mechanic Mode",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem(
      IconData icon, String title, BuildContext context,
      {bool isLogout = false, VoidCallback? onTap}) {
    return ListTile(
      leading:
          Icon(icon, color: isLogout ? Colors.red : primaryColor),
      title: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: onTap ?? () => Navigator.pop(context),
    );
  }
}



// ================= MECHANIC CARD =================
class _NearbyMechanicCompactCard extends StatelessWidget {
  final Map<String, dynamic> mechanic;
  final Color primaryColor;

  const _NearbyMechanicCompactCard(
      {required this.mechanic, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 245,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: mechanic['image'].toString().startsWith('http')
                    ? NetworkImage(mechanic['image'])
                    : AssetImage(mechanic['image']) as ImageProvider,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mechanic['name'],
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(mechanic['type'],
                        style: GoogleFonts.poppins(
                            color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 4),         
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: Colors.amber),
                        Text("${mechanic['rating']}",
                            style:
                                GoogleFonts.poppins(fontSize: 12)),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on,
                            size: 14, color: primaryColor),
                        Text("${mechanic['distance']} km",
                            style:
                                GoogleFonts.poppins(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color:
                      mechanic['available'] ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _actionButton(
                  Icons.call_rounded, "Call", Colors.green, () async {
                   final phone = mechanic['phone'] as String?;
                   if (phone != null && phone.isNotEmpty) {
                     final Uri launchUri = Uri(scheme: 'tel', path: phone);
                     if (await canLaunchUrl(launchUri)) {
                       await launchUrl(launchUri);
                     } else {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Could not launch dialer for $phone'))
                       );
                     }
                   } else {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Phone number not available'))
                     );
                   }
                  }),
              _actionButton(Icons.remove_red_eye_rounded, "View",
                  primaryColor, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MechanicDetailScreen(
                      serviceType: "View Mechanic",
                      mechanic: Mechanic(
                        id: mechanic['id'].toString(),
                        name: mechanic['name'],
                        avatarUrl: mechanic['image'],
                        rating:
                            (mechanic['rating'] as num).toDouble(),
                        distanceKm:
                            (mechanic['distance'] as num).toDouble(),
                        isOnline: mechanic['available'],
                        phone: mechanic['phone'],
                        lat: 0.0,
                        lng: 0.0,
                        experienceYears: mechanic['experience'] ?? 0,
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

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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



class _SkeletonHomeBody extends StatelessWidget {
  const _SkeletonHomeBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto Assign Skeleton
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(height: 26),

            // Nearby Mechanics Title Skeleton
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 150, height: 24, color: Colors.white),
                Container(width: 60, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
              ],
            ),
            const SizedBox(height: 12),

            // Nearby Mechanics List Skeleton
            SizedBox(
              height: 165,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
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

            const SizedBox(height: 30),

            // Service Categories Title Skeleton
            Container(width: 180, height: 24, color: Colors.white),
            const SizedBox(height: 16),

            // Service Cards Skeletons
            Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
            const SizedBox(height: 16),
            Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
            const SizedBox(height: 16),
            Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
          ],
        ),
      ),
    );
  }
}