import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../authentication/user_session.dart';
import '../user/appointment_tracking_map.dart';
import '../../widgets/app_back_button.dart';

class MechanicBookingRequestScreen extends StatefulWidget {
  const MechanicBookingRequestScreen({super.key});

  @override
  State<MechanicBookingRequestScreen> createState() =>
      _MechanicBookingRequestScreenState();
}

class _MechanicBookingRequestScreenState
    extends State<MechanicBookingRequestScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  static const String _baseUrl =
      'https://mechanicapp-service-621632382478.asia-south1.run.app';

  List<dynamic> _allRequests = [];
  bool _isLoading = true;
  // Per-item loading state for buttons
  final Map<String, bool> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/mechanic/appointments/showmechanicappointments'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> all = jsonDecode(response.body);
        setState(() {
          // Show only PENDING — these are new booking requests
          _allRequests = all
              .where((a) =>
                  a['status']?.toString().toUpperCase() == 'PENDING')
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('❌ Error fetching booking requests: $e');
    }
  }

  Future<void> _acceptRequest(String appointmentId) async {
    setState(() => _processingIds[appointmentId] = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/appointment/acceptappointment/$appointmentId'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Appointment Accepted!',
                style: GoogleFonts.getFont('Bricolage Grotesque')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
        _fetchRequests();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: ${response.body}',
                style: GoogleFonts.getFont('Bricolage Grotesque')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      debugPrint('❌ Accept error: $e');
    } finally {
      if (mounted) {
        setState(() => _processingIds[appointmentId] = false);
      }
    }
  }

  Future<void> _showRejectDialog(String appointmentId) async {
    final reasonOptions = [
      "Too many appointments",
      "Location too far",
      "Service not available",
      "Busy schedule",
      "Other",
    ];
    String selectedReason = reasonOptions[0];
    final TextEditingController customController = TextEditingController();
    bool isCustom = false;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Reject Appointment',
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 4),
                  Text('Please select a reason for rejection',
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black45)),
                  const SizedBox(height: 16),
                  ...reasonOptions.map((reason) {
                    final isSelected = selectedReason == reason;
                    final isOther = reason == "Other";
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() {
                          selectedReason = reason;
                          isCustom = isOther;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.red.withOpacity(isDark ? 0.15 : 0.07)
                              : (isDark ? Colors.grey[850] : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected ? Colors.red : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected ? Colors.red : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              reason,
                              style: GoogleFonts.getFont('Bricolage Grotesque',
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (isCustom) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: customController,
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Describe your reason...',
                        hintStyle: GoogleFonts.getFont('Bricolage Grotesque',
                            color: Colors.grey),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                  ] else
                    const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final reason = isCustom
                                  ? customController.text.trim()
                                  : selectedReason;
                              if (reason.isEmpty) return;
                              setSheetState(() => isSubmitting = true);
                              await _rejectRequest(appointmentId, reason);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text('Confirm Rejection',
                              style: GoogleFonts.getFont('Bricolage Grotesque',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _rejectRequest(String appointmentId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse(
            '$_baseUrl/api/mechanic/appointment/rejectappointment/$appointmentId'),
        headers: {
          ...UserSession().getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Appointment Rejected',
                style: GoogleFonts.getFont('Bricolage Grotesque')),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
          _fetchRequests();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: ${response.body}',
                style: GoogleFonts.getFont('Bricolage Grotesque')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      debugPrint('❌ Reject error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Booking Requests',
          style: GoogleFonts.getFont('Bricolage Grotesque',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: isDark ? Colors.white : Colors.black),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? Colors.white70 : Colors.black54),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _allRequests.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _fetchRequests,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _allRequests.length,
                    itemBuilder: (context, index) {
                      return _buildRequestCard(_allRequests[index], isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildRequestCard(dynamic item, bool isDark) {
    final Map<String, dynamic> a =
        item is Map ? Map<String, dynamic>.from(item) : {};

    final String appointmentId = a['appointmentid']?.toString() ?? '';
    final String serviceType = a['serviceType']?.toString() ?? 'Service';
    final String problem = a['problemDescription']?.toString() ?? '';
    final String address = a['useraddress']?.toString() ?? a['address']?.toString() ?? '';
    final String userName = a['username']?.toString() ?? 'Customer';
    final String userImg = a['userimage']?.toString() ?? '';
    final String phone = a['userphonenumber']?.toString() ?? '';
    final String rawDate = a['appointmentDate']?.toString() ?? '';
    final String rawTime = a['appointmentTime']?.toString() ?? '';
    final int visiting = (a['visitingcharges'] as num?)?.toInt() ?? 0;
    final formattedDateTime = _formatDateTime(rawDate, rawTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryColor.withOpacity(0.1),
                  backgroundImage:
                      userImg.isNotEmpty ? NetworkImage(userImg) : null,
                  child: userImg.isEmpty
                      ? Text(
                          userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                              color: primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black)),
                      Text(
                        serviceType.toUpperCase(),
                        style: GoogleFonts.getFont('Bricolage Grotesque',
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    'PENDING',
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ID + visiting charge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  appointmentId,
                  style: GoogleFonts.getFont('Bricolage Grotesque',
                      fontSize: 12,
                      color: primaryColor,
                      fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Rs. $visiting visiting fee',
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Info rows
            _detailRow(Icons.access_time_rounded, formattedDateTime, isDark),
            const SizedBox(height: 8),
            _detailRow(Icons.build_outlined, problem, isDark),
            const SizedBox(height: 8),
            _detailRow(Icons.location_on_rounded, address, isDark),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _processingIds[appointmentId] == true
                        ? null
                        : () => _acceptRequest(appointmentId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _processingIds[appointmentId] == true
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Accept',
                            style: GoogleFonts.getFont('Bricolage Grotesque',
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(appointmentId),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Reject',
                        style: GoogleFonts.getFont('Bricolage Grotesque',
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.phone_rounded, color: primaryColor),
                      onPressed: () =>
                          launchUrl(Uri.parse('tel:$phone')),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 15,
            color: isDark ? Colors.grey[500] : Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.getFont('Bricolage Grotesque',
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String dateStr, String timeStr) {
    if (dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      final formattedDate = DateFormat('d MMMM yyyy').format(date);
      if (timeStr.isEmpty) return formattedDate;
      final time = DateFormat('HH:mm:ss').parse(timeStr);
      return '$formattedDate, ${DateFormat('h:mm a').format(time)}';
    } catch (_) {
      return '$dateStr • $timeStr';
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No pending booking requests',
            style: GoogleFonts.getFont('Bricolage Grotesque',
                color: isDark ? Colors.white54 : Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'New requests will appear here',
            style: GoogleFonts.getFont('Bricolage Grotesque',
                color: isDark ? Colors.white38 : Colors.grey[400],
                fontSize: 13),
          ),
        ],
      ),
    );
  }
}