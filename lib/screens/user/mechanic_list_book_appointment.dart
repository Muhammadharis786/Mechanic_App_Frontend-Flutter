import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class MechanicListScreenn extends StatelessWidget {
  final String serviceType;
  final List<Map<String, dynamic>> mechanics;
  final String? selectedMechanicId;

  const MechanicListScreenn({
    super.key,
    required this.serviceType,
    required this.mechanics,
    this.selectedMechanicId, required bool showViewOption,
  });

  final Color primaryColor = const Color(0xFFFB3300);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nearby Mechanics",
              style: TextStyle(
                  color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(serviceType,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mechanics.length,
        itemBuilder: (context, index) {
          final mechanic = mechanics[index];
          final isSelected = selectedMechanicId != null &&
              selectedMechanicId == mechanic['id'];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _mechanicCard(mechanic, isSelected, context),
          );
        },
      ),
    );
  }

  Widget _mechanicCard(
      Map<String, dynamic> mechanic, bool isSelected, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mechanic info row
          Row(
            children: [
              CircleAvatar(
                  radius: 28, backgroundImage: AssetImage(mechanic['image'])),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mechanic['name'],
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text("${mechanic['rating']}",
                            style: GoogleFonts.poppins(fontSize: 12)),
                        const SizedBox(width: 6),
                        Icon(Icons.location_on, size: 14, color: primaryColor),
                        Text("${mechanic['distance']} km",
                            style: GoogleFonts.poppins(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: mechanic['available'] ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          // Buttons row: Select + Call
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, mechanic);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isSelected ? "Selected" : "Select",
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
              ElevatedButton.icon(
                onPressed: () => _callMechanic(mechanic['phone']),
                icon: const Icon(Icons.call, size: 16, color: Colors.white),
                label: const Text("Call",
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _callMechanic(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
