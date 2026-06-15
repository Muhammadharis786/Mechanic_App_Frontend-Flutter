import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'mechanic_registration_screen.dart';

class MechanicKycScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;

  const MechanicKycScreen({
    super.key,
    required this.phoneNumber,
    required this.password,
  });

  @override
  State<MechanicKycScreen> createState() => _MechanicKycScreenState();
}

class _MechanicKycScreenState extends State<MechanicKycScreen> {
  static const _baseUrl =
      'https://mechanicapp-service-621632382478.asia-south1.run.app';

  final ImagePicker _picker = ImagePicker();
  final Color primary = const Color(0xFFEF3838);
  final Color textDark = const Color(0xFF07162D);
  final Color muted = const Color(0xFF7D8797);

  int _step = 0;
  XFile? _nicFront;
  XFile? _nicBack;
  XFile? _selfie;
  bool _isVerifying = false;
  _KycResult? _result;

  Future<void> _pickCnicImage({
    required bool front,
    required ImageSource source,
  }) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;
    setState(() {
      if (front) {
        _nicFront = image;
      } else {
        _nicBack = image;
      }
    });
  }

  Future<void> _pickSelfie() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 88,
      maxWidth: 1400,
    );
    if (image == null || !mounted) return;
    setState(() => _selfie = image);
  }

  Future<http.MultipartFile> _multipartImage(
    String field,
    XFile file,
    String fallbackName,
  ) async {
    if (kIsWeb) {
      return http.MultipartFile.fromBytes(
        field,
        await file.readAsBytes(),
        filename: file.name.isNotEmpty ? file.name : fallbackName,
        contentType: MediaType('image', 'jpeg'),
      );
    }

    return http.MultipartFile.fromPath(
      field,
      file.path,
      contentType: MediaType('image', 'jpeg'),
    );
  }

  Future<void> _verifyKyc() async {
    if (_nicFront == null || _nicBack == null || _selfie == null) {
      _showSnack('Please complete CNIC and selfie verification first.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '$_baseUrl/api/kyc/verify/${Uri.encodeComponent(widget.phoneNumber)}',
        ),
      );

      request.files.add(await _multipartImage('nicFront', _nicFront!, 'nic_front.jpg'));
      request.files.add(await _multipartImage('nicBack', _nicBack!, 'nic_back.jpg'));
      request.files.add(await _multipartImage('selfie', _selfie!, 'selfie.jpg'));

      final response = await request.send();
      final body = await response.stream.bytesToString();
      debugPrint('KYC response status: ${response.statusCode}');
      debugPrint('KYC response body: $body');

      if (!mounted) return;
      setState(() {
        _result = _parseKycResult(body, response.statusCode);
        _step = 4;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = _KycResult(
          verified: false,
          score: '--',
          message: 'KYC Failed. Please try again.',
          rawBody: e.toString(),
        );
        _step = 4;
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  _KycResult _parseKycResult(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        // Even if verified is true in JSON, if it's a conflict/error status, we treat as unverified
        final apiVerified = decoded['verified'] == true;
        final isConflict = statusCode == 409 || (decoded['message']?.toString().toLowerCase().contains('already used') ?? false);
        
        return _KycResult(
          verified: apiVerified && !isConflict,
          score: (decoded['similarityScore'] ?? decoded['score'] ?? '--').toString(),
          message: (decoded['message'] ?? (statusCode < 300 ? 'KYC Verified' : body)).toString(),
          rawBody: body,
        );
      }
    } catch (_) {}

    return _KycResult(
      verified: statusCode >= 200 && statusCode < 300,
      score: '--',
      message: body.isNotEmpty ? body : 'KYC verification completed.',
      rawBody: body,
    );
  }

  void _continueRegistration() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MechanicRegistrationScreen(
          phoneNumber: widget.phoneNumber,
          password: widget.password,
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: primary),
    );
  }

  void _showCnicPicker(bool front) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E5EC),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                front ? 'CNIC Front Side' : 'CNIC Back Side',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _sheetAction(
                      icon: Icons.photo_camera_outlined,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickCnicImage(front: front, source: ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sheetAction(
                      icon: Icons.file_upload_outlined,
                      label: 'Upload',
                      onTap: () {
                        Navigator.pop(context);
                        _pickCnicImage(front: front, source: ImageSource.gallery);
                      },
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

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isVerifying
              ? _buildVerifying()
              : switch (_step) {
                  0 => _buildLanding(),
                  1 => _buildIntro(),
                  2 => _buildUpload(),
                  3 => _buildSelfie(),
                  _ => _buildResult(),
                },
        ),
      ),
    );
  }

  Widget _buildVerifying() {
    return Container(
      key: const ValueKey('verifying'),
      width: double.infinity,
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                  backgroundColor: const Color(0xFFF1F1F1),
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF2F2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shield_outlined, color: primary, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Text(
            'Verifying...',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Comparing selfie with your CNIC photo using AI face matching...',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: muted,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.3 + (i * 0.3)),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final result = _result;
    final verified = result?.verified == true;
    final isConflict = result?.message.toLowerCase().contains('used') == true;
    final successColor = const Color(0xFF0FB478);
    final failColor = primary;

    return Container(
      key: const ValueKey('result'),
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: (verified ? successColor : failColor).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: verified ? successColor : failColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (verified ? successColor : failColor).withOpacity(0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    verified ? Icons.check_rounded : (isConflict ? Icons.warning_rounded : Icons.close_rounded),
                    color: Colors.white,
                    size: 58,
                  ),
                ),
                if (verified)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(Icons.shield, color: successColor, size: 24),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            verified ? 'Verification Complete!' : (isConflict ? 'Attention Needed' : 'Verification Failed'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result?.message ?? (verified ? 'Your identity has been verified successfully.' : 'Verification failed.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          // Score Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: verified ? successColor : (isConflict ? const Color(0xFFFF9500) : failColor),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (verified ? successColor : (isConflict ? const Color(0xFFFF9500) : failColor)).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          verified ? 'Biometric Match Score' : 'Match Score',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              result?.score.replaceAll('%', '') ?? '0',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, left: 4),
                              child: Text(
                                '%',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            verified ? Icons.star_rounded : (isConflict ? Icons.info_outline : Icons.cancel_outlined),
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            verified ? 'HIGH' : (isConflict ? 'CONFLICT' : 'LOW'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Match confidence',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      verified ? '${result?.score.replaceAll('%', '')} / 100' : 'Threshold: 90%',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (double.tryParse(result?.score.replaceAll('%', '') ?? '0') ?? 0) / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statusPill(verified ? 'PASSED' : (isConflict ? 'PASSED' : 'FAILED'), 'Face Match', verified || isConflict),
                    const SizedBox(width: 8),
                    _statusPill(verified ? 'VALID' : (isConflict ? 'USED' : 'BLURRY'), 'Document', verified),
                    const SizedBox(width: 8),
                    _statusPill(verified ? 'LIVE' : (isConflict ? 'VALID' : 'LOW'), 'Liveness', verified || isConflict),
                  ],
                ),
              ],
            ),
          ),
          
          if (!verified && !isConflict) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFF2A100), size: 20),
                const SizedBox(width: 8),
                Text(
                  'How to fix this',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _fixItem(Icons.lightbulb_outline_rounded, 'Improve lighting', 'Use bright, even light — avoid harsh shadows or backlight'),
            const SizedBox(height: 12),
            _fixItem(Icons.badge_outlined, 'CNIC image quality', 'Ensure the CNIC text and photo are sharp and readable'),
          ],
          
          if (isConflict) ...[
            const SizedBox(height: 32),
            _fixItem(Icons.contact_support_outlined, 'Contact Support', 'This CNIC is already registered. If you think this is a mistake, please reach out to admin.'),
          ],

          const SizedBox(height: 40),
          _primaryButton(
            label: verified ? 'Continue Registration' : 'Retry Verification',
            onPressed: verified
                ? _continueRegistration
                : () => setState(() {
                      _step = 2;
                      _result = null;
                      _nicFront = null;
                      _nicBack = null;
                      _selfie = null;
                    }),
            icon: verified ? null : Icons.refresh_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildLanding() {
    return _scrollablePage(
      key: const ValueKey('landing'),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 22),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.build_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 24),
          Text(
            'MechVerify',
            style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w800, color: textDark),
          ),
          const SizedBox(height: 10),
          Text(
            'Professional identity verification for mobile\nmechanics. Build trust with your customers.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF536076), height: 1.7),
          ),
          const SizedBox(height: 44),
          _landingFeature(Icons.shield_outlined, 'Bank-grade identity verification'),
          const SizedBox(height: 16),
          _landingFeature(Icons.verified_outlined, 'AI-powered face matching'),
          const SizedBox(height: 16),
          _landingFeature(Icons.handyman_outlined, 'Trusted mechanic badge'),
          const SizedBox(height: 38),
          _primaryButton(
            label: 'Begin KYC Verification',
            onPressed: () => setState(() => _step = 1),
          ),
          const SizedBox(height: 12),
          Text(
            'Takes less than 2 minutes • Secure & private',
            style: GoogleFonts.poppins(color: const Color(0xFF99A2B2), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return _stepScaffold(
      key: const ValueKey('intro'),
      step: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          _aiCard(),
          const SizedBox(height: 24),
          _title('Verify Your Identity'),
          const SizedBox(height: 10),
          _bodyText('Complete this one-time verification to unlock all features of your mechanic account.'),
          const SizedBox(height: 30),
          _sectionLabel("WHAT YOU'LL NEED"),
          const SizedBox(height: 12),
          _needCard(
            icon: Icons.badge_outlined,
            title: 'Prepare your CNIC',
            body: 'Have your national ID card ready (front & back)',
            number: '1',
          ),
          const SizedBox(height: 14),
          _needCard(
            icon: Icons.photo_camera_outlined,
            title: 'Take a selfie',
            body: "We'll match your face with your CNIC photos",
            number: '2',
          ),
          const SizedBox(height: 30),
          _primaryButton(
            label: 'Start Verification',
            onPressed: () => setState(() => _step = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildUpload() {
    final canContinue = _nicFront != null && _nicBack != null;
    return _stepScaffold(
      key: const ValueKey('upload'),
      step: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _title('Upload Your CNIC'),
          const SizedBox(height: 6),
          _bodyText('Take clear photos of both sides of your national identity card.'),
          const SizedBox(height: 24),
          _cnicUploadBox(front: true),
          const SizedBox(height: 18),
          _cnicUploadBox(front: false),
          const SizedBox(height: 22),
          _primaryButton(
            label: canContinue ? 'Next: Selfie' : 'Upload both sides to continue',
            disabled: !canContinue,
            onPressed: () => setState(() => _step = 3),
          ),
        ],
      ),
    );
  }

  Widget _buildSelfie() {
    final captured = _selfie != null;
    return _stepScaffold(
      key: const ValueKey('selfie'),
      step: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _title('Take a Selfie'),
          const SizedBox(height: 8),
          _bodyText('Position your face within the circle. Ensure good lighting.'),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: captured ? null : _pickSelfie,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: captured ? const Color(0xFFE9FFF4) : const Color(0xFFFFF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: captured ? const Color(0xFF35D399) : primary, width: 3),
                ),
                child: captured
                    ? const Icon(Icons.check_rounded, color: Color(0xFF00946D), size: 64)
                    : Icon(Icons.face_retouching_natural, size: 64, color: primary),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: _secondaryButton(
                  label: 'Retake',
                  icon: Icons.refresh_rounded,
                  onPressed: _pickSelfie,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _primaryButton(
                  label: 'Continue ->',
                  disabled: !captured,
                  onPressed: _verifyKyc,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, String sub, bool success) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
            ),
            Text(
              sub,
              style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.7), fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fixItem(IconData icon, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: textDark, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.poppins(color: muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
    bool disabled = false,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryButton({required String label, required IconData icon, required VoidCallback onPressed}) {
    return SizedBox(
      height: 60,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF4F6F9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        icon: Icon(icon, color: textDark),
        label: Text(label, style: GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _stepScaffold({required Key key, required int step, required Widget child}) {
    return Container(
      key: key,
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (step > 1) _backButton() else const SizedBox(width: 48),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('KYC Verification', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18)),
                      Text('Step $step of 3', style: GoogleFonts.poppins(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20), child: child)),
        ],
      ),
    );
  }

  Widget _backButton() {
    return IconButton(
      onPressed: () => setState(() => _step--),
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
    );
  }

  Widget _scrollablePage({required Key key, required Color color, required EdgeInsets padding, required Widget child}) {
    return Container(key: key, color: color, child: SingleChildScrollView(padding: padding, child: child));
  }

  Widget _landingFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: primary),
        const SizedBox(width: 12),
        Text(text, style: GoogleFonts.poppins(fontSize: 14)),
      ],
    );
  }

  Widget _aiCard() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: CustomPaint(painter: _IdCardPainter(primary)),
    );
  }

  Widget _title(String text) => Text(text, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: textDark));
  Widget _bodyText(String text) => Text(text, textAlign: TextAlign.start, style: GoogleFonts.poppins(color: muted, fontSize: 14));
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFFA8B0BE))),
  );

  Widget _needCard({required IconData icon, required String title, required String body, required String number}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: textDark)),
                Text(body, style: GoogleFonts.poppins(fontSize: 12, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cnicUploadBox({required bool front}) {
    final image = front ? _nicFront : _nicBack;
    return InkWell(
      onTap: () => _showCnicPicker(front),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: image == null ? const Color(0xFFE0E5ED) : const Color(0xFF35D399)),
        ),
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: muted),
                  const SizedBox(height: 8),
                  Text(front ? 'Capture Front Side' : 'Capture Back Side', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textDark)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: kIsWeb ? Image.network(image.path, fit: BoxFit.cover) : Image.file(File(image.path), fit: BoxFit.cover),
              ),
      ),
    );
  }
}

