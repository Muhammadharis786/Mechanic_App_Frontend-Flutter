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
import '../../services/mechanic_notification_controller.dart';
import '../../services/mechanic_live_location_service.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../../utils/time_utils.dart';
import 'mechanic_history.dart';
import '../../services/fcm_notification_service.dart';
import '../../services/mechanic_presence_service.dart';

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
      if (_restoreOnlineOnResume) {
        _restoreOnlineOnResume = false;
        unawaited(_toggleOnlineStatus(true, showSnack: false));
      }
      return;
    }

    final shouldGoOffline =
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;

    if (shouldGoOffline && isOnline && !_lifecycleOfflineUpdateInProgress) {
      _restoreOnlineOnResume = true;
      _lifecycleOfflineUpdateInProgress = true;
      unawaited(_toggleOnlineStatus(false, showSnack: false));
    }
  }

  void _initWebSocket() {
    MechanicNotificationController().init();
    MechanicNotificationController().addListener(_onGlobalNotificationReceived);
  }

  void _onGlobalNotificationReceived(
    Map<String, dynamic> request,
    String type,
  ) {
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
    ActiveServiceRequestTracking.current.removeListener(
      _onActiveTrackingChanged,
    );
    MechanicNotificationController().removeListener(
      _onGlobalNotificationReceived,
    );
    MechanicNotificationController()
        .removeListener(_onGlobalNotificationReceived);
    ActiveServiceRequestTracking.current
        .removeListener(_onActiveTrackingChanged);
    _teardownActiveRequestSubscription();
    _fadeController.dispose();
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
      "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/dashboard",
    );

    try {
      final response = await http.get(
        url,
        headers: UserSession().getAuthHeader(),
      );

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
          unawaited(MechanicPresenceService.instance.setLocalOnlineFlag(isOnline));

          _isLoading = false;
        });

        _fadeController.forward();

        if (isOnline) {
          final active = ActiveServiceRequestTracking.current.value;
          final activeRequestId =
              active?['requestId']?.toString() ??
              active?['requestid']?.toString();
          MechanicLiveLocationService.instance.start(
            requestId: activeRequestId,
          );
          unawaited(MechanicPresenceService.instance.ensureAndroidPresenceGuard());
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
      "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/recent-activity",
    );
    try {
      final response = await http.get(
        url,
        headers: UserSession().getAuthHeader(),
      );
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

  Future<void> _toggleOnlineStatus(bool value, {bool showSnack = true}) async {
    if (showSnack && mounted) {
      setState(() => _isToggleLoading = true);
    }

    try {
      final active = ActiveServiceRequestTracking.current.value;
      final activeRequestId = active?['requestId']?.toString() ??
          active?['requestid']?.toString();
      final success = await MechanicPresenceService.instance.updateOnlineStatus(
        value,
        activeRequestId: activeRequestId,
      );

      if (success) {
        if (mounted) {
          setState(() => isOnline = value);
        } else {
          isOnline = value;
        }

        if (value) {
          _lifecycleOfflineUpdateInProgress = false;
          final active = ActiveServiceRequestTracking.current.value;
          final activeRequestId =
              active?['requestId']?.toString() ??
              active?['requestid']?.toString();
          MechanicLiveLocationService.instance.start(
            requestId: activeRequestId,
          );
        } else {
          MechanicLiveLocationService.instance.stop();
        }
        if (showSnack && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                value ? 'You are now online' : 'You are now offline',
              ),
              backgroundColor: value ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        if (showSnack && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update status. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      if (showSnack && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
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
      "https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/appointments/allnotifications",
    );

    try {
      final response = await http.get(
        url,
        headers: UserSession().getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          setState(() {
            _appointmentRequests.clear();
            for (var item in decoded) {
              if (item is Map) {
                _appointmentRequests.add(
                  _mapAppointmentRequest(Map<String, dynamic>.from(item)),
                );
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching appointment notifications: $e");
    }
  }

  // ignore: unused_element
  Map<String, dynamic> _mapRoadRequest(Map<String, dynamic> data) {
    return {
      'type': 'road',
      'id':
          data['userid']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
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
    final Map<String, dynamic> user = (rawUser is Map)
        ? Map<String, dynamic>.from(rawUser)
        : {};

    final String username =
        data['username'] ??
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

    final dynamic rawIsRead = data['read'] ?? data['isread'] ?? data['isRead'];
    final bool isRead = rawIsRead is bool
        ? rawIsRead
        : (rawIsRead?.toString().toLowerCase() == 'true');

    return {
      'type': 'appointment',
      'id':
          (data['notificationid'] ??
                  data['notificationId'] ??
                  data['id'] ??
                  data['appointmentid'] ??
                  data['appointmentId'] ??
                  DateTime.now().millisecondsSinceEpoch.toString())
              .toString(),
      'appointmentId': (data['appointmentid'] ?? data['appointmentId'] ?? '')
          .toString(),
      'userName': username,
      'userimage': userImg,
      'location':
          data['useraddress'] ?? data['address'] ?? 'Address not provided',
      'time': TimeAgo.format(data['created_at']),
      'issue':
          data['problemDescription'] ??
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
      backgroundColor: isDark
          ? const Color(0xFF0F0F10)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FA),
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        centerTitle: false,
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => _openNotificationCenter(
                  initialTabIndex: _appointmentUnreadCount > 0 ? 1 : 0,
                ),
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 26,
                ),
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FA),
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
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
                      // ── PROFILE HEADER HERO CARD ──
                      _buildProfileHeader(isDark),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),

                            // ── ACTIVE REQUEST BANNER ──
                            ValueListenableBuilder<Map<String, dynamic>?>(
                              valueListenable:
                                  ActiveServiceRequestTracking.current,
                              builder: (context, activeRequest, _) {
                                if (!ActiveServiceRequestTracking.isActive(
                                  activeRequest,
                                )) {
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
                                    requestStatus == 'WAITING_FOR_PAYMENT' ||
                                    requestStatus == 'WORK_COMPLETED';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryColor, accentOrange],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.navigation_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
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
                                            const SizedBox(height: 2),
                                            Text(
                                              isPendingRoadRequest
                                                  ? 'Tap to view request details'
                                                  : isPaymentPending
                                                  ? 'Tap to confirm cash payment'
                                                  : isWaitingForPayment
                                                  ? 'Customer payment pending'
                                                  : 'Tap to resume tracking map',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white.withValues(alpha: 0.85),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
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
                                                      requestData: request,
                                                    )
                                                  : MechanicUserMap(
                                                      requestData: request,
                                                    ),
                                            ),
                                          );
                                          if (!mounted) return;
                                          await _syncActiveTrackingWithServer();
                                          _subscribeActiveRequestTopic();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: primaryColor,
                                          elevation: 4,
                                          shadowColor: Colors.black.withValues(alpha: 0.15),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: Text(
                                          'RESUME',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
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
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
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
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildQuickActions(isDark),

                            const SizedBox(height: 16),

                            // ── RECENT ACTIVITY ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Activity',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const MechanicHistoryScreen(),
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      "See All",
                                      style: TextStyle(
                                          fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                                          color: primaryColor,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
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

  // ── PROFILE HEADER HERO CARD ──
  Widget _buildProfileHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            accentOrange,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Background abstract decorative circles
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -50,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Photo, Name & Rating, Edit Button
                  Row(
                    children: [
                      // Profile Photo with custom status ring
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.white24,
                              backgroundImage: mechanicImageUrl.isNotEmpty
                                  ? NetworkImage(mechanicImageUrl)
                                  : const AssetImage('assets/images/m1.jpg') as ImageProvider,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accentOrange,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Name & Rating & Status pill
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $mechanicName 👋',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Rating Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        mechanicRating.toStringAsFixed(1),
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Online Status Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isOnline 
                                        ? Colors.green.shade600.withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isOnline 
                                          ? Colors.green.shade300.withValues(alpha: 0.5)
                                          : Colors.white.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    isOnline ? 'Online' : 'Offline',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Edit profile icon
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MechanicProfileScreen(),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Earnings Summary bottom glassmorphic bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Today's Earnings",
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Rs. ${todaysEarnings.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                "Total Earnings",
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Rs. ${totalEarnings.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  // ── ONLINE TOGGLE ──
  Widget _buildOnlineToggle(bool isDark) {
    final statusColor = isOnline ? const Color(0xFF4CAF50) : const Color(0xFFFF6D00);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.orange).withValues(
              alpha: isDark ? 0.12 : 0.05,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulse status indicator icon
          Stack(
            alignment: Alignment.center,
            children: [
              if (isOnline)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.15),
                  ),
                ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.wifi_tethering_rounded : Icons.portable_wifi_off_rounded,
                  color: isOnline ? Colors.green : Colors.orange,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOnline ? 'Go Offline' : 'Go Online',
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOnline
                      ? 'You are active & visible to customers'
                      : 'You are currently hidden from search',
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _isToggleLoading
              ? const SizedBox(
                  width: 48,
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  ),
                )
              : Switch(
                  value: isOnline,
                  activeThumbColor: Colors.green,
                  activeTrackColor: Colors.green.withValues(alpha: 0.3),
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade300,
                  onChanged: _toggleOnlineStatus,
                ),
        ],
      ),
    );
  }

  // ── STATS OVERVIEW CARDS ──
  Widget _buildStatsGrid(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCardMinimalist(
                label: "Today's Services",
                value: todaysServices.toString(),
                icon: Icons.build_circle_rounded,
                bgColor: primaryColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCardMinimalist(
                label: "Today's Earnings",
                value: 'Rs. ${todaysEarnings.toStringAsFixed(0)}',
                icon: Icons.trending_up_rounded,
                bgColor: const Color(0xFF1E88E5),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCardMinimalist(
                label: 'Total Earnings',
                value: 'Rs. ${totalEarnings.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_rounded,
                bgColor: const Color(0xFF43A047),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCardMinimalist(
                label: 'Total Services',
                value: totalServices.toString(),
                icon: Icons.handyman_rounded,
                bgColor: const Color(0xFF9C27B0),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCardMinimalist({
    required String label,
    required String value,
    required IconData icon,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.06) 
              : Colors.orange.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Clean white icon container/card
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon, 
                  color: primaryColor,
                  size: 20,
                ),
              ),
              Icon(
                icon,
                color: (isDark ? Colors.white : primaryColor).withValues(alpha: 0.04),
                size: 36,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── QUICK ACTIONS (HORIZONTAL ROW) ──
  Widget _buildQuickActions(bool isDark) {
    final actions = [
      {
        'label': 'Bookings',
        'icon': Icons.assignment_turned_in_rounded,
        'color': primaryColor,
        'badge': 0,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MechanicBookingRequestScreen(),
          ),
        ),
      },
      {
        'label': 'Appointments',
        'icon': Icons.calendar_month_rounded,
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
            ),
          ),
        ).then((_) => _fetchAppointmentNotifications()),
      },
      {
        'label': 'Earnings',
        'icon': Icons.payments_rounded,
        'color': const Color(0xFF43A047),
        'badge': 0,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MechanicEarningsScreen()),
        ),
      },
      {
        'label': 'Services',
        'icon': Icons.construction_rounded,
        'color': const Color(0xFF9C27B0),
        'badge': 0,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MechanicServicesScreen()),
        ),
      },
    ];

    return Row(
      children: actions.asMap().entries.map((entry) {
        final idx = entry.key;
        final action = entry.value;
        final badge = action['badge'] as int;
        final color = action['color'] as Color;
        final isLast = idx == actions.length - 1;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: action['onTap'] as VoidCallback,
                borderRadius: BorderRadius.circular(16),
                splashColor: color.withValues(alpha: 0.1),
                highlightColor: color.withValues(alpha: 0.05),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A30) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              action['icon'] as IconData,
                              color: color,
                              size: 18,
                            ),
                          ),
                          if (badge > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  badge > 99 ? '99+' : '$badge',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── RECENT ACTIVITY (TIMELINE STYLE) ──
  Widget _buildRecentActivity(bool isDark) {
    if (_recentJobs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 38,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No recent activity',
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Complete your first job to see it here',
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _recentJobs.asMap().entries.map((entry) {
        final i = entry.key;
        final job = entry.value;
        final isLast = i == _recentJobs.length - 1;

        // API fields
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
            ? Icons.calendar_month_rounded
            : Icons.build_circle_rounded;
        final Color activityColor = isAppointment
            ? const Color(0xFF1E88E5)
            : primaryColor;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline vertical indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FA),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: activityColor,
                          width: 3,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: activityColor.withValues(alpha: 0.3),
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Activity Card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border(
                      top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
                      right: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
                      bottom: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
                      left: BorderSide(color: activityColor, width: 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: activityColor.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                activityIcon,
                                color: activityColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    username,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    serviceType,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  amount == '--' ? 'Rs. --' : 'Rs. $amount',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                ),
                                if (displayDate.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    displayDate,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── DRAWER ITEM ──
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
    final Color itemColor = isLogout
        ? const Color(0xFFFF3B30)
        : (isDark ? Colors.white70 : Colors.black87);
    final Color selectedBgColor = isDark
        ? primaryColor.withValues(alpha: 0.15)
        : primaryColor.withValues(alpha: 0.08);
    final Color selectedTextColor = primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isSelected ? selectedBgColor : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(
          icon,
          color: isSelected ? selectedTextColor : itemColor,
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: isSelected ? selectedTextColor : itemColor,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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

  // ── BUILD DRAWER ──
  Drawer _buildDrawer(bool isDark, ThemeData theme) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F0F10) : Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 14,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E22) : Colors.white,
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
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: mechanicImageUrl.isNotEmpty
                        ? NetworkImage(mechanicImageUrl)
                        : const AssetImage('assets/images/m1.jpg')
                              as ImageProvider,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLoading ? "Loading..." : mechanicName,
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${mechanicRating.toStringAsFixed(1)} Rating',
                            style: GoogleFonts.poppins(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _drawerItem(
                  Icons.dashboard_customize_rounded,
                  "Dashboard",
                  context,
                  isDark: isDark,
                  isSelected: true,
                  onTap: () => Navigator.pop(context),
                ),
                _drawerItem(
                  Icons.calendar_today_rounded,
                  "Appointment Requests",
                  context,
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
                  },
                ),
                _drawerItem(
                  Icons.event_note_rounded,
                  "Booking Requests",
                  context,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MechanicBookingRequestScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  Icons.account_balance_wallet_rounded,
                  "Earnings",
                  context,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MechanicEarningsScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  Icons.build_rounded,
                  "My Services",
                  context,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MechanicServicesScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  Icons.history_rounded,
                  "Service History",
                  context,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MechanicHistoryScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  Icons.person_outline_rounded,
                  "Profile",
                  context,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MechanicProfileScreen(),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                    thickness: 1,
                  ),
                ),
                _drawerItem(
                  Icons.settings_outlined,
                  "Settings",
                  context,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MechanicSettingsScreen(),
                      ),
                    );
                  },
                ),
                _drawerItem(
                  Icons.logout_rounded,
                  "Logout",
                  context,
                  isDark: isDark,
                  isLogout: true,
                  onTap: () async {
                    final nav = Navigator.of(context);
                    MechanicNotificationController().dispose();
                    MechanicLiveLocationService.instance.stop();
                    await UserSession().logout();
                    nav.pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const RoleSelectionScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
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
                          builder: (_) => const RoleSelectionScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Return to User',
                          style: GoogleFonts.poppins(
                            color: primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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

// ── SKELETON LOADER ──
class _SkeletonMechanicDashboard extends StatelessWidget {
  const _SkeletonMechanicDashboard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
        child: Column(
          children: [
            // Profile skeleton
            Container(
              height: 160,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
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
                      borderRadius: BorderRadius.circular(20),
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
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Quick actions skeleton (single horizontal row)
                  Row(
                    children: List.generate(
                      4,
                      (idx) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: idx == 3 ? 0 : 8),
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Recent activity skeleton (timeline format)
                  ...List.generate(
                    3,
                    (idx) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ],
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