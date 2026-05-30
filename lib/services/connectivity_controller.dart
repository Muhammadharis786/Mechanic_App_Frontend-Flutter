import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

enum ConnectionQuality { good, poor, none }

class ConnectivityController {
  static final ConnectivityController _instance = ConnectivityController._internal();
  factory ConnectivityController() => _instance;
  ConnectivityController._internal();

  OverlayEntry? _overlayEntry;
  ConnectionQuality _quality = ConnectionQuality.good;
  Timer? _latencyTimer;

  void init() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _handleConnectivityChange(results);
    });
    
    // Initial check
    Connectivity().checkConnectivity().then((List<ConnectivityResult> results) {
      _handleConnectivityChange(results);
    });
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      _updateStatus(ConnectionQuality.none);
      _latencyTimer?.cancel();
    } else {
      // Re-connected or already connected - check quality
      if (_quality == ConnectionQuality.none) {
        _updateStatus(ConnectionQuality.good);
      }
      _startLatencyCheck();
    }
  }

  void _startLatencyCheck() {
    _latencyTimer?.cancel();
    // Immediate check
    _checkAndShowLatency();
    
    // Periodic check
    _latencyTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndShowLatency();
    });
  }

  Future<void> _checkAndShowLatency() async {
    final quality = await _checkLatency();
    _updateStatus(quality);
  }

  Future<ConnectionQuality> _checkLatency() async {
    try {
      final stopwatch = Stopwatch()..start();
      // Using a small, reliable endpoint for low data consumption
      final response = await http.head(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 8));
      stopwatch.stop();
      
      if (response.statusCode >= 200 && response.statusCode < 400) {
        // threshold for "poor" connection (e.g., 2000ms)
        if (stopwatch.elapsedMilliseconds > 2000) {
          return ConnectionQuality.poor;
        }
        return ConnectionQuality.good;
      }
      return ConnectionQuality.none;
    } catch (_) {
      // If we can't even send a head request, it's effectively none
      return ConnectionQuality.none;
    }
  }

  void _updateStatus(ConnectionQuality newQuality) {
    if (_quality == newQuality) return;
    _quality = newQuality;
    
    // Schedule overlay update on next frame to avoid "setState during build" errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toggleOverlay();
    });
  }

  void _toggleOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;

    if (_quality == ConnectionQuality.good) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _ConnectivityBadge(quality: _quality),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }
}

class _ConnectivityBadge extends StatelessWidget {
  final ConnectionQuality quality;
  const _ConnectivityBadge({required this.quality});

  @override
  Widget build(BuildContext context) {
    final bool isNone = quality == ConnectionQuality.none;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * -20),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isNone ? const Color(0xFFD32F2F) : const Color(0xFFFFA000),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isNone ? Icons.wifi_off_rounded : Icons.signal_cellular_connected_no_internet_4_bar_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNone ? 'No Internet Connection' : 'Poor Connection',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        isNone ? 'Please check your settings' : 'Connectivity is very weak',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                      ),
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
}
