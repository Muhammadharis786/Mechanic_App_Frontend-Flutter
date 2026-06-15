import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:pinput/pinput.dart';

import 'mechanic_kyc_screen.dart';
import 'mechanic_registration_screen.dart';

class MechanicOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;

  const MechanicOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
  });

  @override
  State<MechanicOtpScreen> createState() => _MechanicOtpScreenState();
}

class _MechanicOtpScreenState extends State<MechanicOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isOtpComplete = false;

  // Timer logic
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;

  final Color primaryColor = const Color(0xFFFB3300);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_isOtpComplete || _otpController.text.length < 6) {
      _showSnack('Please enter a complete 6-digit OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/register/verify");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phonenumber": widget.phoneNumber,
          "token": _otpController.text.trim(),
        }),
      );

      final responseBody = response.body;

      if (response.statusCode == 200 || response.statusCode == 201) {
        bool isKycDone = false;
        String successMsg = 'OTP Verified successfully!';

        try {
          final data = jsonDecode(responseBody);
          if (data is Map) {
            isKycDone = data['iskyc'] == true;
            successMsg = data['message'] ?? successMsg;
          }
        } catch (e) {
          if (responseBody.isNotEmpty && !responseBody.startsWith('{')) {
            successMsg = responseBody;
          }
        }

        _showSnack(successMsg, isError: false);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => isKycDone
                  ? MechanicRegistrationScreen(
                      phoneNumber: widget.phoneNumber,
                      password: widget.password,
                    )
                  : MechanicKycScreen(
                      phoneNumber: widget.phoneNumber,
                      password: widget.password,
                    ),
            ),
          );
        }
      } else {
        _handleApiError(responseBody, 'OTP verification failed');
      }
    } catch (e) {
      _showSnack('Server Error! Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/registerwithotp");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phonenumber": widget.phoneNumber,
          "password": widget.password,
        }),
      );

      final responseBody = response.body;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnack('OTP Resent to ${widget.phoneNumber}', isError: false);
        _startTimer(); // Restart timer
      } else {
        _handleApiError(responseBody, 'Failed to resend OTP');
      }
    } catch (e) {
      _showSnack('Server Error! Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleApiError(String responseBody, String defaultMsg) {
    String errorMessage = defaultMsg;
    try {
      final data = jsonDecode(responseBody);
      if (data is Map && data.containsKey('message')) {
        errorMessage = data['message'];
      } else if (data is Map && data.containsKey('error')) {
        errorMessage = data['error'];
      } else {
        errorMessage = responseBody;
      }
    } catch (_) {
      errorMessage = responseBody.isNotEmpty
          ? responseBody
          : defaultMsg;
    }
    _showSnack(errorMessage, isError: true);
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: GoogleFonts.poppins(
        fontSize: 20,
        color: theme.textTheme.bodyLarge?.color,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey.shade50,
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Verification",
          style: GoogleFonts.poppins(color: theme.textTheme.titleLarge?.color),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(
                  "OTP Verification",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter the 6-digit code sent to\n${widget.phoneNumber}",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Pinput
                Pinput(
                  length: 6,
                  controller: _otpController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: primaryColor, width: 2),
                    ),
                  ),
                  submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: primaryColor),
                    ),
                  ),
                  onCompleted: (pin) {
                    setState(() {
                      _isOtpComplete = true;
                    });
                  },
                  onChanged: (value) {
                    if (value.length < 6) {
                      setState(() {
                        _isOtpComplete = false;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 40),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_isOtpComplete) ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: primaryColor.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            "Verify OTP",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                // Resend Timer & Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive code? ",
                      style: GoogleFonts.poppins(
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    _canResend
                        ? GestureDetector(
                            onTap: _isLoading ? null : _resendOtp,
                            child: Text(
                              "Resend",
                              style: GoogleFonts.poppins(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : Text(
                            "00:${_secondsRemaining.toString().padLeft(2, '0')}",
                            style: GoogleFonts.poppins(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
