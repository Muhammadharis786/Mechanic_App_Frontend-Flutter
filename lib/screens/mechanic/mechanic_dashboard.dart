import 'dart:async';
import 'mechanic_usermap.dart';
import 'mechanic_request_alert_screen.dart';
import '../../services/active_service_request_tracking.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'mechanic_bookingrequest.dart';
import 'mechanic_earnings.dart';
import 'mechanic_profile.dart';
import 'mechanic_settings.dart';
import 'mechanic_notification.dart';
import 'mechanic_services.dart';
import 'mechanic_appointmentrequest.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../authentication/user_session.dart';
import '../homescreen.dart';
import '../role_selection_screen.dart';
import '../../services/websocket_service.dart'; // Re-adding websocket
import '../../services/mechanic_notification_controller.dart'; // Add Global Controller
import '../../services/mechanic_live_location_service.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../utils/time_utils.dart'; // Added for relative time formatting

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  final Color primaryColor = const Color(0xFFE64A19);
  final Color accentOrange = const Color(0xFFFF6D00);

  bool _isLoading = true;
  bool _isToggleLoading = false;
  bool isOnline = false;

  double totalEarnings = 0;
  double todaysEarnings = 0;
  int totalServices = 0;
  int todaysServices = 0;
  double mechanicRating = 0;
  String mechanicName = "Mechanic";
  String mechanicImageUrl = '';

  final List<Map<String, dynamic>> _roadRequests = [];
  final List<Map<String, dynamic>> _appointmentRequests = [];

  StompClient? _activeRequestClient;
  String? _subscribedRequestId;

  int get _dailyUnreadCount => _roadRequests.where((e) => e['isRead'] == false).length;
  int get _appointmentUnreadCount =>
      _appointmentRequests.where((e) => e['isRead'] == false).length;
  int get _notificationCount => _dailyUnreadCount + _appointmentUnreadCount;

  @override
  void initState() {
    super.initState();
    ActiveServiceRequestTracking.current.addListener(_onActiveTrackingChanged);
    _fetchDashboardData();
    _fetchAppointmentNotifications();
    _initWebSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncActiveTrackingWithServer();
      _subscribeActiveRequestTopic();
    });
  }

  void _initWebSocket() {
    // 1. Initialize and connect the global controller
    MechanicNotificationController().init();
    
    // 2. Add listener to update dashboard UI when a notification arrives
    MechanicNotificationController().addListener(_onGlobalNotificationReceived);
  }

  void _onGlobalNotificationReceived(Map<String, dynamic> request, String type) {
    final backendType =
        (request['type'] ?? request['backendType'])?.toString() ?? '';

    if (backendType == 'ROAD_REQUEST_EXPIRED' ||
        backendType == 'ROAD_REQUEST_CANCELLED') {
      final eventId =
          request['requestId']?.toString() ?? request['requestid']?.toString();
      ActiveServiceRequestTracking.clearIfMatches(eventId);
      if (backendType == 'ROAD_REQUEST_CANCELLED') {
        return;
      }
      return;
    }

    if (mounted) {
      setState(() {
        if (type == 'appointment' || type == 'cancel') {
          _appointmentRequests.insert(0, request);
        } else {
          _roadRequests.insert(0, request);
        }
      });
    }
  }

  void _onActiveTrackingChanged() {
    _subscribeActiveRequestTopic();
    _syncActiveTrackingWithServer();
  }

  Future<void> _syncActiveTrackingWithServer() async {
    final active = ActiveServiceRequestTracking.current.value;
    if (active == null) return;

    final requestId =
        active['requestId']?.toString() ?? active['requestid']?.toString();
    if (requestId == null || requestId.isEmpty) {
      ActiveServiceRequestTracking.clear();
      if (mounted) setState(() {});
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/tracking/$requestId',
        ),
        headers: UserSession().getAuthHeader(),
      );

      if (response.statusCode == 404) {
        ActiveServiceRequestTracking.clear();
        if (mounted) setState(() {});
        return;
      }

      if (response.statusCode != 200 || response.body.isEmpty) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final status = (decoded['requestStatus'] ?? decoded['status'] ?? '')
          .toString()
          .toUpperCase();

      if (status == 'CANCELLED' ||
          status == 'REJECTED' ||
          status == 'EXPIRED' ||
          status == 'COMPLETED') {
        ActiveServiceRequestTracking.clear();
        _teardownActiveRequestSubscription();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Mechanic dashboard tracking sync failed: $e');
    }
  }

  void _teardownActiveRequestSubscription() {
    _activeRequestClient?.deactivate();
    _activeRequestClient = null;
    _subscribedRequestId = null;
  }

  void _subscribeActiveRequestTopic() {
    final active = ActiveServiceRequestTracking.current.value;
    if (!ActiveServiceRequestTracking.isActive(active)) {
      _teardownActiveRequestSubscription();
      return;
    }

    final requestId =
        active!['requestId']?.toString() ?? active['requestid']?.toString();
    if (requestId == null || requestId.isEmpty) {
      _teardownActiveRequestSubscription();
      return;
    }

    if (_subscribedRequestId == requestId && _activeRequestClient != null) {
      return;
    }

    _teardownActiveRequestSubscription();
    _subscribedRequestId = requestId;

    _activeRequestClient = StompClient(
      config: StompConfig(
        url:
            'wss://mechanicapp-service-621632382478.asia-south1.run.app/ws-notifications/websocket',
        stompConnectHeaders: UserSession().getAuthHeader(),
        webSocketConnectHeaders: UserSession().getAuthHeader(),
        onConnect: (_) {
          _activeRequestClient?.subscribe(
            destination: '/topic/request/$requestId',
            callback: (frame) {
              if (frame.body == null || frame.body!.isEmpty) return;
              try {
                final decoded = jsonDecode(frame.body!);
                if (decoded is! Map) return;
                final data = Map<String, dynamic>.from(decoded);
                final backendType =
                    (data['type'] ?? data['backendType'])?.toString() ?? '';
                final status = (data['status'] ?? data['requestStatus'])
                        ?.toString()
                        .toUpperCase() ??
                    '';

                if (backendType == 'ROAD_REQUEST_CANCELLED' ||
                    status == 'CANCELLED') {
                  ActiveServiceRequestTracking.clearIfMatches(requestId);
                  _teardownActiveRequestSubscription();
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Customer cancelled the request'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Dashboard request topic parse error: $e');
              }
            },
          );
        },
        onWebSocketError: (error) =>
            debugPrint('Dashboard request WS error: $error'),
      ),
    );
    _activeRequestClient?.activate();
  }

  @override
  void dispose() {
    ActiveServiceRequestTracking.current.removeListener(_onActiveTrackingChanged);
    MechanicNotificationController().removeListener(_onGlobalNotificationReceived);
    _teardownActiveRequestSubscription();
    super.dispose();
  }



  void _openNotificationCenter({int initialTabIndex = 0}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MechanicNotificationScreen(
          dailyRequests: _roadRequests,
          appointmentRequests: _appointmentRequests,
          initialTabIndex: initialTabIndex,
          onReadUpdate: _fetchAppointmentNotifications,
        ),
      ),
    ).then((_) {
      _fetchAppointmentNotifications();
    });
  }


  Future<void> _fetchDashboardData() async {
    final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/dashboard");

    try {
      final response =
          await http.get(url, headers: UserSession().getAuthHeader());

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is! Map) {
          debugPrint("⚠️ Mechanic Dashboard data is not a Map: $data");
          setState(() => _isLoading = false);
          return;
        }

        setState(() {
          mechanicName = data['name'] ?? mechanicName;
          mechanicRating =
              (data['averageRating'] as num?)?.toDouble() ?? mechanicRating;
          totalEarnings =
              (data['totalearning'] as num?)?.toDouble() ?? totalEarnings;
          todaysEarnings =
              (data['todaysEarnings'] as num?)?.toDouble() ??
                  todaysEarnings;
          totalServices =
              (data['totalServices'] as num?)?.toInt() ?? totalServices;
          mechanicImageUrl = data['mechanicimgurl'] ?? '';
          todaysServices =
              (data['todaysServices'] as num?)?.toInt() ??
                  todaysServices;

          if (data['isonline'] != null) {
            final onlineStatus = data['isonline'];
            isOnline = onlineStatus is bool 
                ? onlineStatus 
                : onlineStatus.toString().toLowerCase() == 'true';
          }

          _isLoading = false;
        });
        if (isOnline) {
          MechanicLiveLocationService.instance.start();
        }
        await _syncActiveTrackingWithServer();
        _subscribeActiveRequestTopic();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDashboard() async {
    await _fetchDashboardData();
    await _syncActiveTrackingWithServer();
    _subscribeActiveRequestTopic();
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() {
      _isToggleLoading = true;
    });

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/isactive");
    try {
      final response = await http.post(
        url,
        headers: {
          ...UserSession().getAuthHeader(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"isonline": value ? "true" : "false"}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          isOnline = value;
        });
        if (value) {
          MechanicLiveLocationService.instance.start();
        } else {
          MechanicLiveLocationService.instance.stop();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value ? 'You are now online' : 'You are now offline'),
              backgroundColor: value ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update status. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isToggleLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAppointmentNotifications() async {
    final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/appointments/allnotifications");

    try {
      final response =
          await http.get(url, headers: UserSession().getAuthHeader());

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          setState(() {
            _appointmentRequests.clear();
            for (var item in decoded) {
              if (item is Map) {
                _appointmentRequests.add(_mapAppointmentRequest(Map<String, dynamic>.from(item)));
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching appointment notifications: $e");
    }
  }

  Map<String, dynamic> _mapRoadRequest(Map<String, dynamic> data) {
    return {
      'type': 'road',
      'id': data['userid']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'userName': data['username'] ?? 'Unknown User',
      'location': data['userlocname'] ?? 'Location not provided',
      'time': TimeAgo.format(data['created_at']),
      'issue': 'Emergency Roadside Assistance',
      'price': data['price'] != null ? 'Rs. ${data['price']}' : 'Rs. --',
      'distance': data['distance'] != null ? '${data['distance']} km away' : '',
      'userimage': data['userimage'] ?? '',
      'lat': data['lat'],
      'lon': data['lon'],
      'isRead': false,
    };
  }

  Map<String, dynamic> _mapAppointmentRequest(Map<String, dynamic> data) {
    final rawUser = data['user'];
    final Map<String, dynamic> user = (rawUser is Map) ? Map<String, dynamic>.from(rawUser) : {};
    
    final String username = data['username'] ?? data['userName'] ?? user['username'] ?? user['phonenumber'] ?? data['userphonenumber'] ?? 'Appointment User';
    final String userImg = data['userimage'] ?? user['userimgurl'] ?? user['image'] ?? '';
    
    final rawDate = data['appointmentDate']?.toString() ?? '--';
    final rawTime = data['appointmentTime']?.toString() ?? '--';
    final scheduled = '$rawDate | $rawTime';

    final dynamic rawIsRead = data['read'] ?? data['isread'] ?? data['isRead'];
    final bool isRead = rawIsRead is bool ? rawIsRead : (rawIsRead?.toString().toLowerCase() == 'true');

    return {
      'type': 'appointment',
      'id': (data['notificationid'] ?? data['notificationId'] ?? data['id'] ?? data['appointmentid'] ?? data['appointmentId'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
      'appointmentId': (data['appointmentid'] ?? data['appointmentId'] ?? '').toString(),
      'userName': username,
      'userimage': userImg,
      'location': data['useraddress'] ?? data['address'] ?? 'Address not provided',
      'time': TimeAgo.format(data['created_at']),
      'issue': data['problemDescription'] ?? data['problem'] ?? 'Service appointment request',
      'price': 'Rs. --',
      'distance': '',
      'scheduledTime': scheduled,
      'serviceType': data['serviceType'] ?? data['servicetype'] ?? 'General Service',
      'status': data['status']?.toString() ?? 'PENDING',
      'isRead': isRead,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ??
                theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
      ),
      drawer: _buildDrawer(isDark, theme),
      body: _isLoading
          ? _SkeletonMechanicDashboard()
          : RefreshIndicator(
              onRefresh: _refreshDashboard,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<Map<String, dynamic>?>(
                      valueListenable: ActiveServiceRequestTracking.current,
                      builder: (context, activeRequest, _) {
                        if (!ActiveServiceRequestTracking.isActive(activeRequest)) {
                          return const SizedBox.shrink();
                        }
                        final request = activeRequest!;
                        final requestStatus =
                            (request['requestStatus'] ?? request['status'] ?? '')
                                .toString()
                                .toUpperCase();
                        final isPendingRoadRequest =
                            requestStatus == 'PENDING' &&
                            request['mechanicId'] == null;
                        final isPaymentPending =
                            request['paymentPending'] == true ||
                            requestStatus == 'PAYMENT_PENDING';
                        final isWaitingForPayment =
                            request['workCompleted'] == true ||
                            requestStatus == 'WAITING_FOR_PAYMENT' ||
                            requestStatus == 'WORK_COMPLETED';
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, accentOrange],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.navigation_rounded, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPendingRoadRequest
                                          ? 'Pending Service Request'
                                          : isPaymentPending
                                              ? 'Payment Pending'
                                              : isWaitingForPayment
                                                  ? 'Waiting for Payment'
                                              : 'Active Service in Progress',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      isPendingRoadRequest
                                          ? 'Tap to view request details'
                                          : isPaymentPending
                                              ? 'Tap to confirm cash payment'
                                              : isWaitingForPayment
                                                  ? 'Customer payment pending'
                                              : 'Tap to resume tracking map',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => isPendingRoadRequest
                                          ? MechanicRequestAlertScreen(requestData: request)
                                          : MechanicUserMap(requestData: request),
                                    ),
                                  );
                                  if (!mounted) return;
                                  await _syncActiveTrackingWithServer();
                                  _subscribeActiveRequestTopic();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('RESUME'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    /// HEADER 
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, $mechanicName 👋',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.titleLarge?.color,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '$mechanicRating Rating',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                _openNotificationCenter(
                                  initialTabIndex:
                                      _appointmentUnreadCount > 0 ? 1 : 0,
                                );
                              },
                              icon: Icon(Icons.notifications_outlined, color: primaryColor, size: 28),
                            ),
                            if (_notificationCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    '$_notificationCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// ONLINE / OFFLINE TOGGLE (Centered)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: isDark ? Border.all(color: Colors.grey.shade800) : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isOnline ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                            color: isOnline ? Colors.green.shade600 : Colors.red.shade400,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Offline',
                            style: GoogleFonts.poppins(
                              color: isOnline ? (isDark ? Colors.grey.shade600 : Colors.grey.shade400) : Colors.red.shade400,
                              fontWeight: isOnline ? FontWeight.w500 : FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _isToggleLoading
                              ? const SizedBox(
                                  width: 48,
                                  height: 36,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                )
                              : Switch(
                                  value: isOnline,
                                  activeColor: Colors.green.shade500,
                                  activeTrackColor: Colors.green.shade200,
                                  inactiveThumbColor: Colors.red.shade400,
                                  inactiveTrackColor: Colors.red.shade100,
                                  onChanged: _toggleOnlineStatus,
                                ),
                          const SizedBox(width: 12),
                          Text(
                            'Online',
                            style: GoogleFonts.poppins(
                              color: isOnline ? Colors.green.shade600 : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                              fontWeight: isOnline ? FontWeight.bold : FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    /// OVERVIEW
                    Text(
                      'Overview',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 14),

                    /// VERTICAL CARDS
                    Column(
                      children: [
                        _statCard(
                          label: "Today's Services",
                          value: todaysServices.toString(),
                          icon: Icons.build_circle_rounded,
                          accentColor: primaryColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),

                        _statCard(
                          label: "Today's Earnings",
                          value:
                              'Rs. ${todaysEarnings.toStringAsFixed(0)}',
                          icon: Icons.trending_up_rounded,
                          accentColor: const Color(0xFF1E88E5),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),

                        _statCard(
                          label: 'Total Earnings',
                          value:
                              'Rs. ${totalEarnings.toStringAsFixed(0)}',
                          icon:
                              Icons.account_balance_wallet_rounded,
                          accentColor: const Color(0xFF43A047),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 14),

                        _statCard(
                          label: 'Total Services',
                          value: totalServices.toString(),
                          icon: Icons.handyman_rounded,
                          accentColor: const Color(0xFF9C27B0),
                          isDark: isDark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  /// STAT CARD
  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
                alpha: isDark ? 0.30 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark ? Border.all(color: Colors.grey.shade800, width: 1) : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= DRAWER STYLED =================
  Widget _drawerItem(IconData icon, String title, BuildContext context, 
      {bool isLogout = false, required bool isDark, bool isSelected = false, VoidCallback? onTap, int badgeCount = 0}) {
    
    final Color itemColor = isLogout ? Colors.red : (isDark ? Colors.white70 : Colors.black87);
    final Color selectedBgColor = isDark ? primaryColor.withValues(alpha: 0.15) : primaryColor.withValues(alpha: 0.1);
    final Color selectedTextColor = primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? selectedBgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon, 
          color: isSelected ? selectedTextColor : itemColor, 
          size: 24
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: isSelected ? selectedTextColor : itemColor,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minLeadingWidth: 20,
      ),
    );
  }

  // Updated elegant drawer
  Drawer _buildDrawer(bool isDark, ThemeData theme) {
    return Drawer(
      backgroundColor: theme.drawerTheme.backgroundColor ??
          (isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: mechanicImageUrl.isNotEmpty
                        ? NetworkImage(mechanicImageUrl)
                        : const AssetImage('assets/images/m1.jpg') as ImageProvider,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoading ? "Loading..." : mechanicName,
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Mechanic Account",
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, 
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _drawerItem(Icons.dashboard_customize_rounded, "Dashboard", context, isDark: isDark, isSelected: true, onTap: () {
                  Navigator.pop(context);
                }),
                _drawerItem(Icons.calendar_today_rounded, "Appointment Requests", context, isDark: isDark, badgeCount: _appointmentUnreadCount, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MechanicAppointmentRequestScreen(
                        requests: _appointmentRequests,
                        onReadUpdate: () {
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ).then((_) {
                    _fetchAppointmentNotifications();
                  });
                }),
                _drawerItem(Icons.event_note_rounded, "Booking Requests", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicBookingRequestScreen()));
                }),
                _drawerItem(Icons.account_balance_wallet_rounded, "Earnings", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicEarningsScreen()));
                }),
                _drawerItem(Icons.build_rounded, "Services", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicServicesScreen()));
                }),
                _drawerItem(Icons.person_outline_rounded, "Profile", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicProfileScreen()));
                }),
                
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, thickness: 1),
                ),
                
                _drawerItem(Icons.settings_outlined, "Settings", context, isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MechanicSettingsScreen()));
                }),
                _drawerItem(Icons.logout_rounded, "Logout", context, isDark: isDark, isLogout: true, onTap: () async {
                  final nav = Navigator.of(context);
                  MechanicNotificationController().dispose(); // Close WebSocket
                  MechanicLiveLocationService.instance.stop();
                  await UserSession().logout();
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                    (route) => false,
                  );
                }),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: InkWell(
              onTap: () async {
                final nav = Navigator.of(context);
                MechanicNotificationController().dispose(); // Close WebSocket
                MechanicLiveLocationService.instance.stop();
                bool success = await UserSession().trySwitchTo('USER');
                if (success) {
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                } else {
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                    (route) => false,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.05),
                      blurRadius: 10, offset: const Offset(0, 4)
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz_rounded, color: primaryColor, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Return to User',
                      style: GoogleFonts.poppins(
                          color: primaryColor, 
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonMechanicDashboard extends StatelessWidget {
  const _SkeletonMechanicDashboard();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: List.generate(
            4,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
