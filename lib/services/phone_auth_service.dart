// Firebase Phone Authentication Service
// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _verificationId;
  int? _resendToken;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  /// Phone number par OTP bhejne ka function
  /// [phoneNumber] format hona chahiye: +923001234567
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        
        // Jab Android automatically OTP verify kar le
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('Auto verification completed');
          onAutoVerified(credential);
        },
        
        // Jab koi error aaye
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.message}');
          String errorMessage = _getErrorMessage(e.code);
          onError(errorMessage);
        },
        
        // Jab OTP successfully send ho jaye
        codeSent: (String verificationId, int? resendToken) {
          print('OTP sent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        
        // Jab auto-retrieval ka time khatam ho jaye
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto retrieval timeout');
          _verificationId = verificationId;
        },
        
        // Resend ke liye token
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      print('Send OTP error: $e');
      onError('Kuch galat ho gaya. Dobara try karein.');
    }
  }

  /// OTP verify karne ka function
  Future<UserCredential?> verifyOTP({
    required String verificationId,
    required String smsCode,
    required Function(String error) onError,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      print('OTP verified successfully');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Verify OTP error: ${e.code}');
      String errorMessage = _getErrorMessage(e.code);
      onError(errorMessage);
      return null;
    } catch (e) {
      print('Verify OTP error: $e');
      onError('OTP verify nahi ho saka. Dobara try karein.');
      return null;
    }
  }

  /// Auto-verified credential se sign in
  Future<UserCredential?> signInWithCredential({
    required PhoneAuthCredential credential,
    required Function(String error) onError,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential;
    } catch (e) {
      print('Sign in error: $e');
      onError('Sign in nahi ho saka.');
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Error messages ko user-friendly banane ka function
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Phone number galat hai. Sahi format mein dalein (+923001234567)';
      case 'too-many-requests':
        return 'Bohat zyada requests ho gayi. Thodi der baad try karein.';
      case 'invalid-verification-code':
        return 'OTP galat hai. Sahi code dalein.';
      case 'session-expired':
        return 'Session expire ho gaya. OTP dobara bhejein.';
      case 'quota-exceeded':
        return 'Daily limit exceed ho gayi. Kal try karein.';
      case 'network-request-failed':
        return 'Internet connection check karein.';
      case 'billing-not-enabled':
        return 'Free SMS limit khatam. Development ke liye "Test Numbers" use karein (Firebase Console mein add karein).';
      case 'invalid-app-credential':
        return 'App ki SHA-1 Key Firebase mein add nahi hai. Guide follow karein.';
      default:
        return 'Error: $code. Kuch galat ho gaya. Dobara try karein.';
    }
  }

  /// Get saved verification ID
  String? get verificationId => _verificationId;
}
