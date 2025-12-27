// otp_screen.dart file ke top par
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'verify_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String password;
 const OtpScreen({super.key, required this.email , required this.password});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  bool _isOtpComplete = false; 

  final Color kButtonColor = const Color(0xFFFB3300);

Future<void> _verifyOtp() async {
  if (_formKey.currentState!.validate()) {
    final otp = _otpController.text.trim();
    final email = widget.email;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Verifying OTP...")),
    );

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/verify/user/token");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "token": otp,
        }),
      );

      final body = response.body;  
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body),   
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const VerifyScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body),   
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // ignore: duplicate_ignore
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Server Error! Please try again."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


Future<void> _resendOtp() async {
  final email = widget.email;
  final password = widget.password;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Resending OTP...")),
  );

  final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/register");

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final body = response.body;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body),  // backend ka message
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error sending OTP! Try again."),
        backgroundColor: Colors.red,
      ),
    );
  }
}



  @override
  Widget build(BuildContext context) {
    // ... (rest of the build method is unchanged)
    // ... (Pinput, Buttons, etc. ka code jaisa hai waisa hi rahega)
    
    // Yahan aapke build method ka poora code aayega jaisa aapne pehle diya tha.
    // Ensure the onPressed property of ElevatedButton uses the updated _verifyOtp:
    // onPressed: _isOtpComplete ? _verifyOtp : null, 
    
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 55,
      textStyle: GoogleFonts.poppins(
        fontSize: 20,
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Account Verification',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Verification Code',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A 6-digit code has been sent to your registered number/email.',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 50),

            // ✅ Pinput
            Form(
              key: _formKey,
              child: Pinput(
                length: 6,
                controller: _otpController,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: kButtonColor, width: 2),
                  ),
                ),
                pinAnimationType: PinAnimationType.scale,
                keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (s) {
                  if (s == null || s.length < 6) {
                    return 'Enter the complete 6-digit code';
                  }
                  return null;
                },
                
                onCompleted: (pin) {
                  setState(() {
                    _isOtpComplete = true;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    _isOtpComplete = value.length == 6; 
                  });
                },
              ),
            ),

            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isOtpComplete ? _verifyOtp : null, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: kButtonColor,
                  foregroundColor: Colors.white, 
                  disabledBackgroundColor: kButtonColor.withOpacity(0.4), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Verify Code',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Resend Code Link
            Center(
              child: TextButton(
                onPressed: _resendOtp,
                child: Text(
                  'Didn\'t receive the code? Resend',
                  style: GoogleFonts.poppins(
                    color: kButtonColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600
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