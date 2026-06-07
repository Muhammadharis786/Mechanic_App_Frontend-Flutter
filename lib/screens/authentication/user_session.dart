import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class UserSession {
  // Singleton instance
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? email;
  String? password;

  String? userType; // 'USER' or 'MECHANIC'
  int? userId;
  double? latitude;
  double? longitude;
  String? locationName; // ✅ FIX: locationName property add ki

  // Cache for Dual Login
  String? _cachedUserEmail;
  String? _cachedUserPassword;

  String? _cachedMechPhone;
  String? _cachedMechPassword;

  Map<String, String> getAuthHeader() {
    if (email == null || password == null) return {};
    String credentials = '$email;${userType ?? "USER"}';
    String basicAuth =
        'Basic ' + base64Encode(utf8.encode('$credentials:$password'));
    return {
      'Authorization': basicAuth,
      'Content-Type': 'application/json',
    };
  }

  Future<void> saveSession(String id, String pass, String type) async {
    final prefs = await SharedPreferences.getInstance();
    email = id;
    password = pass;
    userType = type;

    print("💾 Saving session... ID: $id, Type: $type");
    await prefs.setString('email', id);
    await prefs.setString('password', pass);
    await prefs.setString('userType', type);

    if (type == 'USER') {
      _cachedUserEmail = id;
      _cachedUserPassword = pass;
      await prefs.setString('cached_user_email', id);
      await prefs.setString('cached_user_pass', pass);
    } else if (type == 'MECHANIC') {
      _cachedMechPhone = id;
      _cachedMechPassword = pass;
      await prefs.setString('cached_mech_id', id);
      await prefs.setString('cached_mech_pass', pass);
    }
  }

  Future<void> saveLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    latitude = lat;
    longitude = lng;
    await prefs.setDouble('user_lat', lat);
    await prefs.setDouble('user_lng', lng);
    print("📍 Location persisted: $lat, $lng");
  }

  Future<void> setUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    userId = id;
    await prefs.setInt('userId', id);
  }

  Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('email') && prefs.containsKey('password')) {
      email = prefs.getString('email');
      password = prefs.getString('password');
      userType = prefs.getString('userType') ?? 'USER';

      _cachedUserEmail = prefs.getString('cached_user_email');
      _cachedUserPassword = prefs.getString('cached_user_pass');
      _cachedMechPhone = prefs.getString('cached_mech_id');
      _cachedMechPassword = prefs.getString('cached_mech_pass');

      userId = prefs.getInt('userId');
      latitude = prefs.getDouble('user_lat');
      longitude = prefs.getDouble('user_lng');
      locationName = prefs.getString('location_name'); // ✅ FIX: load karo

      print(
          "🔄 Session Loaded: $email as $userType (ID: $userId, Lat: $latitude, Lng: $longitude)");
      return true;
    }
    print("⚠️ No session found.");
    return false;
  }

  Future<void> logout() async {
    try {
      try {
        await http
            .post(
              Uri.parse("http://localhost:8080/api/logout"),
              headers: getAuthHeader(),
            )
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        // Ignore network errors for logout
      }
    } catch (e) {
      print("❌ Error calling logout API: $e");
    } finally {
      email = null;
      password = null;
      userType = null;
      userId = null;
      latitude = null;
      longitude = null;
      locationName = null; // ✅ FIX: logout par clear karo

      _cachedUserEmail = null;
      _cachedUserPassword = null;
      _cachedMechPhone = null;
      _cachedMechPassword = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print("✅ Client-side credentials & Storage cleared");
    }
  }

  Future<bool> trySwitchTo(String targetType) async {
    final prefs = await SharedPreferences.getInstance();

    if (targetType == 'USER') {
      if (_cachedUserEmail != null && _cachedUserPassword != null) {
        email = _cachedUserEmail;
        password = _cachedUserPassword;
        userType = 'USER';

        await prefs.setString('email', email!);
        await prefs.setString('password', password!);
        await prefs.setString('userType', 'USER');
        return true;
      }
    } else if (targetType == 'MECHANIC') {
      if (_cachedMechPhone != null && _cachedMechPassword != null) {
        email = _cachedMechPhone;
        password = _cachedMechPassword;
        userType = 'MECHANIC';

        await prefs.setString('email', email!);
        await prefs.setString('password', password!);
        await prefs.setString('userType', 'MECHANIC');
        return true;
      }
    }
    return false;
  }
}