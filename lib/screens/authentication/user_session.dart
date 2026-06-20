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
  
  int? _userId;
  int? get userId => _userId;
  set userId(int? value) {
    _userId = value;
    _saveNumericIdToCache(value);
  }

  double? latitude;
  double? longitude;
  String? locationName; // ✅ FIX: locationName property add ki

  // Cache for Dual Login
  String? _cachedUserEmail;
  String? _cachedUserPassword;
  int? _cachedUserId;

  String? _cachedMechPhone;
  String? _cachedMechPassword;
  int? _cachedMechId;

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

  Future<void> _saveNumericIdToCache(int? id) async {
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (userType == 'USER') {
      _cachedUserId = id;
      await prefs.setInt('cached_user_numeric_id', id);
    } else if (userType == 'MECHANIC') {
      _cachedMechId = id;
      await prefs.setInt('cached_mech_numeric_id', id);
    }
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

  Future<void> _loadCachedSwitchCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedUserEmail = prefs.getString('cached_user_email');
    _cachedUserPassword = prefs.getString('cached_user_pass');
    _cachedUserId = prefs.getInt('cached_user_numeric_id');
    _cachedMechPhone = prefs.getString('cached_mech_id');
    _cachedMechPassword = prefs.getString('cached_mech_pass');
    _cachedMechId = prefs.getInt('cached_mech_numeric_id');
  }

  Future<void> setUserId(int id) async {
    userId = id;
    final prefs = await SharedPreferences.getInstance();
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
      _cachedUserId = prefs.getInt('cached_user_numeric_id');
      _cachedMechPhone = prefs.getString('cached_mech_id');
      _cachedMechPassword = prefs.getString('cached_mech_pass');
      _cachedMechId = prefs.getInt('cached_mech_numeric_id');

      _userId = prefs.getInt('userId');
      latitude = prefs.getDouble('user_lat');
      longitude = prefs.getDouble('user_lng');
      locationName = prefs.getString('location_name'); // ✅ FIX: load karo

      print(
          "🔄 Session Loaded: $email as $userType (ID: $_userId, Lat: $latitude, Lng: $longitude)");
      return true;
    }
    print("⚠️ No session found.");
    return false;
  }

  Future<void> logout() async {
    final activeType = userType; // Store the active role before clearing
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
    } finally {
      final prefs = await SharedPreferences.getInstance();

      // 1. Clear memory fields for the active session
      email = null;
      password = null;
      userType = null;
      _userId = null;
      latitude = null;
      longitude = null;
      locationName = null;

      // 2. Clear role-specific persistent cache
      if (activeType == 'USER') {
        print("👤 Clearing USER specific cache...");
        _cachedUserEmail = null;
        _cachedUserPassword = null;
        _cachedUserId = null;
        await prefs.remove('cached_user_email');
        await prefs.remove('cached_user_pass');
        await prefs.remove('cached_user_numeric_id');
      } else if (activeType == 'MECHANIC') {
        print("🔧 Clearing MECHANIC specific cache...");
        _cachedMechPhone = null;
        _cachedMechPassword = null;
        _cachedMechId = null;
        await prefs.remove('cached_mech_id');
        await prefs.remove('cached_mech_pass');
        await prefs.remove('cached_mech_numeric_id');
      }

      // 3. Always clear the active session pointers in SharedPreferences
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.remove('userType');
      await prefs.remove('userId');
      await prefs.remove('user_lat');
      await prefs.remove('user_lng');
      await prefs.remove('location_name');

      print("✅ Logout complete for $activeType. Other role session preserved if it existed.");
    }
  }

  Future<bool> trySwitchTo(String targetType) async {
    final prefs = await SharedPreferences.getInstance();
    await _loadCachedSwitchCredentials();

    if (targetType == 'USER') {
      // ── Try cached USER credentials first ──
      if (_cachedUserEmail != null && _cachedUserPassword != null) {
        email = _cachedUserEmail;
        password = _cachedUserPassword;
        userType = 'USER';
        _userId = _cachedUserId;

        await prefs.setString('email', email!);
        await prefs.setString('password', password!);
        await prefs.setString('userType', 'USER');
        if (_userId != null) {
          await prefs.setInt('userId', _userId!);
        } else {
          await prefs.remove('userId');
        }
        return true;
      }
    } else if (targetType == 'MECHANIC') {
      // ── Try cached MECHANIC credentials first ──
      if (_cachedMechPhone != null && _cachedMechPassword != null) {
        email = _cachedMechPhone;
        password = _cachedMechPassword;
        userType = 'MECHANIC';
        _userId = _cachedMechId;

        await prefs.setString('email', email!);
        await prefs.setString('password', password!);
        await prefs.setString('userType', 'MECHANIC');
        if (_userId != null) {
          await prefs.setInt('userId', _userId!);
        } else {
          await prefs.remove('userId');
        }
        return true;
      }
      // No mechanic account → return false → show MechanicLoginScreen
    }

    return false;
  }
}