import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_session.dart'; 
import 'otpScreenforgotpassword.dart';
import 'r_screen.dart';
import 'enable_loc.dart';
import 'phone_otp_screen.dart';
import '../services/phone_auth_service.dart';

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  bool isValid = false;
  bool isLoading = false; 
  bool isForgotLoading = false; 
  
  // Toggle: true = Email, false = Phone
  bool isEmailMode = true;
  String _selectedCountryCode = '+92';
  
  final Color kButtonColor = const Color(0xFFFB3300);

  final List<Map<String, String>> _countryCodes = [
    {'code': '+92', 'country': 'Pakistan'},
    {'code': '+91', 'country': 'India'},
    {'code': '+1', 'country': 'USA'},
    {'code': '+44', 'country': 'UK'},
    {'code': '+971', 'country': 'UAE'},
  ];

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInputs);
    _passwordController.addListener(_validateInputs);
    _phoneController.addListener(_validateInputs);
  }

  void _validateInputs() {
    if (isEmailMode) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final emailValid = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$").hasMatch(email);
      setState(() {
        isValid = emailValid && password.length >= 8;
      });
    } else {
      final phone = _phoneController.text.trim();
      setState(() {
        isValid = phone.length >= 10;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------- LOGIN WITH EMAIL ---------------- //
  void _loginWithEmail() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/login");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        UserSession().email = email;
        UserSession().password = password;
        
        // Save Session
        await UserSession().saveSession(email, password, 'USER');

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

  // ---------------- LOGIN WITH PHONE ---------------- //
  void _loginWithPhone() async {
    final phoneNumber = '$_selectedCountryCode${_phoneController.text.trim()}';
    
    setState(() => isLoading = true);

    await _phoneAuthService.sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        setState(() => isLoading = false);
        _showSnackBar('OTP bhej diya gaya! 📱', Colors.green);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhoneOtpScreen(
              phoneNumber: phoneNumber,
              verificationId: verificationId,
            ),
          ),
        );
      },
      onError: (error) {
        setState(() => isLoading = false);
        _showSnackBar(error, Colors.red);
      },
      onAutoVerified: (credential) async {
        setState(() => isLoading = false);
        final result = await _phoneAuthService.signInWithCredential(
          credential: credential,
          onError: (error) => _showSnackBar(error, Colors.red),
        );
        if (result != null) {
          _showSnackBar('Auto-verified! ✅', Colors.green);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EnableLocationScreen()),
          );
        }
      },
    );
  }

  // ---------------- FORGOT PASSWORD ---------------- //
  void _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar("Please enter your email first", Colors.orange);
      return;
    }

    setState(() => isForgotLoading = true);

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/forgot");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
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
              Text(
                isEmailMode 
                  ? "Login with your email and password"
                  : "Login with your phone number",
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54)
              ),
              const SizedBox(height: 30),

              // ============ EMAIL / PHONE TOGGLE ============
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isEmailMode = true;
                            _validateInputs();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isEmailMode ? kButtonColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.email_outlined, 
                                color: isEmailMode ? Colors.white : Colors.black54, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Email",
                                style: GoogleFonts.poppins(
                                  color: isEmailMode ? Colors.white : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isEmailMode = false;
                            _validateInputs();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: !isEmailMode ? kButtonColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.phone_android, 
                                color: !isEmailMode ? Colors.white : Colors.black54, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Phone",
                                style: GoogleFonts.poppins(
                                  color: !isEmailMode ? Colors.white : Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              if (isEmailMode) ...[
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
              ] else ...[
                 // PHONE FIELD
                Text("Phone Number", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: kButtonColor, width: 1.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountryCode,
                          items: _countryCodes.map((c) {
                            return DropdownMenuItem(
                              value: c['code'],
                              child: Text(c['code']!, style: GoogleFonts.poppins(fontSize: 15)),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedCountryCode = v!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: GoogleFonts.poppins(),
                        decoration: _inputDecoration("3001234567"),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 30),

              // LOGIN BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (isValid && !isLoading) 
                    ? (isEmailMode ? _loginWithEmail : _loginWithPhone) 
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? const Color(0xFFFB3300) : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEmailMode ? "Login" : "Send OTP", 
                          style: GoogleFonts.poppins(fontSize: 17, color: Colors.white)
                        ),
                ),
              ),

              const SizedBox(height: 15),

              // FORGOT PASSWORD (Only for Email)
              if (isEmailMode)
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

              // REGISTER LINK
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
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
