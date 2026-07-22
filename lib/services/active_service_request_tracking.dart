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

  static final ValueNotifier<String?> lastExitMessage =
      ValueNotifier<String?>(null);

  static final ValueNotifier<String?> lastExitStatus =
      ValueNotifier<String?>(null);

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

    return !_isTerminalStatus(status, backendType);
  }

  static bool _isTerminalStatus(String? status, String? backendType) {
    final terminalStatuses = {
      'CANCELLED',
      'COMPLETED',
      'REJECTED',
      'EXPIRED',
    };
    final terminalTypes = {
      'ROAD_REQUEST_CANCELLED',
      'ROAD_REQUEST_EXPIRED',
      'ROAD_REQUEST_REJECTED',
      'ROAD_REQUEST_COMPLETED',
      'APPOINTMENT_CANCELLED',
      'APPOINTMENT_EXPIRED',
      'APPOINTMENT_REJECTED',
      'APPOINTMENT_COMPLETED',
      'REQUEST_EXPIRED',
      'PAYMENT_DONE',
      'PAYMENT_SUCCESS',
      'PAYMENT_COMPLETED',
    };

    return terminalStatuses.contains(status) ||
        terminalTypes.contains(backendType);
  }

  static void clear({String? message, String? status}) {
    if (message != null) {
      lastExitMessage.value = message;
    }
    lastExitStatus.value = status;
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
  static void clearIfMatches(String? requestId, {String? message, String? status}) {
    if (requestId == null || requestId.isEmpty) return;
    final active = current.value;
    if (active == null) return;
    final activeId =
        active['requestId']?.toString() ?? active['requestid']?.toString();
    if (_idsMatch(activeId, requestId)) {
      clear(message: message, status: status);
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
      ).timeout(const Duration(seconds: 15)); // Increased from 8 to 15 seconds

      if (response.statusCode == 404) {
        clear(status: 'NOT_FOUND');
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

      if (_isTerminalStatus(status, backendType)) {
        final backendMsg = decoded['message']?.toString();
        // If it's specifically PAYMENT_DONE, prioritize 'COMPLETED' as status for UI navigation
        final exitStatus = (backendType == 'PAYMENT_DONE' ||
                backendType == 'PAYMENT_SUCCESS' ||
                backendType == 'PAYMENT_COMPLETED')
            ? 'COMPLETED'
            : status;
        clear(message: backendMsg, status: exitStatus);
        return;
      }

      save({
        ...active,
        ...Map<String, dynamic>.from(decoded),
      });
    } catch (e) {
    }
  }

  /// Checks if the current active request is CANCELLED or EXPIRED via backend
  static Future<void> validateAndClearIfTerminal() async {
    final active = current.value;
    if (active == null) {
      return;
    }

    final requestId =
        active['requestId']?.toString() ?? active['requestid']?.toString();
    if (requestId == null || requestId.isEmpty) {
      clear();
      return;
    }

    final headers = UserSession().getAuthHeader();
    if (headers.isEmpty) {
      return;
    }


    try {
      final response = await http.get(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/checkrequest/$requestId',
        ),
        headers: headers,
      ).timeout(const Duration(seconds: 5));


      if (response.statusCode == 404) {
        clear(status: 'NOT_FOUND');
        return;
      }

      if (response.statusCode != 200 || response.body.isEmpty) return;

      // Backend plain string return kar raha hai: "CANCELLED", "EXPIRED", etc.
      final status = response.body.trim().replaceAll('"', '').toUpperCase();


      // Agar CANCELLED ya EXPIRED hai toh clear kar do
      if (status == 'CANCELLED' || status == 'EXPIRED') {
        clear(status: status);
      }
    } catch (e) {
    }
  }

  static void _persist(Map<String, dynamic>? tracking) {
    if (tracking == null) return;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_storageKey, jsonEncode(tracking));
    }).catchError((e) {
    });
  }

  static Future<void> _removePersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
    }
  }
}
