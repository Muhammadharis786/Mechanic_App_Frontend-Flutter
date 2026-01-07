import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mech_app/screens/mechanic/mechanic_registration_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'mechanic_dashboard.dart';
import '../authentication/user_session.dart';

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

    final phone = '+92${phoneController.text.trim()}';
    final password = passwordController.text.trim();

    try {
      final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/login");
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phonenumber': phone,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        // Parse user data if needed, for now just expecting success
        // final data = jsonDecode(response.body); 

        // Save Mechanic Session
        await UserSession().saveSession(phone, password, 'MECHANIC');

        debugPrint("Login Success: ${response.body}");

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login Successful!'), backgroundColor: Colors.green),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
          );
        }
      } else {
        debugPrint("Login Failed: ${response.body}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login Failed (${response.statusCode}): ${response.body}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
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
    return Scaffold(
      backgroundColor: Colors.white,
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
                ),
              ),

              const SizedBox(height: 6),

              Text(
                "Login with your phone number and password",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 30),

              /// Phone Number
              Text(
                "Phone Number",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                onChanged: (_) => _checkFields(),
                decoration: InputDecoration(
                  hintText: "3XXXXXXXXX",
                  filled: true,
                  fillColor: const Color(0xFFF3F3F3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      "+92",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: primaryColor),
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
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: passwordController,
                obscureText: _obscurePassword,
                onChanged: (_) => _checkFields(),
                decoration: InputDecoration(
                  hintText: "Min 8 characters",
                  filled: true,
                  fillColor: const Color(0xFFF3F3F3),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
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
                    borderSide: const BorderSide(color: primaryColor),
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
                  onPressed: (_isButtonEnabled && !_isLoading) ? _onLogin : null,
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
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
                      style: GoogleFonts.poppins(color: Colors.black),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const MechanicRegistrationScreen(),
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
