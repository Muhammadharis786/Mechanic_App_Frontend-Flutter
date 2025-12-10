import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart'; // 👈 Geolocator import kiya

class HomeScreen extends StatefulWidget {
  // Filename is homescreen_dart.dart
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State variables for Location
  bool locationEnabled = false; // Isse pata chalega ki location service on hai ya nahi
  String locationStatusMessage = 'Checking location status...';
  
  int selectedIndex = 0; // Bottom nav index

  // Example mechanics list
  final List<Map<String, String>> mechanics = [
    {
      'name': 'Ali Auto Repair',
      'experience': '5 years',
      'rating': '4.5',
      'distance': '2 km',
    },
    {
      'name': 'Ahmed Garage',
      'experience': '3 years',
      'rating': '4.2',
      'distance': '3.5 km',
    },
    {
      'name': 'Zeeshan Motors',
      'experience': '7 years',
      'rating': '4.8',
      'distance': '1.8 km',
    },
  ];

  @override
  void initState() {
    super.initState();
    // App start hote hi location status check aur request karein
    _checkAndRequestLocationPermission();
  }

  // 👇 Location check aur permission request ka main function
  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        locationStatusMessage = 'Location services are disabled on your device.';
        locationEnabled = false;
      });
      // User ko system settings mein jaane ke liye bolne ka logic yahan add kar sakte hain
      return; 
    }

    // 2. Check permission status
    permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Permission maangein (Yeh system prompt dikhayega)
      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          locationStatusMessage = 'Location access denied.';
          locationEnabled = false;
        });
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        locationStatusMessage = 'Location access permanently denied. Please enable from app settings.';
        locationEnabled = false;
      });
      return;
    }

    // 3. Permission granted: Fetch location (Optional, but good for confirmation)
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      setState(() {
        locationStatusMessage = 'Location access granted. Fetching nearest mechanics...';
        locationEnabled = true;
      });
      
      // Temporary: Location fetch karke confirmation message
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location found: ${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}', style: GoogleFonts.poppins())),
        );
      } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location.', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  void _onBottomNavTap(int index) {
    setState(() {
      selectedIndex = index;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected tab: $index', style: GoogleFonts.poppins())),
      );
      // Actual screens switching logic yahan aayega
    });
  }

  @override
  Widget build(BuildContext context) {
    // Apni Orange Color
    final Color kPrimaryColor = const Color(0xFFFB3300);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // User Name
            Text('Hello, Ali!', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 22)),

            // Notification Icon
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black, size: 28),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications clicked')),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            
            // Location Status/Message Display
            Text(
              locationEnabled
                  ? 'Showing mechanics near you' // Agar Location Enabled hai
                  : locationStatusMessage,        // Agar Disabled ya Pending hai
              style: GoogleFonts.poppins(
                fontSize: 15, 
                color: locationEnabled ? Colors.green.shade600 : Colors.red.shade600,
                fontWeight: FontWeight.w500
              ),
            ),
            
            // 👇 Agar Location Enabled nahi hai, to re-try button dikhao
            if (!locationEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton.icon(
                  onPressed: _checkAndRequestLocationPermission, // Re-request karein
                  icon: Icon(Icons.refresh, color: kPrimaryColor),
                  label: Text(
                    'Tap to enable location',
                    style: GoogleFonts.poppins(color: kPrimaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            const SizedBox(height: 25),

            Expanded(
              child: ListView.builder(
                itemCount: mechanics.length,
                itemBuilder: (context, index) {
                  final mechanic = mechanics[index];
                  return Card(
                    // ... Mechanic Card ka code wahi rahega ...
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 15),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      title: Text(mechanic['name']!, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${mechanic['experience']} experience • Rating: ${mechanic['rating']} • ${mechanic['distance']} away',
                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Booking ${mechanic['name']}', style: GoogleFonts.poppins())),
                          );
                        },
                        child: Text('Book', style: GoogleFonts.poppins(color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // ... Bottom Nav Bar ka code wahi rahega ...
        currentIndex: selectedIndex,
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onBottomNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'AI Chatbot'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}