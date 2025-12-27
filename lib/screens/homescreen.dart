import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mech_app/screens/view_detail.dart';
import 'mechanic_list_screen.dart';
import 'auto_assign.dart';
import 'service_chat_screen.dart'; 

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final Color primaryColor = const Color(0xFFFB3300);

  final List<Map<String, dynamic>> nearbyMechanics = [
    {
      "id": 1,
      "name": "Ali Mechanic",
      "rating": 4.8,
      "distance": 2.5,
      "available": true,
      "image": "assets/images/m1.jpg",
      "phone": "03001234567",
    },
    {
      "id": 2,
      "name": "Ahmed Auto Repair",
      "rating": 4.6,
      "distance": 4.0,
      "available": false,
      "image": "assets/images/m2.png",
      "phone": "03009876543",
    },
    {
      "id": 3,
      "name": "Zain's Garage",
      "rating": 4.7,
      "distance": 3.2,
      "available": true,
      "image": "assets/images/m3.jpg",
      "phone": "03001112233",
    },
    {
      "id": 4,
      "name": "John Auto",
      "rating": 4.5,
      "distance": 5.0,
      "available": true,
      "image": "assets/images/m4.png",
      "phone": "03004445566",
    },
  ];

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
            Text("Hi 👋",
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.grey)),
            Text(
              "Syeda Zainab",
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),

      // ================= BODY =================
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------- Auto Assign --------
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient:
                    LinearGradient(colors: [primaryColor, Colors.deepOrange]),
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
                Text("Syeda Zainab",
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
          _drawerItem(Icons.logout_rounded, "Logout", context,
              isLogout: true),

          const SizedBox(height: 8),
          // ====== SWITCH TO MECHANIC MODE BUTTON AT BOTTOM ======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () {
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
      {bool isLogout = false}) {
    return ListTile(
      leading:
          Icon(icon, color: isLogout ? Colors.red : primaryColor),
      title: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: () => Navigator.pop(context),
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
                backgroundImage: AssetImage(mechanic['image']),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mechanic['name'],
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 14)),
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
                  Icons.call_rounded, "Call", Colors.green, () {}),
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