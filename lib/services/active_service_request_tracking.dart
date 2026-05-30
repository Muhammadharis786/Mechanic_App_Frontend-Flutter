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
        backendType != 'APPOINTMENT_CANCELLED';
  }

  static void clear() {
    current.value = null;
  }
}
