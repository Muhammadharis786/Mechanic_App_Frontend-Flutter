import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/authentication/user_session.dart';

class ActiveServiceRequestTracking {
  ActiveServiceRequestTracking._();

  static const _storageKey = 'active_service_request_tracking';

  static final ValueNotifier<Map<String, dynamic>?> current =
      ValueNotifier<Map<String, dynamic>?>(null);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final tracking = Map<String, dynamic>.from(decoded);
        if (isActive(tracking)) {
          current.value = tracking;
        } else {
          await _removePersisted();
        }
      }
    } catch (e) {
      debugPrint('Active tracking load failed: $e');
    }
  }

  static void save(Map<String, dynamic> tracking) {
    current.value = Map<String, dynamic>.from(tracking);
    _persist(current.value);
  }

  static bool isActive(Map<String, dynamic>? tracking) {
    if (tracking == null) return false;
    final status = (tracking['status'] ?? tracking['requestStatus'])
        ?.toString()
        .toUpperCase();
    final backendType = (tracking['backendType'] ?? tracking['type'])
        ?.toString()
        .toUpperCase();

    return status != 'CANCELLED' &&
        status != 'COMPLETED' &&
        status != 'REJECTED' &&
        status != 'EXPIRED' &&
        backendType != 'ROAD_REQUEST_CANCELLED' &&
        backendType != 'ROAD_REQUEST_EXPIRED' &&
        backendType != 'APPOINTMENT_CANCELLED';
  }

  static void clear() {
    current.value = null;
    _removePersisted();
  }

  static bool _idsMatch(String? a, String? b) {
    if (a == null || b == null) return false;
    final aTrim = a.trim();
    final bTrim = b.trim();
    if (aTrim == bTrim) return true;
    final aNum = int.tryParse(aTrim);
    final bNum = int.tryParse(bTrim);
    if (aNum != null && bNum != null) return aNum == bNum;
    return false;
  }

  /// Clears active tracking when [requestId] matches the stored request.
  static void clearIfMatches(String? requestId) {
    if (requestId == null || requestId.isEmpty) return;
    final active = current.value;
    if (active == null) return;
    final activeId =
        active['requestId']?.toString() ?? active['requestid']?.toString();
    if (_idsMatch(activeId, requestId)) {
      clear();
    }
  }

  static Future<void> syncWithServer() async {
    final active = current.value;
    if (active == null) return;

    final requestId =
        active['requestId']?.toString() ?? active['requestid']?.toString();
    if (requestId == null || requestId.isEmpty) {
      clear();
      return;
    }

    final headers = UserSession().getAuthHeader();
    if (headers.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/tracking/$requestId',
        ),
        headers: headers,
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        clear();
        return;
      }

      if (response.statusCode != 200 || response.body.isEmpty) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;

      final status = (decoded['requestStatus'] ?? decoded['status'] ?? '')
          .toString()
          .toUpperCase();
      final backendType =
          (decoded['type'] ?? decoded['backendType'] ?? '').toString().toUpperCase();

      if (status == 'CANCELLED' ||
          status == 'REJECTED' ||
          status == 'EXPIRED' ||
          status == 'COMPLETED' ||
          backendType == 'ROAD_REQUEST_CANCELLED' ||
          backendType == 'ROAD_REQUEST_EXPIRED') {
        clear();
        return;
      }

      save({
        ...active,
        ...Map<String, dynamic>.from(decoded),
      });
    } catch (e) {
      debugPrint('Active tracking sync failed: $e');
    }
  }

  static void _persist(Map<String, dynamic>? tracking) {
    if (tracking == null) return;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_storageKey, jsonEncode(tracking));
    }).catchError((e) {
      debugPrint('Active tracking persist failed: $e');
    });
  }

  static Future<void> _removePersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('Active tracking remove failed: $e');
    }
  }
}
