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
    email = id;
    password = pass;
    userType = type;

    print("💾 Saving session... ID: $id, Type: $type");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', id);
    await prefs.setString('password', pass);
    await prefs.setString('userType', type);
  }

  // Load Credentials (Splash screen par call karein)
  Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('email') && prefs.containsKey('password')) {
      email = prefs.getString('email');
      password = prefs.getString('password');
      userType = prefs.getString('userType') ?? 'USER';
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
      final response = await http.post(
        Uri.parse("http://localhost:8080/api/logout"),
        headers: getAuthHeader(),
      );

      if (response.statusCode == 200) {
        print("✅ Server-side session cleared");
      } else {
        print("⚠️ Server logout returned: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error calling logout API: $e");
    } finally {
      // 2. Client-side clear (Hamesha execute hoga chahe API call fail ho jaye)
      email = null;
      password = null;
      userType = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print("✅ Client-side credentials & Storage cleared");
    }
  }
}
