// Phone OTP Verification Screen - Firebase Phone Authentication
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../services/phone_auth_service.dart';

class PhoneOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const PhoneOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final PhoneAuthService _authService = PhoneAuthService();

  bool _isLoading = false;
  bool _isOtpComplete = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  late String _currentVerificationId;

  final Color kButtonColor = const Color(0xFFFB3300);

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() => _resendCountdown--);
        _startResendTimer();
      }
    });
  }

  Future<void> _verifyOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final result = await _authService.verifyOTP(
        verificationId: _currentVerificationId,
        smsCode: _otpController.text.trim(),
        onError: (error) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        },
      );

      if (result != null) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verify ho gaya! ✅'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to first screen or home
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isResending = true;
      _resendCountdown = 60;
    });

    await _authService.sendOTP(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (verificationId) {
        setState(() {
          _isResending = false;
          _currentVerificationId = verificationId;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Naya OTP bhej diya gaya! 📱'),
            backgroundColor: Colors.green,
          ),
        );
        
        _startResendTimer();
      },
      onError: (error) {
        setState(() => _isResending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
          ),
        );
      },
      onAutoVerified: (credential) async {
        setState(() => _isResending = false);
        
        final result = await _authService.signInWithCredential(
          credential: credential,
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          },
        );

        if (result != null) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 58,
      textStyle: GoogleFonts.poppins(
        fontSize: 22,
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: kButtonColor, width: 2),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: Colors.red, width: 2),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'OTP Verification',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // OTP Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: kButtonColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sms_outlined,
                    size: 50,
                    color: kButtonColor,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Title
                Text(
                  'Verification Code',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Subtitle with phone number
                Text(
                  'Hum ne ${_maskPhoneNumber(widget.phoneNumber)} par code bheja hai',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // OTP Input (Pinput)
                Pinput(
                  length: 6,
                  controller: _otpController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  errorPinTheme: errorPinTheme,
                  pinAnimationType: PinAnimationType.scale,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return '6-digit code dalein';
                    }
                    return null;
                  },
                  onCompleted: (pin) {
                    setState(() => _isOtpComplete = true);
                  },
                  onChanged: (value) {
                    setState(() => _isOtpComplete = value.length == 6);
                  },
                ),
                
                const SizedBox(height: 50),
                
                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (_isOtpComplete && !_isLoading) ? _verifyOTP : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kButtonColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: kButtonColor.withOpacity(0.4),
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
                            'Verify Karein',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Resend OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Code nahi mila? ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (_resendCountdown > 0)
                      Text(
                        '${_resendCountdown}s mein dobara bhejein',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _isResending ? null : _resendOTP,
                        child: _isResending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Dobara Bhejein',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: kButtonColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Change Number Link
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Number badlein',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Phone number mask karne ke liye (privacy)
  String _maskPhoneNumber(String phone) {
    if (phone.length > 6) {
      return '${phone.substring(0, phone.length - 4)}****';
    }
    return phone;
  }
}
