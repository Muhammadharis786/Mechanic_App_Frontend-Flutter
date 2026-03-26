import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user/view_detail.dart';

class MechanicListScreen extends StatefulWidget {
  final String serviceType;
  final List<Map<String, dynamic>> mechanics;
  final bool showViewOption;

  const MechanicListScreen({
    super.key,
    required this.serviceType,
    required this.mechanics,
    required this.showViewOption,
  });

  @override
  State<MechanicListScreen> createState() => _MechanicListScreenState();
}

class _MechanicListScreenState extends State<MechanicListScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mechanic list updated")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: primaryColor, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nearby Mechanics",
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(widget.serviceType,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey)),
          ],
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _refresh,
        color: primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: widget.mechanics.length,
          itemBuilder: (context, index) {
            return _NearbyMechanicCardVertical(
              mechanic: widget.mechanics[index],
              primaryColor: primaryColor,
              isDark: isDark,
            );
          },
        ),
      ),
    );
  }
}

// ================= CARD =================
class _NearbyMechanicCardVertical extends StatelessWidget {
  final Map<String, dynamic> mechanic;
  final Color primaryColor;
  final bool isDark;

  const _NearbyMechanicCardVertical({
    required this.mechanic,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
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
                radius: 28,
                backgroundImage: mechanic['mechanicimgurl']
                        .toString()
                        .startsWith('http')
                    ? NetworkImage(mechanic['mechanicimgurl'])
                    : AssetImage(mechanic['mechanicimgurl'])
                        as ImageProvider,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mechanic['name'],
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: Colors.amber),
                        Text(
                          "${mechanic['averagerating']}",
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on,
                            size: 14, color: primaryColor),
                        Text(
                          "${mechanic['distance']} km",
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: mechanic['isactive']
                      ? Colors.green
                      : Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            ],
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _actionButton(
                Icons.call_rounded,
                "Call",
                Colors.green,
                () async {
                  final phone = mechanic['phonenumber'] as String?;
                  if (phone != null && phone.isNotEmpty) {
                    final Uri launchUri =
                        Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(launchUri)) {
                      await launchUrl(launchUri);
                    }
                  }
                },
              ),
              _actionButton(
                Icons.remove_red_eye_rounded,
                "View",
                primaryColor,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MechanicDetailScreen(
                        serviceType: "View Mechanic",
                        mechanic: Mechanic(
                          id: mechanic['id'].toString(),
                          mechanictype:
                              mechanic['MechanicType'] ?? 'Mechanic',
                          name: mechanic['name'],
                          avatarUrl: mechanic['mechanicimgurl'],
                          rating:
                              (mechanic['averagerating'] as num)
                                  .toDouble(),
                          distanceKm:
                              (mechanic['distance'] as num)
                                  .toDouble(),
                          isOnline: mechanic['isactive'],
                          phone: mechanic['phonenumber'],
                          lat: (mechanic['latitude'] is String)
                              ? double.tryParse(
                                      mechanic['latitude']) ??
                                  0.0
                              : (mechanic['latitude'] as num?)
                                      ?.toDouble() ??
                                  0.0,
                          lng: (mechanic['longitude'] is String)
                              ? double.tryParse(
                                      mechanic['longitude']) ??
                                  0.0
                              : (mechanic['longitude'] as num?)
                                      ?.toDouble() ??
                                  0.0,
                          experienceYears:
                              mechanic['experience'] ?? 0,
                          mechanicLocName:
                              mechanic['mechaniclocname'] ??
                                  "Unknown Location",
                        ),
                        isDarkMode: isDark, // <-- pass theme info
                      ),
                    ),
                  );
                },
              ),
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
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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