import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/authentication/user_session.dart';
import 'mechanic_live_location_service.dart';

class MechanicPresenceService {
  MechanicPresenceService._();

  static final MechanicPresenceService instance = MechanicPresenceService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.mech_app/mechanic_presence');
  static const String _onlinePrefKey = 'mechanic_is_online';
  static const String _isActiveUrl =
      'https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/isactive';

  Future<void> setLocalOnlineFlag(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlinePrefKey, value);
  }

  Future<bool> localOnlineFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onlinePrefKey) ?? false;
  }

  Future<void> _setAndroidPresenceGuard(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod(
        enabled ? 'startPresenceGuard' : 'stopPresenceGuard',
      );
    } catch (e) {
      debugPrint('Mechanic presence guard error: $e');
    }
  }

  Future<void> ensureAndroidPresenceGuard() async {
    if (await localOnlineFlag()) {
      await _setAndroidPresenceGuard(true);
    }
  }

  Future<bool> updateOnlineStatus(
    bool value, {
    String? activeRequestId,
  }) async {
    debugPrint('🌐 API CALL START: updateOnlineStatus(value=$value, activeRequestId=$activeRequestId)');
    
    final headers = UserSession().getAuthHeader();
    if (headers.isEmpty) {
      debugPrint('❌ API CALL FAILED: No auth headers');
      return false;
    }

    try {
      final url = Uri.parse(_isActiveUrl);
      final body = jsonEncode({'isonline': value ? 'true' : 'false'});
      
      debugPrint('🌐 API CALL: POST $_isActiveUrl');
      debugPrint('🌐 API BODY: $body');
      
      final response = await http
          .post(
            url,
            headers: {
              ...headers,
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 8));

      debugPrint('🌐 API RESPONSE: Status=${response.statusCode}, Body=${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ API SUCCESS: Status updated to $value');
        await setLocalOnlineFlag(value);
        if (value) {
          await _setAndroidPresenceGuard(true);
          await MechanicLiveLocationService.instance.start(
            requestId: activeRequestId,
          );
        } else {
          await _setAndroidPresenceGuard(false);
          await MechanicLiveLocationService.instance.stop();
        }
        return true;
      } else {
        debugPrint('❌ API FAILED: Unexpected status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ API ERROR: $e');
    }
    return false;
  }
}
