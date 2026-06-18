import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'authentication/user_session.dart';
import 'otpScreenforgotpassword.dart';
import 'r_screen.dart';
import 'enable_loc.dart';
import '../services/fcm_notification_service.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool isValid = false;
  bool isLoading = false;
  bool isForgotLoading = false;
  bool _obscurePassword = true;

  final Color kButtonColor = const Color(0xFFFB3300);

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validateInputs);
    _passwordController.addListener(_validateInputs);
  }

  void _validateInputs() {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    setState(() {
      isValid = phone.length >= 10 && password.length >= 6;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------- LOGIN WITH UNIFIED API ---------------- //
  void _login() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    final phone = '92${_phoneController.text.trim()}';
    final password = _passwordController.text.trim();

    final url = Uri.parse(
      "https://mechanicapp-service-621632382478.asia-south1.run.app/api/login",
    );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phonenumber": phone,
          "password": password,
          "loginAs": "USER",
        }),
      );

      if (response.statusCode == 200) {
        // Save Session with phone number
        await UserSession().saveSession(phone, password, 'USER');
        await FcmNotificationService.instance.syncTokenWithBackend();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EnableLocationScreen()),
        );
      } else {
        String errorMessage = 'Login Failed';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map && responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else if (responseData is String) {
            errorMessage = responseData;
          }
        } catch (e) {
          errorMessage = response.body.isNotEmpty && response.body.length < 100
              ? response.body
              : 'Login failed. Please check your credentials.';
        }
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (_) {
      _showSnackBar("Server not reachable ❌", Colors.red);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------- FORGOT PASSWORD ---------------- //
  void _forgotPassword() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar("Please enter your WhatsApp number first", Colors.orange);
      return;
    }

    setState(() => isForgotLoading = true);

    final url = Uri.parse(
      "https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/forgot",
    );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phonenumber": '92$phone'}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpScreen(email: '92$phone')),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
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
              // Back button
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFFFB3300),
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(4),
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Welcome Back!",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              Text(
                "Login with your WhatsApp number and password",
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 30),

              // WhatsApp Number
              Text(
                "WhatsApp Number",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: GoogleFonts.poppins(),
                decoration: _inputDecoration("3XXXXXXXXX").copyWith(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      "+92",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // PASSWORD
              Text(
                "Password",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: GoogleFonts.poppins(),
                decoration: _inputDecoration("Min 6 characters").copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: kButtonColor,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // LOGIN BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (isValid && !isLoading) ? _login : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid
                        ? kButtonColor
                        : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Login",
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 15),

              // FORGOT PASSWORD
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFB3300),
                          ),
                        ),
                      if (isForgotLoading) const SizedBox(width: 8),
                      Text(
                        isForgotLoading ? "Sending..." : "Forgot Password?",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: kButtonColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // REGISTER LINK
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: Text(
                      "Register",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kButtonColor,
                      ),
                    ),
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
      hintStyle: GoogleFonts.poppins(color: Colors.black45),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: kButtonColor, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: kButtonColor, width: 2),
      ),
    );
  }
}