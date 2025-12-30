import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'otp_screen.dart';
import 'phone_otp_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/phone_auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailC = TextEditingController();
  final TextEditingController _passC = TextEditingController();
  final TextEditingController _phoneC = TextEditingController();
  
  final PhoneAuthService _phoneAuthService = PhoneAuthService();

  bool isValid = false;
  bool hidePassword = true;
  bool isLoading = false;
  
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
    _emailC.addListener(_validate);
    _passC.addListener(_validate);
    _phoneC.addListener(_validate);
  }

  void _validate() {
    if (isEmailMode) {
      final email = _emailC.text.trim();
      final pass = _passC.text.trim();
      bool validEmail = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
          .hasMatch(email);
      bool validPass = pass.length >= 8;
      setState(() {
        isValid = validEmail && validPass;
      });
    } else {
      final phone = _phoneC.text.trim();
      setState(() {
        isValid = phone.length >= 10;
      });
    }
  }

  // Email Registration
  Future<void> _registerWithEmail() async {
    final email = _emailC.text.trim();
    final password = _passC.text.trim();

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/register");

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(email: email, password: password),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server not reachable ❌"), backgroundColor: Colors.red),
      );
    }
  }

  // Phone Registration
  Future<void> _registerWithPhone() async {
    final phoneNumber = '$_selectedCountryCode${_phoneC.text.trim()}';
    
    setState(() => isLoading = true);

    await _phoneAuthService.sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP bhej diya gaya! 📱'), backgroundColor: Colors.green),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      },
      onAutoVerified: (credential) async {
        setState(() => isLoading = false);
        final result = await _phoneAuthService.signInWithCredential(
          credential: credential,
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          },
        );
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Auto-verified! ✅'), backgroundColor: Colors.green),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  void _onRegister() {
    if (isEmailMode) {
      _registerWithEmail();
    } else {
      _registerWithPhone();
    }
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
              Text(
                "Register Account",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEmailMode 
                  ? "Register with your email and password"
                  : "Register with your phone number",
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54),
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
                            _validate();
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
                            _validate();
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

              // ============ CONDITIONAL INPUT FIELDS ============
              if (isEmailMode) ...[
                // EMAIL FIELD
                Text("Email", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailC,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.poppins(),
                  decoration: _inputDecoration("example@gmail.com"),
                ),
                const SizedBox(height: 20),

                // PASSWORD FIELD
                Text("Password", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 6),
                TextField(
                  controller: _passC,
                  obscureText: hidePassword,
                  style: GoogleFonts.poppins(),
                  decoration: _inputDecoration("Minimum 8 characters").copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(hidePassword ? Icons.visibility_off : Icons.visibility, color: Colors.black54),
                      onPressed: () => setState(() => hidePassword = !hidePassword),
                    ),
                  ),
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
                        controller: _phoneC,
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
              const SizedBox(height: 40),

              // ============ REGISTER BUTTON ============
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isValid && !isLoading ? _onRegister : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? kButtonColor : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEmailMode ? "Send OTP" : "Send OTP 📱",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
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
