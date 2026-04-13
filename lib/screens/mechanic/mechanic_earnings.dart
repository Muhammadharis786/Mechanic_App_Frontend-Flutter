import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicEarningsScreen extends StatefulWidget {
  const MechanicEarningsScreen({super.key});

  @override
  State<MechanicEarningsScreen> createState() =>
      _MechanicEarningsScreenState();
}

class _MechanicEarningsScreenState extends State<MechanicEarningsScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  List<Map<String, dynamic>> completedBookings = [
    {'userName': 'Ali Khan', 'amount': 1200, 'date': '12 Jan 2026'},
    {'userName': 'Sarah Ahmed', 'amount': 2500, 'date': '13 Jan 2026'},
    {'userName': 'Usman Ali', 'amount': 3000, 'date': '13 Jan 2026'},
  ];

  int pendingBookings = 2;
  String today = '13 Jan 2026';

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Earnings updated")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int totalEarnings =
        completedBookings.fold(0, (sum, b) => sum + (b['amount'] as int));
    int todaysEarnings = completedBookings
        .where((b) => b['date'] == today)
        .fold(0, (sum, b) => sum + (b['amount'] as int));
    int completedCount = completedBookings.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: primaryColor),
        elevation: 1,
        title: Text(
          'Earnings',
          style: GoogleFonts.poppins(
            color: theme.textTheme.titleLarge?.color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Summary Cards
              Row(
                children: [
                   Expanded(child: _summaryCard('Total Earnings', 'Rs. $totalEarnings', Colors.green, theme, Icons.account_balance_wallet_outlined)),
                   const SizedBox(width: 12),
                   Expanded(child: _summaryCard('Today', 'Rs. $todaysEarnings', Colors.blue, theme, Icons.today_outlined)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                   Expanded(child: _summaryCard('Completed', '$completedCount', Colors.orange, theme, Icons.done_all_outlined)),
                   const SizedBox(width: 12),
                   Expanded(child: _summaryCard('Pending', '$pendingBookings', Colors.purple, theme, Icons.hourglass_empty_outlined)),
                ],
              ),
              const SizedBox(height: 30),

              // Completed Bookings List Header
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'History',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                ),
              ),

              // Completed Bookings List
              completedBookings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No history available',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color),
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: completedBookings.length,
                      itemBuilder: (context, index) {
                        final b = completedBookings[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black26
                                    : Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b['userName'],
                                        style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: theme.textTheme.bodyLarge?.color)),
                                    const SizedBox(height: 4),
                                    Text(b['date'],
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: isDark ? Colors.white54 : Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              Text('Rs. ${b['amount']}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.greenAccent : Colors.green.shade700)),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // Summary Card Widget
  Widget _summaryCard(String title, String value, Color color, ThemeData theme, IconData icon) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
        ],
      ),
    );
  }
}