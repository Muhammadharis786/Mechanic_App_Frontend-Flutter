import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/app_back_button.dart';

class MechanicEarningsScreen extends StatefulWidget {
  const MechanicEarningsScreen({super.key});

  @override
  State<MechanicEarningsScreen> createState() => _MechanicEarningsScreenState();
}

class _MechanicEarningsScreenState extends State<MechanicEarningsScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  // 🔹 Dummy Data for Earnings
  final double totalEarnings = 85000;
  final double todaysEarnings = 4500;

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Earnings updated")),
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
          "My Earnings",
          style: GoogleFonts.poppins(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          children: [
            _earningCard(
              title: "Total Earnings",
              amount: "PKR 85,000",
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.green,
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            _earningCard(
              title: "Today's Earnings",
              amount: "PKR 4,500",
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF1E88E5), // Premium Blue
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Premium Earning Card Design
  Widget _earningCard({
    required String title,
    required String amount,
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
                  amount,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
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