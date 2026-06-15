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
import '../../services/websocket_service.dart';
import '../../services/mechanic_notification_controller.dart';
import '../../services/mechanic_live_location_service.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../utils/time_utils.dart';
import 'mechanic_history.dart';
import '../../services/fcm_notification_service.dart';

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final Color primaryColor = const Color(0xFFE64A19);
  final Color accentOrange = const Color(0xFFFF6D00);

  bool _isLoading = true;
  bool _isToggleLoading = false;
  bool isOnline = false;
  bool _restoreOnlineOnResume = false;
  bool _lifecycleOfflineUpdateInProgress = false;

  double totalEarnings = 0;
  double todaysEarnings = 0;
  int totalServices = 0;
  int todaysServices = 0;
  double mechanicRating = 0;
  String mechanicName = "Mechanic";
  String mechanicImageUrl = '';

  // Recent jobs list
  List<Map<String, dynamic>> _recentJobs = [];

  final List<Map<String, dynamic>> _roadRequests = [];
  final List<Map<String, dynamic>> _appointmentRequests = [];

  StompClient? _activeRequestClient;
  String? _subscribedRequestId;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int get _dailyUnreadCount =>
      _roadRequests.where((e) => e['isRead'] == false).length;
  int get _appointmentUnreadCount =>
      _appointmentRequests.where((e) => e['isRead'] == false).length;
  int get _notificationCount => _dailyUnreadCount + _appointmentUnreadCount;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    ActiveServiceRequestTracking.current.addListener(_onActiveTrackingChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ActiveServiceRequestTracking.load();
      await ActiveServiceRequestTracking.syncWithServer();
      if (mounted) setState(() {});
      _subscribeActiveRequestTopic();
    });
    _fetchDashboardData();
    _fetchAppointmentNotifications();
    _fetchRecentJobs();
    _initWebSocket();
    FcmNotificationService.instance.syncTokenWithBackend();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncActiveTrackingWithServer();
      _subscribeActiveRequestTopic();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      return;
    }

    final shouldGoOffline = state == AppLifecycleState.detached;

    if (shouldGoOffline && isOnline && !_lifecycleOfflineUpdateInProgress) {
      _lifecycleOfflineUpdateInProgress = true;
      unawaited(_toggleOnlineStatus(false, showSnack: false));
    }
  }

  void _initWebSocket() {
    MechanicNotificationController().init();
    MechanicNotificationController().addListener(_onGlobalNotificationReceived);
  }

  void _onGlobalNotificationReceived(
      Map<String, dynamic> request, String type) {
    final backendType =
        (request['type'] ?? request['backendType'])?.toString() ?? '';

    if (backendType == 'ROAD_REQUEST_EXPIRED' ||
        backendType == 'ROAD_REQUEST_CANCELLED') {
      final eventId =
          request['requestId']?.toString() ?? request['requestid']?.toString();
      ActiveServiceRequestTracking.clearIfMatches(eventId);
      _teardownActiveRequestSubscription();
      if (mounted) setState(() {});
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
    await ActiveServiceRequestTracking.syncWithServer();
    if (!mounted) return;
    if (!ActiveServiceRequestTracking.isActive(
      ActiveServiceRequestTracking.current.value,
    )) {
      _teardownActiveRequestSubscription();
      setState(() {});
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
                final status =
                    (data['status'] ?? data['requestStatus'])
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
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    ActiveServiceRequestTracking.current
        .removeListener(_onActiveTrackingChanged);
    MechanicNotificationController()
        .removeListener(_onGlobalNotificationReceived);
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
              (data['todaysEarnings'] as num?)?.toDouble() ?? todaysEarnings;
          totalServices =
              (data['totalServices'] as num?)?.toInt() ?? totalServices;
          mechanicImageUrl = data['mechanicimgurl'] ?? '';
          todaysServices =
              (data['todaysServices'] as num?)?.toInt() ?? todaysServices;

          if (data['isonline'] != null) {
            final onlineStatus = data['isonline'];
            isOnline = onlineStatus is bool
                ? onlineStatus
                : onlineStatus.toString().toLowerCase() == 'true';
          }

          _isLoading = false;
        });

        _fadeController.forward();

        if (isOnline) {
          final active = ActiveServiceRequestTracking.current.value;
          final activeRequestId = active?['requestId']?.toString() ??
              active?['requestid']?.toString();
          MechanicLiveLocationService.instance.start(
            requestId: activeRequestId,
          );
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

  Future<void> _fetchRecentJobs() async {
    final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/recent-activity");
    try {
      final response =
          await http.get(url, headers: UserSession().getAuthHeader());
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            _recentJobs = data
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Recent jobs fetch failed: $e');
    }
  }

  Future<void> _refreshDashboard() async {
    _fadeController.reset();
    await _fetchDashboardData();
    await _fetchAppointmentNotifications();
    await _fetchRecentJobs();
    await _syncActiveTrackingWithServer();
    _subscribeActiveRequestTopic();
  }

  Future<void> _toggleOnlineStatus(
    bool value, {
    bool showSnack = true,
  }) async {
    if (showSnack && mounted) {
      setState(() => _isToggleLoading = true);
    }

    final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/isactive");
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
        if (mounted) {
          setState(() => isOnline = value);
        } else {
          isOnline = value;
        }

        if (value) {
          _lifecycleOfflineUpdateInProgress = false;
          final active = ActiveServiceRequestTracking.current.value;
          final activeRequestId = active?['requestId']?.toString() ??
              active?['requestid']?.toString();
          MechanicLiveLocationService.instance
              .start(requestId: activeRequestId);
        } else {
          MechanicLiveLocationService.instance.stop();
        }
        if (showSnack && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(value ? 'You are now online' : 'You are now offline'),
              backgroundColor: value ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        if (showSnack && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to update status. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (showSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    } finally {
      if (!value) {
        _lifecycleOfflineUpdateInProgress = false;
      }
      if (showSnack && mounted) {
        setState(() => _isToggleLoading = false);
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
                _appointmentRequests.add(
                    _mapAppointmentRequest(Map<String, dynamic>.from(item)));
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
      'id': data['userid']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'userName': data['username'] ?? 'Unknown User',
      'location': data['userlocname'] ?? 'Location not provided',
      'time': TimeAgo.format(data['created_at']),
      'issue': 'Emergency Roadside Assistance',
      'price': data['price'] != null ? 'Rs. ${data['price']}' : 'Rs. --',
      'distance':
          data['distance'] != null ? '${data['distance']} km away' : '',
      'userimage': data['userimage'] ?? '',
      'lat': data['lat'],
      'lon': data['lon'],
      'isRead': false,
    };
  }

  Map<String, dynamic> _mapAppointmentRequest(Map<String, dynamic> data) {
    final rawUser = data['user'];
    final Map<String, dynamic> user =
        (rawUser is Map) ? Map<String, dynamic>.from(rawUser) : {};

    final String username = data['username'] ??
        data['userName'] ??
        user['username'] ??
        user['phonenumber'] ??
        data['userphonenumber'] ??
        'Appointment User';
    final String userImg =
        data['userimage'] ?? user['userimgurl'] ?? user['image'] ?? '';

    final rawDate = data['appointmentDate']?.toString() ?? '--';
    final rawTime = data['appointmentTime']?.toString() ?? '--';
    final scheduled = '$rawDate | $rawTime';

    final dynamic rawIsRead =
        data['read'] ?? data['isread'] ?? data['isRead'];
    final bool isRead = rawIsRead is bool
        ? rawIsRead
        : (rawIsRead?.toString().toLowerCase() == 'true');

    return {
      'type': 'appointment',
      'id': (data['notificationid'] ??
              data['notificationId'] ??
              data['id'] ??
              data['appointmentid'] ??
              data['appointmentId'] ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .toString(),
      'appointmentId':
          (data['appointmentid'] ?? data['appointmentId'] ?? '').toString(),
      'userName': username,
      'userimage': userImg,
      'location':
          data['useraddress'] ?? data['address'] ?? 'Address not provided',
      'time': TimeAgo.format(data['created_at']),
      'issue': data['problemDescription'] ??
          data['problem'] ??
          'Service appointment request',
      'price': 'Rs. --',
      'distance': '',
      'scheduledTime': scheduled,
      'serviceType':
          data['serviceType'] ?? data['servicetype'] ?? 'General Service',
      'status': data['status']?.toString() ?? 'PENDING',
      'isRead': isRead,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => _openNotificationCenter(
                    initialTabIndex: _appointmentUnreadCount > 0 ? 1 : 0),
                icon: Icon(Icons.notifications_outlined,
                    color: primaryColor, size: 28),
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
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(isDark, theme),
      body: _isLoading
          ? const _SkeletonMechanicDashboard()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _refreshDashboard,
                color: primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── PROFILE HEADER SECTION ──
                      _buildProfileHeader(isDark),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),

                            // ── ACTIVE REQUEST BANNER ──
                            ValueListenableBuilder<Map<String, dynamic>?>(
                              valueListenable:
                                  ActiveServiceRequestTracking.current,
                              builder: (context, activeRequest, _) {
                                if (!ActiveServiceRequestTracking.isActive(
                                    activeRequest)) {
                                  return const SizedBox.shrink();
                                }
                                final request = activeRequest!;
                                final requestStatus =
                                    (request['requestStatus'] ??
                                            request['status'] ??
                                            '')
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
                                        requestStatus ==
                                            'WAITING_FOR_PAYMENT' ||
                                        requestStatus == 'WORK_COMPLETED';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
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
                                        color:
                                            primaryColor.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                            Icons.navigation_rounded,
                                            color: Colors.white,
                                            size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              builder: (context) =>
                                                  isPendingRoadRequest
                                                      ? MechanicRequestAlertScreen(
                                                          requestData: request)
                                                      : MechanicUserMap(
                                                          requestData: request),
                                            ),
                                          );
                                          if (!mounted) return;
                                          await _syncActiveTrackingWithServer();
                                          _subscribeActiveRequestTopic();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: primaryColor,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                        ),
                                        child: Text('RESUME',
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            // ── ONLINE / OFFLINE TOGGLE ──
                            _buildOnlineToggle(isDark),

                            const SizedBox(height: 24),

                            // ── STATS GRID 2x2 ──
                            Text(
                              'Overview',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: theme.textTheme.titleLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildStatsGrid(isDark),

                            const SizedBox(height: 24),

                            // ── QUICK ACTIONS ──
                            Text(
                              'Quick Actions',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: theme.textTheme.titleLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildQuickActions(isDark),

                            const SizedBox(height: 24),

                            // ── RECENT ACTIVITY ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Activity',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textTheme.titleLarge?.color,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const MechanicHistoryScreen())),
                                  child: Text(
                                    'See All',
                                    style: GoogleFonts.poppins(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildRecentActivity(isDark),

                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── PROFILE HEADER ──
  Widget _buildProfileHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Photo
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryColor, accentOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: mechanicImageUrl.isNotEmpty
                      ? NetworkImage(mechanicImageUrl)
                      : const AssetImage('assets/images/m1.jpg')
                          as ImageProvider,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Name & Rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $mechanicName 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Stars
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < mechanicRating.floor()
                              ? Icons.star_rounded
                              : i < mechanicRating
                                  ? Icons.star_half_rounded
                                  : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${mechanicRating.toStringAsFixed(1)} Rating',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Profile edit button
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MechanicProfileScreen())),
            icon: Icon(Icons.edit_outlined, color: primaryColor, size: 22),
          ),
        ],
      ),
    );
  }

  // ── ONLINE TOGGLE ──
  Widget _buildOnlineToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.red.withValues(alpha: 0.3),
          width: 1.5,
        ),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOnline
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOnline ? Icons.sensors_rounded : Icons.sensors_off_rounded,
              color: isOnline ? Colors.green.shade600 : Colors.red.shade400,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Offline',
            style: GoogleFonts.poppins(
              color: isOnline
                  ? (isDark ? Colors.grey.shade600 : Colors.grey.shade400)
                  : Colors.red.shade400,
              fontWeight: isOnline ? FontWeight.w500 : FontWeight.bold,
              fontSize: 15,
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
              color: isOnline
                  ? Colors.green.shade600
                  : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
              fontWeight: isOnline ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ── STATS 2x2 GRID ──
  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _gridStatCard(
          label: "Today's Services",
          value: todaysServices.toString(),
          icon: Icons.build_circle_rounded,
          accentColor: primaryColor,
          isDark: isDark,
        ),
        _gridStatCard(
          label: "Today's Earnings",
          value: 'Rs. ${todaysEarnings.toStringAsFixed(0)}',
          icon: Icons.trending_up_rounded,
          accentColor: const Color(0xFF1E88E5),
          isDark: isDark,
        ),
        _gridStatCard(
          label: 'Total Earnings',
          value: 'Rs. ${totalEarnings.toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet_rounded,
          accentColor: const Color(0xFF43A047),
          isDark: isDark,
        ),
        _gridStatCard(
          label: 'Total Services',
          value: totalServices.toString(),
          icon: Icons.handyman_rounded,
          accentColor: const Color(0xFF9C27B0),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _gridStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark
            ? Border.all(color: Colors.grey.shade800, width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.grey.shade400 : Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── QUICK ACTIONS ──
  Widget _buildQuickActions(bool isDark) {
    final actions = [
      {
        'label': 'Bookings',
        'icon': Icons.event_note_rounded,
        'color': const Color(0xFFE64A19),
        'badge': 0,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MechanicBookingRequestScreen())),
      },
      {
        'label': 'Appointments',
        'icon': Icons.calendar_today_rounded,
        'color': const Color(0xFF1E88E5),
        'badge': _appointmentUnreadCount,
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MechanicAppointmentRequestScreen(
                      requests: _appointmentRequests,
                      onReadUpdate: () {
                        if (mounted) setState(() {});
                      },
                    ))).then((_) => _fetchAppointmentNotifications()),
      },
      {
        'label': 'Earnings',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF43A047),
        'badge': 0,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MechanicEarningsScreen())),
      },
      {
        'label': 'Services',
        'icon': Icons.build_rounded,
        'color': const Color(0xFF9C27B0),
        'badge': 0,
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MechanicServicesScreen())),
      },
    ];

    return Row(
      children: actions.map((action) {
        final badge = action['badge'] as int;
        final color = action['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: action['onTap'] as VoidCallback,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isDark
                    ? Border.all(color: Colors.grey.shade800)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(action['icon'] as IconData,
                            color: color, size: 24),
                      ),
                      if (badge > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            child: Text(
                              '$badge',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── RECENT ACTIVITY ──
  Widget _buildRecentActivity(bool isDark) {
    if (_recentJobs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded,
                  size: 40,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'No recent activity',
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _recentJobs.asMap().entries.map((entry) {
          final i = entry.key;
          final job = entry.value;
          final isLast = i == _recentJobs.length - 1;

          // New API fields
          final String type = job['type']?.toString() ?? 'SERVICE_REQUEST';
          final bool isAppointment = type == 'APPOINTMENT';
          final amount = job['amount']?.toString() ?? '--';
          final username = job['username']?.toString() ?? 'Customer';
          final serviceType = job['serviceType']?.toString() ?? 'Service';
          final completedAt = job['completedAt']?.toString() ?? '';
          final displayDate = completedAt.length >= 10
              ? completedAt.substring(0, 10)
              : completedAt;

          // Icon aur color type ke hisaab se
          final IconData activityIcon = isAppointment
              ? Icons.calendar_today_rounded
              : Icons.build_circle_rounded;
          final Color activityColor = isAppointment
              ? const Color(0xFF1E88E5)
              : primaryColor;

          return Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: activityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(activityIcon, color: activityColor, size: 20),
                ),
                title: Text(
                  username,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  serviceType,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.black54,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount == '--' ? 'Rs. --' : 'Rs. $amount',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green.shade600,
                      ),
                    ),
                    if (displayDate.isNotEmpty)
                      Text(
                        displayDate,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── DRAWER ──
  Widget _drawerItem(
    IconData icon,
    String title,
    BuildContext context, {
    bool isLogout = false,
    required bool isDark,
    bool isSelected = false,
    VoidCallback? onTap,
    int badgeCount = 0,
  }) {
    final Color itemColor =
        isLogout ? Colors.red : (isDark ? Colors.white70 : Colors.black87);
    final Color selectedBgColor = isDark
        ? primaryColor.withValues(alpha: 0.15)
        : primaryColor.withValues(alpha: 0.1);
    final Color selectedTextColor = primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? selectedBgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon,
            color: isSelected ? selectedTextColor : itemColor, size: 24),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: isSelected ? selectedTextColor : itemColor,
            fontSize: 15,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w500,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minLeadingWidth: 20,
      ),
    );
  }

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
                  color:
                      isDark ? Colors.white10 : Colors.grey.shade100,
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
                    border: Border.all(
                        color: primaryColor.withValues(alpha: 0.5),
                        width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: mechanicImageUrl.isNotEmpty
                        ? NetworkImage(mechanicImageUrl)
                        : const AssetImage('assets/images/m1.jpg')
                            as ImageProvider,
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
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$mechanicRating Rating',
                            style: GoogleFonts.poppins(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                _drawerItem(
                    Icons.dashboard_customize_rounded, "Dashboard", context,
                    isDark: isDark,
                    isSelected: true,
                    onTap: () => Navigator.pop(context)),
                _drawerItem(Icons.calendar_today_rounded,
                    "Appointment Requests", context,
                    isDark: isDark,
                    badgeCount: _appointmentUnreadCount,
                    onTap: () {
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
                  ).then((_) => _fetchAppointmentNotifications());
                }),
                _drawerItem(
                    Icons.event_note_rounded, "Booking Requests", context,
                    isDark: isDark,
                    onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const MechanicBookingRequestScreen()));
                }),
                _drawerItem(Icons.account_balance_wallet_rounded, "Earnings",
                    context,
                    isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MechanicEarningsScreen()));
                }),
                _drawerItem(Icons.build_rounded, "Services", context,
                    isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MechanicServicesScreen()));
                }),
                _drawerItem(Icons.history_rounded, "Service History",
                    context,
                    isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MechanicHistoryScreen()));
                }),
                _drawerItem(Icons.person_outline_rounded, "Profile", context,
                    isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MechanicProfileScreen()));
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                      thickness: 1),
                ),
                _drawerItem(Icons.settings_outlined, "Settings", context,
                    isDark: isDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MechanicSettingsScreen()));
                }),
                _drawerItem(Icons.logout_rounded, "Logout", context,
                    isDark: isDark,
                    isLogout: true,
                    onTap: () async {
                  final nav = Navigator.of(context);
                  MechanicNotificationController().dispose();
                  MechanicLiveLocationService.instance.stop();
                  await UserSession().logout();
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const RoleSelectionScreen()),
                    (route) => false,
                  );
                }),
              ],
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: InkWell(
              onTap: () async {
                final nav = Navigator.of(context);
                MechanicNotificationController().dispose();
                MechanicLiveLocationService.instance.stop();
                bool success = await UserSession().trySwitchTo('USER');
                if (success) {
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                } else {
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const RoleSelectionScreen()),
                    (route) => false,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:
                      isDark ? Colors.grey[850] : Colors.white,
                  border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swap_horiz_rounded,
                        color: primaryColor, size: 22),
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

// ── SKELETON LOADER ──
class _SkeletonMechanicDashboard extends StatelessWidget {
  const _SkeletonMechanicDashboard();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            // Profile skeleton
            Container(
              height: 100,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 16),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Toggle skeleton
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                  ),
                  // Grid skeleton
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: List.generate(
                      4,
                      (_) => Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Quick actions skeleton
                  Row(
                    children: List.generate(
                      4,
                      (_) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Recent activity skeleton
                  ...List.generate(
                    3,
                    (_) => Container(
                      height: 64,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
