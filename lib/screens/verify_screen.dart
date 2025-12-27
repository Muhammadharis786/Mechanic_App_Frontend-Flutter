import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_session.dart'; // Ensure this file exists
import 'otpScreenforgotpassword.dart';
import 'r_screen.dart';
import 'enable_loc.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key} );

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool isValid = false;
  bool isLoading = false; 
  bool isForgotLoading = false; // Loading for forgot password

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInputs);
    _passwordController.addListener(_validateInputs);
  }

  void _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final emailValid = RegExp(
      r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
    ).hasMatch(email);

    setState(() {
      isValid = emailValid && password.length >= 8;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------- LOGIN ---------------- //
  void _login() async {
    if (isLoading) return;

    setState(() {
      isLoading = true; 
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/login" );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password} ),
      );

      if (response.statusCode == 200) {
        // 🔐 SAVE CREDENTIALS TO SESSION
        UserSession().email = email;
        UserSession().password = password;

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EnableLocationScreen()),
        );
      } else {
        _showSnackBar(response.body, Colors.red);
      }
    } catch (_) {
      _showSnackBar("Server not reachable ❌", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------- FORGOT PASSWORD ---------------- //
  void _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar("Please enter your email first", Colors.orange);
      return;
    }

    setState(() => isForgotLoading = true);

    final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/forgot" );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email} ),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpScreen(email: email)),
        );
      } else {
        _showSnackBar(response.body, Colors.red);
      }
    } catch (_) {
      _showSnackBar("Server not reachable ❌", Colors.red);
    } finally {
      if (mounted) setState(() => isForgotLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome Back 👋",
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text("Login with your email and password",
                  style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54)),
              const SizedBox(height: 50),

              // EMAIL
              Text("Email", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration("example@gmail.com"),
              ),

              const SizedBox(height: 22),

              // PASSWORD
              Text("Password", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: _inputDecoration("Min 8 characters"),
              ),

              const SizedBox(height: 30),

              // LOGIN BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (isValid && !isLoading) ? _login : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFB3300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Login", style: GoogleFonts.poppins(fontSize: 17, color: Colors.white)),
                ),
              ),

              const SizedBox(height: 15),

              // FORGOT PASSWORD WITH LOADING
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: isForgotLoading ? null : _forgotPassword,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isForgotLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFB3300)),
                        ),
                      if (isForgotLoading) const SizedBox(width: 8),
                      Text(
                        isForgotLoading ? "Forgetting password..." : "Forgot Password?",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFFB3300),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // REGISTER
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ", style: GoogleFonts.poppins(fontSize: 14)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: Text("Register",
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFFB3300))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFB3300), width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFB3300), width: 2),
      ),
    );
  }
}
