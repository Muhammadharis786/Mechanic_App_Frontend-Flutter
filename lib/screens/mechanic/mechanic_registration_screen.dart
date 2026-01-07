import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import '../authentication/user_session.dart';
import 'mechanic_dashboard.dart';
import '../authentication/user_session.dart';
import 'mechanic_dashboard.dart';
import 'mechanic_login.dart'; // Import MechanicLoginScreen
import 'package:geolocator/geolocator.dart'; // Added geolocator import

import 'package:mech_app/services/phone_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  XFile? profileImage;
  XFile? cnicFrontImage;
  XFile? cnicBackImage;

  String name = '';
  String phone = '';
  String password = '';
  String shopAddress = '';
  double? latitude; // Added latitude
  double? longitude; // Added longitude

  String mechanicType = 'Bike Mechanic';
  String experience = '';
  String workingHours = '';

  // ================= IMAGE PICK =================
  Future<void> pickImage(String type) async {
    // type: 'profile', 'cnicFront', 'cnicBack'
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() {
        if (type == 'profile') profileImage = img;
        if (type == 'cnicFront') cnicFrontImage = img;
        if (type == 'cnicBack') cnicBackImage = img;
      });
    }
  }

  // ================= LOCATION =================
  bool isGettingLocation = false;
  String? locationMessage;

  Future<void> _getCurrentLocation() async {
    setState(() {
      isGettingLocation = true;
      locationMessage = null;
    });

    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        isGettingLocation = false;
        locationMessage = 'Location services are disabled.';
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          isGettingLocation = false;
          locationMessage = 'Location permissions are denied';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        isGettingLocation = false;
        locationMessage = 'Location permissions are permanently denied.';
      });
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        locationMessage = "Location Acquired: ${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}";
        isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        isGettingLocation = false;
        locationMessage = 'Error getting location: $e';
      });
    }
  }

  // ================= SUBMIT =================
  bool isSubmitting = false;

  Future<void> submitRegistration() async {
    setState(() => isSubmitting = true);
    
    try {
      var uri = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/register");
      var request = http.MultipartRequest("POST", uri);




      // 1. Create JSON Data (mirroring JS mechanicData)
      Map<String, dynamic> mechanicData = {
        'userid':    UserSession().userId ?? 0, 
        'name': name,
        'phonenumber': phone,
        'password': password,
        'shopaddress': shopAddress,
        'mechanictype': mechanicType,
        'experienceyears': experience,
        'workinghours': workingHours,
        'otpVerified': true, 
        'latitude': latitude, // Added latitude
        'longitude': longitude // Added longitude
      };

      // 2. Add 'userData' as a JSON Part (application/json)
      request.files.add(http.MultipartFile.fromString(
        'userData',
        jsonEncode(mechanicData),
        contentType: MediaType('application', 'json'),
      ));

      // 3. Add Files with CORRECT keys (matching JS: mechanicprofilePicture, cnicfrontimg, cnicbackimg)
      if (profileImage != null) {
        if (kIsWeb) {
          request.files.add(http.MultipartFile.fromBytes(
            'mechanicprofilePicture',
            await profileImage!.readAsBytes(),
            filename: 'profile.jpg'
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath('mechanicprofilePicture', profileImage!.path));
        }
      }
      if (cnicFrontImage != null) {
        if (kIsWeb) {
           request.files.add(http.MultipartFile.fromBytes(
            'cnicfrontimg',
            await cnicFrontImage!.readAsBytes(),
            filename: 'cnic_front.jpg'
          ));
        } else {
           request.files.add(await http.MultipartFile.fromPath('cnicfrontimg', cnicFrontImage!.path));
        }
      }
      if (cnicBackImage != null) {
        if (kIsWeb) {
           request.files.add(http.MultipartFile.fromBytes(
            'cnicbackimg',
            await cnicBackImage!.readAsBytes(),
            filename: 'cnic_back.jpg'
          ));
        } else {
           request.files.add(await http.MultipartFile.fromPath('cnicbackimg', cnicBackImage!.path));
        }
      }

      // Send
      var response = await request.send();
      var responseBody = await response.stream.bytesToString(); // Read response

      if (response.statusCode == 200) {
        // Success
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration Successful!'), backgroundColor: Colors.green),
        );
        
        // Auto Login Session save (optional but good UX)
        await UserSession().saveSession(phone, password, 'MECHANIC');

        // Navigate
        if (mounted) {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
          );
        }
      } else if (response.statusCode == 409) {
         // Mechanic Already Exists
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already registered! Logging you in...'), backgroundColor: Colors.orange),
        );
        
        // Navigate to Login
        if (mounted) {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MechanicLoginScreen()), // Import MechanicLoginScreen if needed
          );
        }
      } else {
        debugPrint("Registration Error: $responseBody");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration Failed (${response.statusCode}): $responseBody'), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSubmitting = false);
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
      // Last step -> Submit
      submitRegistration();
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
                    onPressed: isSubmitting
                        ? null 
                        : nextPage,
                    child: isSubmitting 
                     ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                     : Text(
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

  // ================= PHONE CHECK =================
  bool isCheckingPhone = false;
  String? phoneStatusMessage;
  bool isPhoneOk = false;
  bool isOtpVerified = false;
  
  // OTP logic placeholders
  TextEditingController otpController = TextEditingController();

  Future<void> _checkPhoneNumber(String number) async {
    if (number.length < 10) return; // Basic length check for +92...

    setState(() {
      isCheckingPhone = true;
      phoneStatusMessage = null;
      isPhoneOk = false;
    });

    try {
      // 10.0.2.2 for Android Emulator localhost
      // Real device: Use your PC IP e.g. 192.168.x.x
      final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/checknumber");
      
      final response = await http.post(
        url,
        body: {'phonenumber': number},
      );

      if (response.statusCode == 200) {
        setState(() {
          isPhoneOk = true;
          phoneStatusMessage = "Number Available ";
        });
      } else {
        setState(() {
          isPhoneOk = false;
          phoneStatusMessage = "Number Status: ${response.statusCode } (Not Available)";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isPhoneOk = false;
          phoneStatusMessage = "Error checking number";
        });
      }
    } finally {
      if (mounted) {
         setState(() => isCheckingPhone = false);
      }
    }
  }

  // ================= OTP LOGIC =================
  String? verificationId;
  final PhoneAuthService _authService = PhoneAuthService();

  Future<void> _sendOTP() async {
    if (phone.isEmpty) return;
    
    // Show spinner or loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sending OTP...')),
    );

    await _authService.sendOTP(
      phoneNumber: phone,
      onCodeSent: (id) {
        setState(() {
          verificationId = id;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP Sent! Check SMS.')),
        );
      },
      onError: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      },
      onAutoVerified: (credential) async {
        // Auto sign-in logic if needed
        setState(() => isOtpVerified = true);
      },
    );
  }

  Future<void> _verifyOTP() async {
    String code = otpController.text.trim();
    if (code.isEmpty || verificationId == null) return;

    final credential = await _authService.verifyOTP(
      verificationId: verificationId!,
      smsCode: code,
      onError: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      },
    );

    if (credential != null && credential.user != null) {
      setState(() => isOtpVerified = true);
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone Verified!'), backgroundColor: Colors.green),
        );
    }
  }

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
                  backgroundImage: profileImage != null
                      ? (kIsWeb
                          ? NetworkImage(profileImage!.path)
                          : FileImage(File(profileImage!.path)) as ImageProvider)
                      : null,
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
          
          // Phone Input with Check Logic
          input(
            'Phone Number',
            type: TextInputType.phone,
            prefix: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('+92',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            onChanged: (v) {
              phone = '+92$v';
              if (v.length >= 10) {
                // Debounce could be good, but direct call for now
                _checkPhoneNumber(phone);
              }
            },
          ),
          
          // Status Message
          if (isCheckingPhone)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (phoneStatusMessage != null)
             Padding(
              padding: const EdgeInsets.only(top: 5, left: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  phoneStatusMessage!,
                  style: GoogleFonts.poppins(
                    color: isPhoneOk ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),
          
          // OTP Section (Only if phone is OK)
          if (isPhoneOk)
            Padding(
               padding: const EdgeInsets.only(bottom: 12),
               child: Column(
                 children: [
                   Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey,
                            ),
                            onPressed: (isOtpVerified || phone.length < 10) ? null : _sendOTP,
                            child: Text(isOtpVerified ? "Verified" : "Get OTP"),
                          ),
                        ),
                        if (!isOtpVerified) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: otpController,
                              decoration: const InputDecoration(
                                hintText: "Enter Code",
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ]
                      ],
                   ),
                   if (!isOtpVerified && verificationId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: _verifyOTP, 
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: const Text("Verify Code")
                          ),
                        ),
                      )
                 ],
               ),
            ),

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
          const SizedBox(height: 20),

          // Location Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isGettingLocation ? null : _getCurrentLocation,
              icon: isGettingLocation 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.my_location, color: Colors.white),
              label: Text(
                isGettingLocation ? 'Getting Location...' : 'Allow Current Location',
                 style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          if (locationMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                locationMessage!,
                style: GoogleFonts.poppins(
                  color: (latitude != null && longitude != null) ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (latitude != null && longitude != null)
             Padding(
               padding: const EdgeInsets.only(top: 4.0),
               child: Text(
                 "Lat: $latitude, Lng: $longitude",
                 style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
               ),
             ),

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
              child: kIsWeb
                  ? Image.network(cnicFrontImage!.path, height: 150, fit: BoxFit.cover)
                  : Image.file(File(cnicFrontImage!.path), height: 150, fit: BoxFit.cover),
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
              child: kIsWeb
                  ? Image.network(cnicBackImage!.path, height: 150, fit: BoxFit.cover)
                  : Image.file(File(cnicBackImage!.path), height: 150, fit: BoxFit.cover),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
