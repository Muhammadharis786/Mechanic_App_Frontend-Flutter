import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../authentication/user_session.dart';
import '../../widgets/app_back_button.dart';

class MechanicHistoryScreen extends StatefulWidget {
  const MechanicHistoryScreen({super.key});

  @override
  State<MechanicHistoryScreen> createState() => _MechanicHistoryScreenState();
}

class _MechanicHistoryScreenState extends State<MechanicHistoryScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  bool _isLoading = true;
  List<Map<String, dynamic>> _allJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/alljobs/history");
    try {
      final response =
          await http.get(url, headers: UserSession().getAuthHeader());
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            _allJobs = data
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('History fetch failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          "Service History",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              color: primaryColor,
              child: _allJobs.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _allJobs.length,
                      itemBuilder: (context, index) {
                        return _buildHistoryCard(_allJobs[index], isDark);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded,
              size: 80,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No history found",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> job, bool isDark) {
    final String type = job['type']?.toString() ?? 'SERVICE_REQUEST';
    final bool isAppointment = type == 'APPOINTMENT';
    final amount = job['amount']?.toString() ?? '--';
    final username = job['username']?.toString() ?? 'Customer';
    final serviceType = job['serviceType']?.toString() ?? 'Service';
    final completedAt = job['completedAt']?.toString() ?? '';
    final displayDate = completedAt.length >= 10
        ? completedAt.substring(0, 10)
        : completedAt;

    final IconData activityIcon = isAppointment
        ? Icons.calendar_today_rounded
        : Icons.build_circle_rounded;
    final Color activityColor = isAppointment
        ? const Color(0xFF1E88E5)
        : primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: activityColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(activityIcon, color: activityColor, size: 24),
        ),
        title: Text(
          username,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              serviceType,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.black54,
              ),
            ),
            if (displayDate.isNotEmpty)
              Text(
                displayDate,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount == '--' ? 'Rs. --' : 'Rs. $amount',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.green.shade600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Completed",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
