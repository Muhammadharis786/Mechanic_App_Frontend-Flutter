import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'homescreen.dart';

class AutoAssignScreen extends StatelessWidget {
  const AutoAssignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔥 Bottom sheet screen load hote hi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAutoAssignOptions(context);
    });

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 253, 250, 250).withOpacity(0.4), // dark overlay
        body: const SizedBox.shrink(),
      ),
    );
  }

  void _showAutoAssignOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Column(
              children: [
                const SizedBox(height: 12),

                
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 20),

                /// 🔥 Title
                const Text(
                  "Choose Service",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Select a service to auto assign nearby mechanic",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 30),

                _serviceCard(
                  context,
                  title: "Bike Mechanic",
                  icon: Icons.motorcycle,
                  service: "Bike",
                ),
                const SizedBox(height: 16),

                _serviceCard(
                  context,
                  title: "Car Mechanic",
                  icon: Icons.directions_car,
                  service: "Car",
                ),
                const SizedBox(height: 16),

                _serviceCard(
                  context,
                  title: "Puncture Service",
                  icon: Icons.build_circle,
                  service: "Puncher",
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _serviceCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String service,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MapScreen(serviceType: service),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFFB3300).withOpacity(0.1),
              child: Icon(icon, color: const Color(0xFFFB3300)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
