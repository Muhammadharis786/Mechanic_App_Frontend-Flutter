import 'package:flutter/foundation.dart';

class ActiveServiceRequestTracking {
  ActiveServiceRequestTracking._();

  static final ValueNotifier<Map<String, dynamic>?> current =
      ValueNotifier<Map<String, dynamic>?>(null);

  static void save(Map<String, dynamic> tracking) {
    current.value = Map<String, dynamic>.from(tracking);
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
}
