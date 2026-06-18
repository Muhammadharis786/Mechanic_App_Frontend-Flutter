import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'mechanic_login.dart';

class MechanicNewPasswordScreen extends StatefulWidget {
  final String phoneNumber;

  const MechanicNewPasswordScreen({super.key, required this.phoneNumber});

  @override
  State<MechanicNewPasswordScreen> createState() => _MechanicNewPasswordScreenState();
}

class _MechanicNewPasswordScreenState extends State<MechanicNewPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final Color primaryColor = const Color(0xFFFB3300);

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (password.length < 8) {
      _showSnack("Password must be at least 8 characters", true);
      return;
    }
    if (password != confirm) {
      _showSnack("Passwords do not match", true);
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/forget/newPassword");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phonenumber": widget.phoneNumber,
          "password": password,
          "loginAs": "MECHANIC",
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        _showSnack("Password updated successfully!", false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MechanicLoginScreen()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        _showSnack(response.body, true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack("Server error. Please try again.", true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFFB3300),
            size: 18,
          ),
          splashRadius: 20,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                "New Password",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "New Password",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Enter new password",
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : const Color(0xFFF3F3F3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: primaryColor),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Confirm Password",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Repeat new password",
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : const Color(0xFFF3F3F3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Update Password",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