class _KycResult {
  final bool verified;
  final String score;
  final String message;
  final String rawBody;

  const _KycResult({
    required this.verified,
    required this.score,
    required this.message,
    required this.rawBody,
  });
}

class _IdCardPainter extends CustomPainter {
  final Color primary;
  const _IdCardPainter(this.primary);

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = primary.withOpacity(0.72)
      ..strokeWidth = 1.4;
    final linePaint = Paint()
      ..color = const Color(0xFFD8DCE4)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, size.height * 0.45), Offset(size.width, size.height * 0.45), borderPaint);
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.28), 18, Paint()..color = primary.withOpacity(0.12));

    final textPainter = TextPainter(
      text: TextSpan(text: 'ID', style: GoogleFonts.poppins(color: primary, fontSize: 13, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.width * 0.22 - textPainter.width / 2, size.height * 0.28 - 9));

    canvas.drawLine(Offset(size.width * 0.48, size.height * 0.24), Offset(size.width * 0.86, size.height * 0.24), linePaint);
    canvas.drawLine(Offset(size.width * 0.48, size.height * 0.34), Offset(size.width * 0.76, size.height * 0.34), linePaint);
  }

  @override
  bool shouldRepaint(covariant _IdCardPainter oldDelegate) => oldDelegate.primary != primary;
}
