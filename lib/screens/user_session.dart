import 'dart:convert';

class UserSession {
  // Singleton instance
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  String? email;
  String? password;

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
}
