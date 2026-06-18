import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mech_app/screens/homescreen.dart';
import 'package:mech_app/screens/authentication/user_session.dart';
import 'package:mech_app/screens/user/book_appointments_menubar.dart';
import 'package:mech_app/screens/user/appointment_tracking_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:mech_app/services/user_notification_controller.dart';
import 'package:mech_app/screens/user/service_review_screen.dart';
import 'package:mech_app/widgets/app_back_button.dart';

class RequestHistoryScreen extends StatefulWidget {
  const RequestHistoryScreen({super.key});

  @override
  State<RequestHistoryScreen> createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  final String _baseUrl = 'https://mechanicapp-service-621632382478.asia-south1.run.app';

  List<dynamic> _allAppointments = [];
  bool _isLoading = true;
  // Updated: "Upcoming" | "Completed" | "Cancelled"
  String _selectedCategory = "Upcoming";

  @override
  void initState() {
    super.initState();
    UserNotificationController().init();
    _fetchAppointments();
    UserNotificationController().addListener(_fetchAppointments);
  }

  @override
  void dispose() {
    UserNotificationController().removeListener(_fetchAppointments);
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/appointments/showuserappointments'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        setState(() {
          _allAppointments = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("❌ Error fetching appointments: $e");
    }
  }

  // UPCOMING = PENDING + ACCEPTED + ON_THE_WAY (and any intermediate statuses)
  // CANCELLED = CANCELLED + REJECTED
  // COMPLETED = COMPLETED
  List<dynamic> get _filteredAppointments {
    List<dynamic> list;

    if (_selectedCategory == "Upcoming") {
      list = _allAppointments.where((a) {
        final status = a['status']?.toString().toUpperCase() ?? '';
        return [
          'PENDING',
          'ACCEPTED',
          'ON_THE_WAY',
          'ARRIVED',
          'IN_PROGRESS',
          'WORK_COMPLETED',
          'PAYMENT_PROCESS'
        ].contains(status);
      }).toList();

      // Sort: ON_THE_WAY first, then ACCEPTED, then PENDING
      list.sort((a, b) {
        final _order = {'ON_THE_WAY': 0, 'ACCEPTED': 1, 'PENDING': 2};
        final aStatus = a['status']?.toString().toUpperCase() ?? '';
        final bStatus = b['status']?.toString().toUpperCase() ?? '';
        final aOrd = _order[aStatus] ?? 3;
        final bOrd = _order[bStatus] ?? 3;
        if (aOrd != bOrd) return aOrd.compareTo(bOrd);
        final aDate = a['appointmentDate']?.toString() ?? "";
        final bDate = b['appointmentDate']?.toString() ?? "";
        return aDate.compareTo(bDate);
      });
      return list;
    } else if (_selectedCategory == "Completed") {
      list = _allAppointments.where((a) {
        final status = a['status']?.toString().toUpperCase() ?? '';
        return status == 'COMPLETED';
      }).toList();
    } else {
      // Cancelled tab → CANCELLED + REJECTED
      list = _allAppointments.where((a) {
        final status = a['status']?.toString().toUpperCase() ?? '';
        return status == 'CANCELLED' || status == 'REJECTED' || status == 'EXPIRED';
      }).toList();
    }

    list.sort((a, b) {
      final aDate = a['appointmentDate']?.toString() ?? "";
      final bDate = b['appointmentDate']?.toString() ?? "";
      return bDate.compareTo(aDate);
    });
    return list;
  }

  /// Shows cancel appointment dialog with reason options and custom text
  Future<void> _showCancelDialog(String appointmentId) async {
    final reasonOptions = [
      "Changed my mind",
      "Scheduled by mistake",
      "Found another mechanic",
      "Emergency came up",
      "Other",
    ];
    String? selectedReason = reasonOptions[0];
    final TextEditingController customController = TextEditingController();
    bool isCustom = false;
    bool _isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
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
                  // Handle bar
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
                  Text(
                    'Cancel Appointment',
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please tell us why you are cancelling',
                    style: GoogleFonts.getFont('Bricolage Grotesque',
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black45),
                  ),
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
                              : (isDark
                                  ? Colors.grey[850]
                                  : Colors.grey[100]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.red
                                : Colors.transparent,
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
                                  color: isDark ? Colors.white : Colors.black87),
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
                        fillColor:
                            isDark ? Colors.grey[850] : Colors.grey[100],
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
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              final reason = isCustom
                                  ? customController.text.trim()
                                  : selectedReason ?? '';
                              if (reason.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Please provide a reason',
                                        style: GoogleFonts.getFont(
                                            'Bricolage Grotesque')),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => _isSubmitting = true);
                              await _cancelAppointment(appointmentId, reason);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Confirm Cancellation',
                              style: GoogleFonts.getFont('Bricolage Grotesque',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15),
                            ),
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

  Future<void> _payCash(String appointmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/mechanic/appointment/paynow/$appointmentId'),
        headers: UserSession().getAuthHeader(),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        await _fetchAppointments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceReviewScreen(
              serviceId: appointmentId,
              serviceType: 'APPOINTMENT',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${response.body}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPayNowSheet(String appointmentId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose payment method',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.payments_rounded, color: Colors.green),
              title: const Text('Cash'),
              subtitle: const Text('Pay directly to mechanic'),
              onTap: () {
                Navigator.pop(ctx);
                _payCash(appointmentId);
              },
            ),
            ListTile(
              leading: Icon(Icons.language_rounded, color: Colors.grey.shade500),
              title: const Text('Online'),
              subtitle: const Text('Coming soon'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Online payment coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(
      String appointmentId, String reason) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/api/user/appointment/cancelappointment/$appointmentId'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Appointment cancelled successfully',
                style: GoogleFonts.getFont('Bricolage Grotesque')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
          _fetchAppointments();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to cancel: ${response.body}',
                style: GoogleFonts.getFont('Bricolage Grotesque')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      debugPrint('❌ Cancel error: $e');
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
        centerTitle: false,
        leading: AppBackButton(
          onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen())),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFFB3300),
            size: 18,
          ),
          splashRadius: 20,
        ),
        title: Text(
          'Appointments',
          style: GoogleFonts.getFont('Bricolage Grotesque',
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 24),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BookAppointmentScreen())),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add,
                    color: isDark ? Colors.white : Colors.black, size: 22),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Selectors
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _categoryChip("Upcoming", isDark),
                const SizedBox(width: 10),
                _categoryChip("Completed", isDark),
                const SizedBox(width: 10),
                _categoryChip("Cancelled", isDark),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAppointments,
              color: primaryColor,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAppointments.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredAppointments.length,
                          itemBuilder: (context, index) {
                            return AppointmentCard(
                              data: _filteredAppointments[index],
                              primaryColor: primaryColor,
                              isDark: isDark,
                              onCancel: (id) => _showCancelDialog(id),
                              onPay: _showPayNowSheet,
                              onRefresh: _fetchAppointments,
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String title, bool isDark) {
    final isSelected = _selectedCategory == title;

    // Count badges
    int count = 0;
    if (title == "Upcoming") {
      count = _allAppointments.where((a) {
        final status = a['status']?.toString().toUpperCase() ?? '';
        return status == 'PENDING' || status == 'ACCEPTED' || status == 'ON_THE_WAY';
      }).length;
    }

    final displayText = count > 0 ? "$title ($count)" : title;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? Colors.grey[900] : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border:
              isSelected ? null : Border.all(color: Colors.grey.shade300),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(
          displayText,
          style: GoogleFonts.getFont('Bricolage Grotesque',
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No ${_selectedCategory.toLowerCase()} appointments",
            style: GoogleFonts.getFont('Bricolage Grotesque',
                color: isDark ? Colors.white54 : Colors.grey,
                fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ================= CARD =================
class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color primaryColor;
  final bool isDark;
  final Function(String)? onCancel;
  final Function(String)? onPay;
  final VoidCallback? onRefresh;

  const AppointmentCard({
    super.key,
    required this.data,
    required this.primaryColor,
    required this.isDark,
    this.onCancel,
    this.onPay,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString().toUpperCase() ?? 'PENDING';
    final mechanicId = data['mechanicid'] ?? 0;
    final isAccepted = status == 'ACCEPTED';
    final isCompleted = status == 'COMPLETED';
    final isPending = status == 'PENDING';
    final isOnTheWay = status == 'ON_THE_WAY';
    final isArrived = status == 'ARRIVED';
    final isInProgress = status == 'IN_PROGRESS';
    final isWorkCompleted = status == 'WORK_COMPLETED';
    final isPaymentProcess = status == 'PAYMENT_PROCESS';
    final isCancelled = status == 'CANCELLED' || status == 'REJECTED' || status == 'EXPIRED';
    final canCancel = isPending || isAccepted;

    final mechName = data['mechname'] ??
        (mechanicId == 0 ? "Waiting for Assignment" : "Professional Mechanic");
    final mechImg = data['mechimage'];
    final rating = (data['mechrating'] as num?)?.toDouble() ?? 0.0;
    final serviceType = data['serviceType'] ?? "Mechanical Service";

    final rawDate = data['appointmentDate']?.toString() ?? "";
    final rawTime = data['appointmentTime']?.toString() ?? "";
    final formattedDateTime = _formatDateTime(rawDate, rawTime);

    final problem = data['problemDescription'] ?? "No description provided";
    final address = data['mechanicshopaddress'] ?? data['address'] ?? "Shop Location TBD";
    final reason = data['reason']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Opacity(
        opacity: isCancelled ? 0.7 : 1.0,
        child: Column(
          children: [
            if (isArrived)
              _statusBanner(
                'Mechanic has arrived at your location',
                Icons.place_rounded,
                Colors.indigo,
              ),
            if (isInProgress)
              _statusBanner(
                'Mechanic has started work',
                Icons.build_circle_outlined,
                Colors.purple,
              ),
            if (isWorkCompleted)
              _statusBanner(
                'Work completed — awaiting bill from mechanic',
                Icons.check_circle_outline,
                Colors.blue,
              ),

            // ON THE WAY banner
            if (isOnTheWay)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.12),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_rounded,
                        color: Colors.teal, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Your mechanic is on the way!',
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          color: Colors.teal,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Image & Name
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: mechImg != null
                            ? NetworkImage(mechImg)
                            : null,
                        child: mechImg == null
                            ? Icon(Icons.person,
                                color: Colors.grey[400], size: 30)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mechName,
                              style: GoogleFonts.getFont(
                                  'Bricolage Grotesque',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "ID: ${data['appointmentid'] ?? 'N/A'}",
                              style: GoogleFonts.getFont(
                                  'Bricolage Grotesque',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: primaryColor.withOpacity(0.8)),
                            ),
                            Row(
                              children: [
                                Text(
                                  serviceType,
                                  style: GoogleFonts.getFont(
                                      'Bricolage Grotesque',
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.grey[600]),
                                ),
                                if (mechanicId != 0) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: GoogleFonts.getFont(
                                        'Bricolage Grotesque',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.grey[600]),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      _statusBadge(status),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black26
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _infoItem(Icons.calendar_today_outlined,
                            formattedDateTime, isDark),
                        const SizedBox(height: 12),
                        _infoItem(Icons.build_outlined, problem, isDark),
                        _infoItem(
                            Icons.location_on_outlined, address, isDark),
                      ],
                    ),
                  ),

                  // Billing only after mechanic sends charges (PAYMENT_PROCESS+)
                  if (isPaymentProcess &&
                      _repairAmount(data) > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(isDark ? 0.1 : 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          _priceRow(
                            'Visiting Charges',
                            'Rs. ${data['visitingCharge'] ?? data['visitingcharges'] ?? 0}',
                            isDark,
                          ),
                          const SizedBox(height: 8),
                          _priceRow(
                            'Repair Amount',
                            'Rs. ${_repairAmount(data)}',
                            isDark,
                          ),
                          const Divider(height: 24),
                          _priceRow(
                            'Total Amount',
                            'Rs. ${data['amount'] ?? (_visitingCharge(data) + _repairAmount(data))}',
                            isDark,
                            isTotal: true,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Reason Box (only where reason is not null)
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? Colors.red.withOpacity(
                                isDark ? 0.1 : 0.05)
                            : Colors.orange.withOpacity(
                                isDark ? 0.1 : 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCancelled
                              ? Colors.red.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCancelled
                                ? Icons.info_rounded
                                : Icons.info_outline_rounded,
                            size: 16,
                            color: isCancelled
                                ? Colors.red
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCancelled
                                      ? 'Reason for Cancellation'
                                      : 'Note',
                                  style: GoogleFonts.getFont(
                                      'Bricolage Grotesque',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isCancelled
                                          ? Colors.red
                                          : Colors.orange),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  reason,
                                  style: GoogleFonts.getFont(
                                      'Bricolage Grotesque',
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action Buttons
            if (!isCancelled) ...[
              if (isPending) _buildPendingActions(context),
              if (isAccepted) _buildAcceptedActions(context),
              if (isOnTheWay) _buildOnTheWayActions(context),
              if (isArrived || isInProgress || isWorkCompleted)
                _buildProgressActions(context, status),
              if (isPaymentProcess) _buildPaymentProcessActions(context),
              if (isCompleted) _buildCompletedActions(context),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    Color bgColor;
    String label;
    switch (status) {
      case 'ACCEPTED':
        color = Colors.green;
        bgColor = Colors.green.withOpacity(0.1);
        label = 'ACCEPTED';
        break;
      case 'PENDING':
        color = Colors.orange;
        bgColor = Colors.orange.withOpacity(0.1);
        label = 'PENDING';
        break;
      case 'COMPLETED':
        color = Colors.blue;
        bgColor = Colors.blue.withOpacity(0.1);
        label = 'COMPLETED';
        break;
      case 'ON_THE_WAY':
        color = Colors.teal;
        bgColor = Colors.teal.withOpacity(0.1);
        label = 'ON THE WAY';
        break;
      case 'ARRIVED':
        color = Colors.indigo;
        bgColor = Colors.indigo.withOpacity(0.1);
        label = 'ARRIVED';
        break;
      case 'IN_PROGRESS':
        color = Colors.purple;
        bgColor = Colors.purple.withOpacity(0.1);
        label = 'IN PROGRESS';
        break;
      case 'WORK_COMPLETED':
        color = Colors.blue;
        bgColor = Colors.blue.withOpacity(0.1);
        label = 'WORK COMPLETED';
        break;
      case 'PAYMENT_PROCESS':
        color = Colors.green;
        bgColor = Colors.green.withOpacity(0.1);
        label = 'PAY NOW';
        break;
      default:
        color = Colors.red;
        bgColor = Colors.red.withOpacity(0.1);
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.getFont('Bricolage Grotesque',
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDateTime(String dateStr, String timeStr) {
    if (dateStr.isEmpty || timeStr.isEmpty) return "Schedule Pending";
    try {
      DateTime date = DateTime.parse(dateStr);
      DateFormat timeInputFormat = DateFormat("HH:mm:ss");
      DateTime time = timeInputFormat.parse(timeStr);
      String formattedDate = DateFormat('d MMMM yyyy').format(date);
      String formattedTime = DateFormat('h:mm a').format(time);
      return "$formattedDate, $formattedTime";
    } catch (e) {
      return "$dateStr • $timeStr";
    }
  }

  Widget _infoItem(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.getFont('Bricolage Grotesque',
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () {
            final id = data['appointmentid']?.toString() ?? '';
            if (id.isNotEmpty) onCancel?.call(id);
          },
          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
          label: Text(
            "Cancel Appointment",
            style: GoogleFonts.getFont('Bricolage Grotesque',
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          style: TextButton.styleFrom(
            backgroundColor:
                isDark ? Colors.grey[900] : Colors.white,
            side: BorderSide(
                color: isDark
                    ? Colors.red.withOpacity(0.3)
                    : Colors.red.shade100),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildAcceptedActions(BuildContext context) {
    final phone = data['mechnumber'] ?? "";
    final uLat = double.tryParse(data['latitude']?.toString() ?? "");
    final uLng = double.tryParse(data['longitude']?.toString() ?? "");
    final mLat = double.tryParse(data['mechshoplat']?.toString() ?? "");
    final mLng = double.tryParse(data['mechshoplong']?.toString() ?? "");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () {
                    if (uLat != null && uLng != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentTrackingMap(
                            userLat: uLat,
                            userLng: uLng,
                            mechLat: mLat,
                            mechLng: mLng,
                            mechanicName: data['mechname'],
                            address: data['address'],
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Location data unavailable.",
                            style:
                                GoogleFonts.getFont('Bricolage Grotesque')),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("View Directions",
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (phone.toString().isNotEmpty) {
                    launchUrl(Uri.parse("tel:${phone.toString()}"));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[850]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.phone_outlined,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Cancel button also available on accepted status
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                final id = data['appointmentid']?.toString() ?? '';
                if (id.isNotEmpty) onCancel?.call(id);
              },
              icon:
                  const Icon(Icons.close_rounded, size: 16, color: Colors.red),
              label: Text(
                "Cancel Appointment",
                style: GoogleFonts.getFont('Bricolage Grotesque',
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              style: TextButton.styleFrom(
                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnTheWayActions(BuildContext context) {
    final phone = data['mechnumber'] ?? "";
    final uLat = double.tryParse(data['latitude']?.toString() ?? "");
    final uLng = double.tryParse(data['longitude']?.toString() ?? "");
    final mLat = double.tryParse(data['mechshoplat']?.toString() ?? "");
    final mLng = double.tryParse(data['mechshoplong']?.toString() ?? "");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: () {
                if (uLat != null && uLng != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AppointmentTrackingMap(
                        userLat: uLat,
                        userLng: uLng,
                        mechLat: mLat,
                        mechLng: mLng,
                        mechanicName: data['mechname'],
                        address: data['address'],
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.my_location_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text("Track Mechanic",
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          if (phone.toString().isNotEmpty) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () =>
                  launchUrl(Uri.parse("tel:${phone.toString()}")),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_outlined, color: Colors.teal),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final id = data['appointmentid']?.toString() ?? '';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceReviewScreen(
                  serviceId: id,
                  serviceType: "APPOINTMENT",
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDark ? (Colors.grey[850] ?? Colors.grey) : Colors.white,
            side: BorderSide(
                color: isDark
                    ? (Colors.grey[800] ?? Colors.grey)
                    : Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_outline,
                  size: 20, color: isDark ? Colors.white : Colors.black),
              const SizedBox(width: 8),
              Text(
                "Rate Mechanic",
                style: GoogleFonts.getFont('Bricolage Grotesque',
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressActions(BuildContext context, String status) {
    String msg = "Mechanic is working...";
    if (status == 'ARRIVED') msg = "Mechanic has arrived!";
    if (status == 'WORK_COMPLETED') msg = "Service done! Awaiting bill...";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            msg,
            style: GoogleFonts.getFont('Bricolage Grotesque',
                color: primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  static num _repairAmount(Map<String, dynamic> data) {
    final v = data['repairAmount'] ?? data['repairamount'];
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  static num _visitingCharge(Map<String, dynamic> data) {
    final v = data['visitingCharge'] ?? data['visitingcharges'];
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  Widget _statusBanner(String text, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.getFont(
                'Bricolage Grotesque',
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProcessActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final id = data['appointmentid']?.toString() ?? '';
            if (id.isNotEmpty) onPay?.call(id);
          },
          icon: const Icon(Icons.payment_rounded, color: Colors.white),
          label: Text("PAY NOW",
              style: GoogleFonts.getFont('Bricolage Grotesque',
                  fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, bool isDark,
      {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.getFont('Bricolage Grotesque',
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14)),
        Text(value,
            style: GoogleFonts.getFont('Bricolage Grotesque',
                color: isTotal ? primaryColor : (isDark ? Colors.white : Colors.black),
                fontWeight: FontWeight.bold,
                fontSize: isTotal ? 18 : 14)),
      ],
    );
  }
}

// ================= MODEL =================
class RequestModel {
  final String service;
  final String mechanic;
  final String problem;
  final String location;
  final String date;
  final String type;
  final int amount;
  final double rating;
  final String status;
  final IconData icon;

  RequestModel({
    required this.service,
    required this.mechanic,
    required this.problem,
    required this.location,
    required this.date,
    required this.type,
    required this.amount,
    required this.rating,
    required this.status,
    required this.icon,
  });
}

// ================= DUMMY DATA =================
final List<RequestModel> dummyRequests = [];
