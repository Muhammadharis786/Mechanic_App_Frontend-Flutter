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
  
  // Cache for Dual Login
  String? _cachedUserEmail;
  String? _cachedUserPassword;
  
  String? _cachedMechPhone;
  String? _cachedMechPassword;
  
  // Basic Auth Header generate karne ke liye function
  Map<String, String> getAuthHeader() {
    if (email == null || password == null) return {};
    
    // Email:Password ko Base64 mein convert karna
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$email:$password'));
    return {
      'Authorization': basicAuth,
      'Content-Type': 'application/json',
    };
  }

  // Save Credentials (Login ke waqt call karein)
  Future<void> saveSession(String id, String pass, String type) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Set Active Session
    email = id;
    password = pass;
    userType = type;

    print("💾 Saving session... ID: $id, Type: $type");
    await prefs.setString('email', id);
    await prefs.setString('password', pass);
    await prefs.setString('userType', type);

    // 2. Cache Specific Session (Dual Login Support)
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

  // Load Credentials (Splash screen par call karein)
  Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('email') && prefs.containsKey('password')) {
      email = prefs.getString('email');
      password = prefs.getString('password');
      userType = prefs.getString('userType') ?? 'USER';
      
      // Load Caches
      _cachedUserEmail = prefs.getString('cached_user_email');
      _cachedUserPassword = prefs.getString('cached_user_pass');
      _cachedMechPhone = prefs.getString('cached_mech_id');
      _cachedMechPassword = prefs.getString('cached_mech_pass');

      print("🔄 Session Loaded: $email as $userType");
      return true;
    }
    print("⚠️ No session found.");
    return false;
  }

  // Logout function jo server aur client dono side se clear karega
  Future<void> logout() async {
    try {
      // 1. Server-side logout call (Spring Boot)
      // Note: Basic Auth header bhej rahe hain taake server ko pata chale kaun logout ho raha hai
      try {
        final response = await http.post(
          Uri.parse("http://localhost:8080/api/logout"),
          headers: getAuthHeader(),
        ).timeout(const Duration(seconds: 2)); // Short timeout for localhost
      } catch (e) {
        // Ignore network errors for logout
      }

    } catch (e) {
      print("❌ Error calling logout API: $e");
    } finally {
      // 2. Client-side clear (Hamesha execute hoga chahe API call fail ho jaye)
      email = null;
      password = null;
      userType = null;
      userId = null;
      
      // Clear caches too? 
      // Usually on explicit logout we want to clear EVERYTHING
      _cachedUserEmail = null;
      _cachedUserPassword = null;
      _cachedMechPhone = null;
      _cachedMechPassword = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print("✅ Client-side credentials & Storage cleared");
    }
  }

  // Switch Context Method
  Future<bool> trySwitchTo(String targetType) async {
    final prefs = await SharedPreferences.getInstance();

    if (targetType == 'USER') {
      if (_cachedUserEmail != null && _cachedUserPassword != null) {
        // Restore User Session
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
        // Restore Mechanic Session
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
