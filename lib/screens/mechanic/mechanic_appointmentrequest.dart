import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../authentication/user_session.dart';
import '../../widgets/app_back_button.dart';
import '../user/appointment_tracking_map.dart';
import '../../services/mechanic_notification_controller.dart';

class MechanicAppointmentRequestScreen extends StatefulWidget {
  final List<dynamic> requests;
  final VoidCallback? onReadUpdate;

  const MechanicAppointmentRequestScreen({
    super.key,
    required this.requests,
    this.onReadUpdate,
  });

  @override
  State<MechanicAppointmentRequestScreen> createState() =>
      _MechanicAppointmentRequestScreenState();
}

class _MechanicAppointmentRequestScreenState
    extends State<MechanicAppointmentRequestScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  static const String _baseUrl =
      'https://mechanicapp-service-621632382478.asia-south1.run.app';

  List<dynamic> _allAppointments = [];
  bool _isLoading = true;
  // 3 tabs: "Booking Requests" | "Upcoming" | "Completed" | "Cancelled"
  String _selectedCategory = "Booking Requests";

  // Per-item loading state for buttons
  final Map<String, bool> _processingIds = {};

  void Function(Map<String, dynamic> data, String type)? _wsListener;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    MechanicNotificationController().init();
    _wsListener = (data, type) {
      if (type == 'appointment_done') {
        _fetchAppointments();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Payment received',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    };
    MechanicNotificationController().addListener(_wsListener!);
  }

  @override
  void dispose() {
    if (_wsListener != null) {
      MechanicNotificationController().removeListener(_wsListener!);
    }
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/mechanic/appointments/showmechanicappointments'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _allAppointments = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("❌ Error fetching mechanic appointments: $e");
    }
  }

  // Booking Requests = PENDING (new requests that need accept/reject)
  // Upcoming = ACCEPTED + ON_THE_WAY (accepted by this mechanic)
  // Completed = COMPLETED
  // Cancelled = CANCELLED + REJECTED
  List<dynamic> get _filteredAppointments {
    List<dynamic> list;

    if (_selectedCategory == "Booking Requests") {
      list = _allAppointments
          .where((a) =>
              a['status']?.toString().toUpperCase() == 'PENDING')
          .toList();
    } else if (_selectedCategory == "Upcoming") {
      list = _allAppointments.where((a) {
        final status = a['status']?.toString().toUpperCase() ?? '';
        return [
          'ACCEPTED',
          'ON_THE_WAY',
          'ARRIVED',
          'IN_PROGRESS',
          'WORK_COMPLETED',
          'PAYMENT_PROCESS'
        ].contains(status);
      }).toList();
      // Sort: Active ones first
      list.sort((a, b) {
        final _order = {
          'PAYMENT_PROCESS': 0,
          'WORK_COMPLETED': 1,
          'IN_PROGRESS': 2,
          'ARRIVED': 3,
          'ON_THE_WAY': 4,
          'ACCEPTED': 5
        };
        final aOrd =
            _order[a['status']?.toString().toUpperCase() ?? ''] ?? 6;
        final bOrd =
            _order[b['status']?.toString().toUpperCase() ?? ''] ?? 6;
        return aOrd.compareTo(bOrd);
      });
      return list;
    } else if (_selectedCategory == "Completed") {
      list = _allAppointments
          .where((a) =>
              a['status']?.toString().toUpperCase() == 'COMPLETED')
          .toList();
    } else {
      // Cancelled
      list = _allAppointments.where((a) {
        final status = a['status']?.toString().toUpperCase() ?? '';
        return status == 'CANCELLED' || status == 'REJECTED';
      }).toList();
    }

    list.sort((a, b) {
      final aDate = a['appointmentDate']?.toString() ?? "";
      final bDate = b['appointmentDate']?.toString() ?? "";
      return bDate.compareTo(aDate);
    });
    return list;
  }

  int _countByStatus(List<String> statuses) {
    return _allAppointments
        .where((a) =>
            statuses.contains(a['status']?.toString().toUpperCase() ?? ''))
        .length;
  }

  // ─── Accept Appointment ───────────────────────────────────────────────────
  Future<void> _acceptAppointment(String appointmentId) async {
    setState(() => _processingIds[appointmentId] = true);
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/api/user/appointment/acceptappointment/$appointmentId'),
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
        _fetchAppointments();
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

  // ─── Start Appointment (ON_THE_WAY) ──────────────────────────────────────
  Future<void> _startAppointment(String appointmentId) async {
    setState(() => _processingIds[appointmentId] = true);
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/api/mechanic/appointment/startappointment/$appointmentId'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Appointment Started! User notified.',
                style: GoogleFonts.getFont('Bricolage Grotesque')),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ));
        }
        _fetchAppointments();
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
      debugPrint('❌ Start error: $e');
    } finally {
      if (mounted) {
        setState(() => _processingIds[appointmentId] = false);
      }
    }
  }

  Future<void> _arrived(String id) async {
    setState(() => _processingIds[id] = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/mechanic/appointment/arrived/$id'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        _fetchAppointments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Arrived Successfully"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.body}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _processingIds[id] = false);
    }
  }

  Future<void> _startWork(String id) async {
    setState(() => _processingIds[id] = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/mechanic/appointment/startwork/$id'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        _fetchAppointments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Work Started Successfully"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.body}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _processingIds[id] = false);
    }
  }

  Future<void> _completeWork(String id) async {
    setState(() => _processingIds[id] = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/mechanic/appointment/completework/$id'),
        headers: UserSession().getAuthHeader(),
      );
      if (response.statusCode == 200) {
        _fetchAppointments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work completed. Tap SEND CHARGES to bill the customer.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.body}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _processingIds[id] = false);
    }
  }

  void _showSendChargesDialog(String appointmentId) {
    final TextEditingController priceController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.receipt_long_rounded, color: primaryColor, size: 32),
                ),
                const SizedBox(height: 15),
                Text(
                  "Set Repair Charges",
                  style: GoogleFonts.getFont('Bricolage Grotesque',
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter the final repair amount for this service",
                  style: GoogleFonts.getFont('Bricolage Grotesque',
                      color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text("Rs.",
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryColor)),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          style: GoogleFonts.getFont('Bricolage Grotesque',
                              fontSize: 28, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "0.00",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      final price = double.tryParse(priceController.text.trim());
                      if (price == null || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a valid price")),
                        );
                        return;
                      }

                      setModalState(() => isSaving = true);

                      try {
                        final response = await http.post(
                          Uri.parse('$_baseUrl/api/mechanic/appointment/sencharges/$appointmentId'),
                          headers: {
                            'Content-Type': 'application/json',
                            ...UserSession().getAuthHeader(),
                          },
                          body: jsonEncode({
                            'appid': appointmentId,
                            'finalPrice': price,
                          }),
                        );

                        if (response.statusCode == 200) {
                          Navigator.pop(ctx);
                          _fetchAppointments();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Charges sent successfully"), backgroundColor: Colors.green),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: ${response.body}")),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error: $e")),
                        );
                      } finally {
                        setModalState(() => isSaving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text("Send Repair Charges",
                            style: GoogleFonts.getFont('Bricolage Grotesque',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Reject with Reason Dialog ────────────────────────────────────────────
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
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                  Text('Select a reason for rejecting this request',
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          fontSize: 13,
                          color:
                              isDark ? Colors.white54 : Colors.black45)),
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
                              ? Colors.red
                                  .withOpacity(isDark ? 0.15 : 0.07)
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
                              color:
                                  isSelected ? Colors.red : Colors.grey,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(reason,
                                style: GoogleFonts.getFont(
                                    'Bricolage Grotesque',
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
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
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final reason = isCustom
                                  ? customController.text.trim()
                                  : selectedReason;
                              if (reason.isEmpty) return;
                              setSheetState(() => isSubmitting = true);
                              try {
                                final resp = await http.post(
                                  Uri.parse(
                                      '$_baseUrl/api/mechanic/appointment/rejectappointment/$appointmentId'),
                                  headers: {
                                    ...UserSession().getAuthHeader(),
                                    'Content-Type': 'application/json',
                                  },
                                  body: jsonEncode({'reason': reason}),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        resp.statusCode == 200
                                            ? 'Appointment Rejected'
                                            : 'Failed: ${resp.body}',
                                        style: GoogleFonts.getFont(
                                            'Bricolage Grotesque'),
                                      ),
                                      backgroundColor: resp.statusCode == 200
                                          ? Colors.orange
                                          : Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  _fetchAppointments();
                                }
                              } catch (e) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                debugPrint('❌ Reject error: $e');
                              }
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
                              style: GoogleFonts.getFont(
                                  'Bricolage Grotesque',
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

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ['Booking Requests', 'Upcoming', 'Completed', 'Cancelled'];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Appointments",
          style: GoogleFonts.getFont('Bricolage Grotesque',
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: isDark ? Colors.white : Colors.black),
        ),
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? Colors.white70 : Colors.black54),
            onPressed: _fetchAppointments,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Chips — horizontally scrollable
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return _categoryChip(cat, isDark);
              },
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
                            return _MechanicAppointmentCard(
                              data: _filteredAppointments[index],
                              primaryColor: primaryColor,
                              isDark: isDark,
                              isProcessing: _processingIds[_filteredAppointments[index]['appointmentid']?.toString() ?? ''] ?? false,
                              onAccept: _acceptAppointment,
                              onReject: _showRejectDialog,
                              onStart: _startAppointment,
                              onArrived: _arrived,
                              onStartWork: _startWork,
                              onCompleteWork: _completeWork,
                              onSendCharges: _showSendChargesDialog,
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

    // Badge counts
    int count = 0;
    if (title == "Booking Requests") {
      count = _countByStatus(['PENDING']);
    } else if (title == "Upcoming") {
      count = _countByStatus(['ACCEPTED', 'ON_THE_WAY']);
    }

    final displayText = count > 0 ? "$title ($count)" : title;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? Colors.grey[900] : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
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
              fontSize: 13),
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
                color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ─── Mechanic Appointment Card ─────────────────────────────────────────────
class _MechanicAppointmentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color primaryColor;
  final bool isDark;
  final Function(String) onAccept;
  final Function(String) onReject;
  final Function(String) onStart;
  final Function(String) onArrived;
  final Function(String) onStartWork;
  final Function(String) onCompleteWork;
  final Function(String) onSendCharges;
  final bool isProcessing;

  const _MechanicAppointmentCard({
    required this.data,
    required this.primaryColor,
    required this.isDark,
    required this.onAccept,
    required this.onReject,
    required this.onStart,
    required this.onArrived,
    required this.onStartWork,
    required this.onCompleteWork,
    required this.onSendCharges,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString().toUpperCase() ?? 'PENDING';
    final isAccepted = status == 'ACCEPTED';
    final isPending = status == 'PENDING';
    final isOnTheWay = status == 'ON_THE_WAY';
    final isArrived = status == 'ARRIVED';
    final isInProgress = status == 'IN_PROGRESS';
    final isWorkCompleted = status == 'WORK_COMPLETED';
    final isPaymentProcess = status == 'PAYMENT_PROCESS';
    final isCompleted = status == 'COMPLETED';
    final isCancelled =
        status == 'CANCELLED' || status == 'REJECTED' || status == 'EXPIRED';

    final userName = data['username'] ?? "Anonymous User";
    final userImg = data['userimage'];
    final serviceType = data['serviceType'] ?? "Mechanical Service";
    final rawDate = data['appointmentDate']?.toString() ?? "";
    final rawTime = data['appointmentTime']?.toString() ?? "";
    final formattedDateTime = _formatDateTime(rawDate, rawTime);
    final problem = data['problemDescription'] ?? "No description provided";
    final address = data['useraddress'] ?? data['address'] ?? "User Address TBD";
    final userPhone = data['userphonenumber'] ?? "";
    final reason = data['reason']?.toString();
    final appointmentId = data['appointmentid']?.toString() ?? '';

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
            // ON_THE_WAY banner
            if (isOnTheWay)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_rounded,
                        color: Colors.teal, size: 16),
                    const SizedBox(width: 6),
                    Text('Currently on the way to customer',
                        style: GoogleFonts.getFont('Bricolage Grotesque',
                            color: Colors.teal,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage:
                            userImg != null ? NetworkImage(userImg) : null,
                        child: userImg == null
                            ? Icon(Icons.person,
                                color: Colors.grey[400], size: 30)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName,
                                style: GoogleFonts.getFont(
                                    'Bricolage Grotesque',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black)),
                            Text("ID: ${data['appointmentid'] ?? 'N/A'}",
                                style: GoogleFonts.getFont(
                                    'Bricolage Grotesque',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: primaryColor.withOpacity(0.8))),
                            Text(serviceType,
                                style: GoogleFonts.getFont(
                                    'Bricolage Grotesque',
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey[600])),
                          ],
                        ),
                      ),
                      _statusBadge(status),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _infoItem(Icons.calendar_today_outlined,
                            formattedDateTime, isDark),
                        const SizedBox(height: 12),
                        _infoItem(Icons.build_outlined, problem, isDark),
                        const SizedBox(height: 12),
                        _infoItem(
                            Icons.location_on_outlined, address, isDark),
                      ],
                    ),
                  ),

                  // Reason box (only where reason is not null)
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(isDark ? 0.1 : 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_rounded,
                              size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reason',
                                    style: GoogleFonts.getFont(
                                        'Bricolage Grotesque',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red)),
                                const SizedBox(height: 2),
                                Text(reason,
                                    style: GoogleFonts.getFont(
                                        'Bricolage Grotesque',
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87)),
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
            if (isPending) _buildPendingActions(context, appointmentId),
            if (isAccepted) _buildAcceptedActions(context, userPhone, appointmentId),
            if (isOnTheWay) _buildOnTheWayActions(context, userPhone, appointmentId),
            if (isArrived) _buildArrivedActions(context, appointmentId),
            if (isInProgress) _buildInProgressActions(context, appointmentId),
            if (isWorkCompleted) _buildWorkCompletedActions(context, appointmentId),
            if (isPaymentProcess) _buildPaymentProcessIndicator(context),
            if (isCompleted) _buildPaymentDoneIndicator(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingActions(BuildContext context, String appointmentId) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isProcessing ? null : () => onAccept(appointmentId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isProcessing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text("Accept",
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => onReject(appointmentId),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Reject",
                  style: GoogleFonts.getFont('Bricolage Grotesque',
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedActions(
      BuildContext context, String phone, String appointmentId) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        children: [
          // Start Appointment button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isProcessing ? null : () => onStart(appointmentId),
              icon: isProcessing
                  ? const SizedBox.shrink()
                  : const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
              label: isProcessing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text("Start Appointment",
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final lat = double.tryParse(
                        data['latitude']?.toString() ?? "");
                    final lng = double.tryParse(
                        data['longitude']?.toString() ?? "");
                    final mechLat = double.tryParse(
                        data['mechshoplat']?.toString() ?? "");
                    final mechLng = double.tryParse(
                        data['mechshoplong']?.toString() ?? "");
                    if (lat != null && lng != null) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AppointmentTrackingMap(
                                    userLat: lat,
                                    userLng: lng,
                                    mechLat: mechLat,
                                    mechLng: mechLng,
                                  )));
                    }
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text("View Location",
                      style: GoogleFonts.getFont('Bricolage Grotesque',
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.phone_rounded, color: primaryColor),
                    onPressed: () =>
                        launchUrl(Uri.parse("tel:$phone")),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOnTheWayActions(BuildContext context, String phone, String appointmentId) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isProcessing ? null : () => onArrived(appointmentId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("I HAVE ARRIVED", style: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final lat = double.tryParse(data['latitude']?.toString() ?? "");
                    final lng = double.tryParse(data['longitude']?.toString() ?? "");
                    final mechLat = double.tryParse(data['mechshoplat']?.toString() ?? "");
                    final mechLng = double.tryParse(data['mechshoplong']?.toString() ?? "");
                    if (lat != null && lng != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentTrackingMap(userLat: lat, userLng: lng, mechLat: mechLat, mechLng: mechLng)));
                    }
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: Text("User Location", style: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: IconButton(icon: const Icon(Icons.phone_rounded, color: Colors.teal), onPressed: () => launchUrl(Uri.parse("tel:$phone"))),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrivedActions(BuildContext context, String appointmentId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isProcessing ? null : () => onStartWork(appointmentId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : Text("START WORK", style: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildInProgressActions(BuildContext context, String appointmentId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isProcessing ? null : () => onCompleteWork(appointmentId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : Text("WORK COMPLETED", style: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildWorkCompletedActions(BuildContext context, String appointmentId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isProcessing ? null : () => onSendCharges(appointmentId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : Text("SEND CHARGES", style: GoogleFonts.getFont('Bricolage Grotesque', fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPaymentProcessIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_outlined, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text("WAITING FOR PAYMENT", style: GoogleFonts.getFont('Bricolage Grotesque', color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDoneIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              'PAYMENT DONE',
              style: GoogleFonts.getFont(
                'Bricolage Grotesque',
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'ACCEPTED':
        color = Colors.green;
        label = 'ACCEPTED';
        break;
      case 'PENDING':
        color = Colors.orange;
        label = 'PENDING';
        break;
      case 'COMPLETED':
        color = Colors.blue;
        label = 'COMPLETED';
        break;
      case 'ON_THE_WAY':
        color = Colors.teal;
        label = 'ON THE WAY';
        break;
      case 'ARRIVED':
        color = Colors.indigo;
        label = 'ARRIVED';
        break;
      case 'IN_PROGRESS':
        color = Colors.purple;
        label = 'IN PROGRESS';
        break;
      case 'WORK_COMPLETED':
        color = Colors.blue;
        label = 'WORK COMPLETED';
        break;
      case 'PAYMENT_PROCESS':
        color = Colors.green;
        label = 'WAITING PAYMENT';
        break;
      case 'CANCELLED':
      case 'REJECTED':
        color = Colors.red;
        label = status;
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: GoogleFonts.getFont('Bricolage Grotesque',
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
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
        Icon(icon,
            size: 16,
            color: isDark ? Colors.white54 : Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: GoogleFonts.getFont('Bricolage Grotesque',
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}