import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:pinput/pinput.dart';
import 'mechanic_new_password_screen.dart';

class MechanicForgotOtpScreen extends StatefulWidget {
  final String phoneNumber;

  const MechanicForgotOtpScreen({super.key, required this.phoneNumber});

  @override
  State<MechanicForgotOtpScreen> createState() => _MechanicForgotOtpScreenState();
}

class _MechanicForgotOtpScreenState extends State<MechanicForgotOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  final Color primaryColor = const Color(0xFFFB3300);

  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();
    if (token.length < 6) return;

    setState(() => _isLoading = true);

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/forget/verifytoken");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": token,
          "phonenumber": widget.phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MechanicNewPasswordScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server error. Please try again."), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: GoogleFonts.poppins(
        fontSize: 20,
        color: isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade300),
      ),
    );

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              "Verify OTP",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Sent to ${widget.phoneNumber}",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),
            const SizedBox(height: 50),
            Center(
              child: Pinput(
                length: 6,
                controller: _otpController,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: primaryColor, width: 2),
                  ),
                ),
                onCompleted: (_) => _verifyOtp(),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Verify Code",
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
    );
  }
}
