import 'package:firebase_auth/firebase_auth.dart';

FirebaseAuth _auth = FirebaseAuth.instance;

// OTP bhejne ka function
Future<void> sendOTP(String phoneNumber) async {
  await _auth.verifyPhoneNumber(
    phoneNumber: phoneNumber, // Format: +923001234567
    verificationCompleted: (PhoneAuthCredential credential) async {
      // Android auto-verification
      await _auth.signInWithCredential(credential);
    },
    verificationFailed: (FirebaseAuthException e) {
      print('Error: ${e.message}');
    },
    codeSent: (String verificationId, int? resendToken) {
      // OTP bhej diya gaya - verificationId save karein
    },
    codeAutoRetrievalTimeout: (String verificationId) {},
  );
}

// OTP verify karne ka function
Future<void> verifyOTP(String verificationId, String smsCode) async {
  PhoneAuthCredential credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: smsCode,
  );
  await _auth.signInWithCredential(credential);
}