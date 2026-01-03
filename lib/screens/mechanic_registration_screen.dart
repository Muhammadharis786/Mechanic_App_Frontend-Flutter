import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// Import your dashboard screen
import 'mechanic_dashboard.dart';

class MechanicRegistrationScreen extends StatefulWidget {
  const MechanicRegistrationScreen({super.key});

  @override
  State<MechanicRegistrationScreen> createState() =>
      _MechanicRegistrationScreenState();
}

class _MechanicRegistrationScreenState
    extends State<MechanicRegistrationScreen> {
  final PageController _pageController = PageController();
  final ImagePicker _picker = ImagePicker();

  final Color primary = const Color(0xFFFB3300);

  int currentStep = 0;
  final int totalSteps = 4;
  bool showPassword = false;

  // ==================== IMAGES ====================
  File? profileImage;
  File? cnicFrontImage;
  File? cnicBackImage;

  String name = '';
  String phone = '';
  String password = '';
  String shopAddress = '';
  String homeAddress = '';
  String mechanicType = 'Bike Mechanic';
  String experience = '';
  String workingHours = '';

  // ================= IMAGE PICK =================
  Future<void> pickImage(String type) async {
    // type: 'profile', 'cnicFront', 'cnicBack'
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        if (type == 'profile') profileImage = File(img.path);
        if (type == 'cnicFront') cnicFrontImage = File(img.path);
        if (type == 'cnicBack') cnicBackImage = File(img.path);
      });
    }
  }

  // ================= NAVIGATION =================
  void nextPage() {
    if (currentStep < totalSteps - 1) {
      setState(() => currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Last step -> Submit -> Navigate to dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MechanicDashboardScreen()),
      );
    }
  }

  void previousPage() {
    if (currentStep > 0) {
      setState(() => currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ================= CLOSE DIALOG =================
  void showCloseDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Close Registration',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to close registration process?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(backgroundColor: primary),
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
          TextButton(
            style: TextButton.styleFrom(backgroundColor: primary),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Yes, Exit',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ================= INPUT FIELD =================
  Widget input(
    String hint, {
    bool isPassword = false,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
    Widget? prefix,
    Function(String)? onChanged,
  }) {
    return TextField(
      keyboardType: type,
      obscureText: isPassword && !showPassword,
      inputFormatters: formatters,
      onChanged: onChanged,
      style: GoogleFonts.poppins(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(),
        prefixIcon: prefix,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  showPassword ? Icons.visibility : Icons.visibility_off,
                  color: primary,
                ),
                onPressed: () =>
                    setState(() => showPassword = !showPassword),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  if (currentStep > 0)
                    IconButton(
                      onPressed: previousPage,
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: primary, size: 22),
                    ),
                  Expanded(
                    child: Text(
                      _titles[currentStep],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: showCloseDialog,
                    icon: Icon(Icons.close, color: primary),
                  ),
                ],
              ),
            ),

            // PAGES
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  personalInfo(),
                  locationInfo(),
                  professionalInfo(),
                  documentInfo(),
                ],
              ),
            ),

            // BOTTOM BAR
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${currentStep + 1} of $totalSteps',
                            style: GoogleFonts.poppins(fontSize: 12)),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (currentStep + 1) / totalSteps,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(primary),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primary),
                    onPressed: nextPage,
                    child: Text(
                      currentStep == totalSteps - 1 ? 'Submit' : 'Next',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  final List<String> _titles = [
    'Personal Information',
    'Location Information',
    'Professional Information',
    'Documents'
  ];

  // ================= STEP 1 =================
  Widget personalInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upload Profile Picture',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('This will be visible to customers',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => pickImage('profile'),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      profileImage != null ? FileImage(profileImage!) : null,
                  child: profileImage == null
                      ? Icon(Icons.add, size: 30, color: primary)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          input('Full Name', onChanged: (v) => name = v),
          const SizedBox(height: 12),
          input(
            'Phone Number',
            type: TextInputType.phone,
            prefix: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('+92',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            onChanged: (v) => phone = '+92$v',
          ),
          const SizedBox(height: 12),
          input('Password', isPassword: true, onChanged: (v) => password = v),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ================= STEP 2 =================
  Widget locationInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          input('Shop Address', onChanged: (v) => shopAddress = v),
          const SizedBox(height: 12),
          input('Home Address', onChanged: (v) => homeAddress = v),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ================= STEP 3 =================
  Widget professionalInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField(
            initialValue: mechanicType,
            items: const [
              DropdownMenuItem(value: 'Bike Mechanic', child: Text('Bike Mechanic')),
              DropdownMenuItem(value: 'Car Mechanic', child: Text('Car Mechanic')),
              DropdownMenuItem(value: 'Puncture Specialist', child: Text('Puncture Specialist')),
            ],
            onChanged: (v) => mechanicType = v!,
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          input(
            'Experience (Years)',
            type: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => experience = v,
          ),
          const SizedBox(height: 12),
          input('Working Hours', onChanged: (v) => workingHours = v),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ================= STEP 4 =================
  Widget documentInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CNIC Front
          Text('Upload CNIC Front (شناختی کارڈ سامنے والا حصہ)',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: () => pickImage('cnicFront'),
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: Text('Select Front Image',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          if (cnicFrontImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(cnicFrontImage!, height: 150, fit: BoxFit.cover),
            ),
          const SizedBox(height: 24),

          // CNIC Back
          Text('Upload CNIC Back (شناختی کارڈ پیچھے والا حصہ)',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: () => pickImage('cnicBack'),
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: Text('Select Back Image',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          if (cnicBackImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(cnicBackImage!, height: 150, fit: BoxFit.cover),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
