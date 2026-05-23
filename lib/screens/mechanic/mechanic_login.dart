import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mech_app/screens/mechanic/mechanic_register_phone.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'mechanic_location_screen.dart';
import 'mechanic_under_review_screen.dart';
import '../authentication/user_session.dart';
import '../../services/fcm_notification_service.dart';

class MechanicLoginScreen extends StatefulWidget {
  const MechanicLoginScreen({super.key});

  @override
  State<MechanicLoginScreen> createState() => _MechanicLoginScreenState();
}

class _MechanicLoginScreenState extends State<MechanicLoginScreen> {
  static const Color primaryColor = Color(0xFFFB3300);

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isButtonEnabled = false;
  bool _isLoading = false;

  void _checkFields() {
    setState(() {
      _isButtonEnabled =
          phoneController.text.length >= 10 &&
          passwordController.text.length >= 8;
    });
  }

  Future<void> _onLogin() async {
    setState(() => _isLoading = true);

    final phone = '92${phoneController.text.trim()}';
    final password = passwordController.text.trim();

    try {
      final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/login",
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phonenumber': phone,
          'password': password,
          'loginAs': 'MECHANIC',
        }),
      );

      if (response.statusCode == 200) {
        // Parse user data if needed, for now just expecting success
        // final data = jsonDecode(response.body);

        // Save Mechanic Session
        await UserSession().saveSession(phone, password, 'MECHANIC');

        // Extract Mechanic ID from the login response and save to Session
        try {
          final data = jsonDecode(response.body);
          int? mechanicId;

          if (data is Map) {
            if (data.containsKey('id') && data['id'] != null) {
              // Convert to int in case the backend returns it as string unexpectedly
              mechanicId = int.tryParse(data['id'].toString());
            } else if (data.containsKey('userId') && data['userId'] != null) {
              mechanicId = int.tryParse(data['userId'].toString());
            }
          }

          if (mechanicId != null) {
            await UserSession().setUserId(mechanicId);
            debugPrint(
              "✅ Mechanic ID ($mechanicId) saved to UserSession during login.",
            );
          } else {
            debugPrint("⚠️ Mechanic ID not found in login response.");
          }
        } catch (e) {
          debugPrint("❌ Error parsing login response for ID: $e");
        }

        await FcmNotificationService.instance.syncTokenWithBackend();

        debugPrint("Login Success: ${response.body}");

        // --- ADMIN CHECK (Success case with message) ---
        if (response.body.toLowerCase().contains('admin')) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const MechanicUnderReviewScreen(),
              ),
            );
          }
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login Successful!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MechanicLocationScreen()),
          );
        }
      } else {
        // Parse backend error message
        String errorMessage = 'Login Failed';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map && responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else if (responseData is Map && responseData.containsKey('error')) {
            errorMessage = responseData['error'];
          } else if (responseData is String) {
            errorMessage = responseData;
          }
        } catch (e) {
          // If parsing fails, use response body as is (but keep it clean)
          errorMessage = response.body.isNotEmpty && response.body.length < 100
              ? response.body
              : 'Login failed. Please check your credentials.';
        }

        debugPrint("Login Failed: ${response.body}");

        // --- ADMIN CHECK ---
        if (response.body.toLowerCase().contains('admin')) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const MechanicUnderReviewScreen(),
              ),
            );
          }
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              Text(
                "Welcome Back 👋",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                "Login with your phone number and password",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey,
                ),
              ),

              const SizedBox(height: 30),

              /// Phone Number
              Text(
                "Phone Number",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                onChanged: (_) => _checkFields(),
                decoration: InputDecoration(
                  hintText: "3XXXXXXXXX",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.grey[900]
                      : const Color(0xFFF3F3F3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      "92",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[800]! : primaryColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// Password
              Text(
                "Password",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                onChanged: (_) => _checkFields(),
                decoration: InputDecoration(
                  hintText: "Min 8 characters",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.grey[900]
                      : const Color(0xFFF3F3F3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[800]! : primaryColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: primaryColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// Login Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isButtonEnabled && !_isLoading)
                      ? _onLogin
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isButtonEnabled
                        ? primaryColor
                        : Colors.grey.shade300,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Login",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // forgot password screen later
                  },
                  child: Text(
                    "Forgot Password?",
                    style: GoogleFonts.poppins(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 50),

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MechanicRegisterPhoneScreen(),
                          ),
                        );
                      },
                      child: Text(
                        "Register",
                        style: GoogleFonts.poppins(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
