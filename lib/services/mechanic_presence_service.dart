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
      if (enabled) {
        final mechanicId = UserSession().userId;
        final authHeader = UserSession().getAuthHeader()['Authorization'];
        await _channel.invokeMethod('startPresenceGuard', {
          if (mechanicId != null) 'mechanicId': mechanicId,
          if (authHeader != null) 'authHeader': authHeader,
        });
      } else {
        await _channel.invokeMethod('stopPresenceGuard');
      }
    } catch (e) {
      debugPrint('MechanicPresenceService guard error: $e');
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
    final headers = UserSession().getAuthHeader();
    if (headers.isEmpty) {
      return false;
    }

    try {
      final url = Uri.parse(_isActiveUrl);
      final body = jsonEncode({'isonline': value ? 'true' : 'false'});

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

      if (response.statusCode == 200 || response.statusCode == 201) {
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
      }
    } catch (e) {
      debugPrint('MechanicPresenceService updateOnlineStatus error: $e');
    }
    return false;
  }
}
