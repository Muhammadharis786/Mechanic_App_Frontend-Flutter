import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicServicesScreen extends StatefulWidget {
  const MechanicServicesScreen({super.key});

  @override
  State<MechanicServicesScreen> createState() => _MechanicServicesScreenState();
}

class _MechanicServicesScreenState extends State<MechanicServicesScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  // 🔹 Dummy Data for Services Status
  final int totalServicesCompleted = 45;
  final int pendingServices = 12;
  final int rejectedServices = 8;

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Services updated")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "My Services",
          style: GoogleFonts.poppins(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          children: [
            _serviceCard(
              title: "Total Completed Services",
              count: "$totalServicesCompleted",
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            _serviceCard(
              title: "Pending Services",
              count: "$pendingServices",
              icon: Icons.hourglass_top_rounded,
              color: Colors.orange,
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            _serviceCard(
              title: "Rejected Services",
              count: "$rejectedServices",
              icon: Icons.cancel_outlined,
              color: Colors.red,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Premium Service Card Design
  Widget _serviceCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          )
        ],
        border: isDark ? Border.all(color: Colors.grey.shade800) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count,
                  style: GoogleFonts.poppins(
                    fontSize: 24, // Optimized font size for counts 
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
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