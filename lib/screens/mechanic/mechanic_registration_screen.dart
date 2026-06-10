import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../authentication/user_session.dart';

import 'mechanic_login.dart'; // Import MechanicLoginScreen
import 'mechanic_map_selection_screen.dart';

class MechanicRegistrationScreen extends StatefulWidget {
  final String phoneNumber;
  final String password;
  
  const MechanicRegistrationScreen({super.key, required this.phoneNumber, required this.password});

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
  // phone is now retrieved from widget.phoneNumber rather than input on this screen
  String shopAddress = '';
  final TextEditingController addressController = TextEditingController();
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

  // ================= SUBMIT =================
  bool isSubmitting = false;

  String _mechanicTypeForApi(String value) {
    final type = value.trim().toLowerCase();
    if (type.contains('bike')) return 'bike';
    if (type.contains('car')) return 'car';
    if (type.contains('punch') || type.contains('punct')) return 'puncher';
    return type;
  }

  Future<void> submitRegistration() async {
    setState(() => isSubmitting = true);
    
    try {
      var uri = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/register");
      var request = http.MultipartRequest("POST", uri);

      // 1. Create JSON Data
      Map<String, dynamic> mechanicData = {
        'name': name,
        'phonenumber': widget.phoneNumber,
        'shopaddress': shopAddress,
        'mechanictype': _mechanicTypeForApi(mechanicType),
        'experienceyears': int.tryParse(experience) ?? 0,
        'workinghours': workingHours,
        'latitude': latitude,
        'longitude': longitude
      };
      
      // Print complete data being sent (like Postman)
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('📤 MECHANIC REGISTRATION DATA BEING SENT:');
      debugPrint(JsonEncoder.withIndent('  ').convert(mechanicData));
      debugPrint('Images:');
      debugPrint('  - Profile Image: ${profileImage != null ? "✓ Selected" : "✗ Not Selected"}');
      debugPrint('  - CNIC Front: ${cnicFrontImage != null ? "✓ Selected" : "✗ Not Selected"}');
      debugPrint('  - CNIC Back: ${cnicBackImage != null ? "✓ Selected" : "✗ Not Selected"}');
      debugPrint('═══════════════════════════════════════════════════');
      
      // 2. Add 'userData' as a JSON Part
      request.files.add(http.MultipartFile.fromString(
        'userData',
        jsonEncode(mechanicData),
        contentType: MediaType('application', 'json'),
      ));

      // 3. Add Files with Web/Mobile Compatibility
      // Helper function to add files correctly
      Future<void> addMultipartFile(String fieldName, XFile? file, String defaultName) async {
        if (file == null) return;
        
        if (kIsWeb) {
          // For Web: Use fromBytes
          final bytes = await file.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: file.name.isNotEmpty ? file.name : defaultName,
            contentType: MediaType('image', 'jpeg'), // Adjust if needed
          ));
        } else {
          // For Mobile: Use fromPath
          request.files.add(await http.MultipartFile.fromPath(
            fieldName, 
            file.path,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }

      await addMultipartFile('mechanicprofilePicture', profileImage, 'profile.jpg');
      await addMultipartFile('cnicfrontimg', cnicFrontImage, 'cnic_front.jpg');
      await addMultipartFile('cnicbackimg', cnicBackImage, 'cnic_back.jpg');

      // Send
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration Successful! Please login to continue.'), backgroundColor: Colors.green),
        );
        
        if (mounted) {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MechanicLoginScreen()),
          );
        }
      } else if (response.statusCode == 409 || responseBody.contains("already exists")) {
        // Handle "Already Registered" case
        // Try to parse backend message
        String errorMessage = 'You are already registered as a mechanic!';
        try {
          final responseData = jsonDecode(responseBody);
          if (responseData is Map && responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else if (responseData is String) {
            errorMessage = responseData;
          }
        } catch (e) {
          // Use default message if parsing fails
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage), 
            backgroundColor: const Color.fromARGB(255, 250, 61, 3),
          ),
        );
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MechanicLoginScreen()),
          );
        }
      } else {
        // Parse backend error message
        String errorMessage = 'Registration Failed';
        try {
          final responseData = jsonDecode(responseBody);
          if (responseData is Map && responseData.containsKey('message')) {
            errorMessage = responseData['message'];
          } else if (responseData is Map && responseData.containsKey('error')) {
            errorMessage = responseData['error'];
          } else if (responseData is String) {
            errorMessage = responseData;
          }
        } catch (e) {
          // If parsing fails, use response body as is (but keep it clean)
          errorMessage = responseBody.isNotEmpty && responseBody.length < 100 
              ? responseBody 
              : 'Registration failed. Please try again.';
        }
        
        debugPrint("Registration Error Status: ${response.statusCode}");
        debugPrint("Registration Error Body: $responseBody");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage), 
            backgroundColor: Colors.red,
          ),
        );
      }

    } catch (e) {
      debugPrint("Submit Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }


  // ================= VALIDATION =================
  bool _validateCurrentStep() {
    if (currentStep == 0) {
      if (profileImage == null) {
        _showError('Please upload a profile picture.');
        return false;
      }
      if (name.trim().isEmpty) {
        _showError('Please enter your full name.');
        return false;
      }
      return true;
    } else if (currentStep == 1) {
      if (shopAddress.trim().isEmpty) {
        _showError('Please provide your shop address.');
        return false;
      }
      if (latitude == null || longitude == null) {
        _showError('Please select a location from the map.');
        return false;
      }
      return true;
    } else if (currentStep == 2) {
      if (mechanicType.isEmpty) {
        _showError('Please select a mechanic type.');
        return false;
      }
      if (experience.trim().isEmpty) {
        _showError('Please enter your experience in years.');
        return false;
      }
      if (workingHours.trim().isEmpty) {
        _showError('Please specify your working hours.');
        return false;
      }
      return true;
    } else if (currentStep == 3) {
      if (cnicFrontImage == null) {
        _showError('Please upload CNIC Front Image.');
        return false;
      }
      if (cnicBackImage == null) {
        _showError('Please upload CNIC Back Image.');
        return false;
      }
      return true;
    }
    return true;
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    }
  }

  // ================= NAVIGATION =================
  void nextPage() {
    if (!_validateCurrentStep()) return;

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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'Close Registration',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: theme.textTheme.titleLarge?.color),
        ),
        content: Text(
          'Are you sure you want to close registration process?',
          style: GoogleFonts.poppins(color: theme.textTheme.bodyMedium?.color),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      keyboardType: type,
      obscureText: isPassword && !showPassword,
      inputFormatters: formatters,
      onChanged: onChanged,
      style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white38 : Colors.grey),
        filled: true,
        fillColor: isDark ? Colors.grey[900] : Colors.white,
        prefixIcon: prefix,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  showPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: primary,
                ),
                onPressed: () =>
                    setState(() => showPassword = !showPassword),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.grey[800]! : primary),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      splashRadius: 20,
                      onPressed: previousPage,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFFFB3300),
                        size: 18,
                      ),
                      padding: const EdgeInsets.all(4),
                    ),
                  Expanded(
                    child: Text(
                      _titles[currentStep],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w600, color: theme.textTheme.titleLarge?.color),
                    ),
                  ),
                  IconButton(
                    onPressed: showCloseDialog,
                    icon: Icon(Icons.close_rounded, color: primary),
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
                            style: GoogleFonts.poppins(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (currentStep + 1) / totalSteps,
                          backgroundColor: isDark ? Colors.grey[900] : Colors.grey.shade300,
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
                            fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.titleMedium?.color)),
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
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey.shade200,
                  backgroundImage: profileImage != null
                      ? (kIsWeb
                          ? NetworkImage(profileImage!.path)
                          : FileImage(File(profileImage!.path)) as ImageProvider)
                      : null,
                  child: profileImage == null
                      ? Icon(Icons.add_circle_outline_rounded, size: 30, color: primary)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          input('Full Name', onChanged: (v) => name = v),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: addressController,
                  style: GoogleFonts.poppins(color: Theme.of(context).textTheme.bodyLarge?.color),
                  onChanged: (v) => shopAddress = v,
                  decoration: InputDecoration(
                    hintText: 'Shop Address',
                    hintStyle: GoogleFonts.poppins(color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.map_outlined, color: Colors.white),
                  onPressed: () async {
                    FocusScope.of(context).unfocus(); // Close keyboard before opening map
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MechanicMapSelectionScreen(
                          initialLat: latitude,
                          initialLng: longitude,
                        ),
                      ),
                    );
                    if (result != null && result is Map<String, dynamic>) {
                      final String selectedAddress =
                          (result['address']?.toString().trim() ?? '');

                      setState(() {
                        latitude = result['latitude'] as double?;
                        longitude = result['longitude'] as double?;
                        shopAddress = selectedAddress.isNotEmpty
                            ? selectedAddress
                            : 'Selected location';
                        addressController.text = shopAddress;
                        locationMessage = 'Location Selected from Map';
                      });
                    }
                  },
                ),
              ),
            ],
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
            dropdownColor: Theme.of(context).cardColor,
            style: GoogleFonts.poppins(color: Theme.of(context).textTheme.bodyLarge?.color),
            items: const [
              DropdownMenuItem(value: 'Bike Mechanic', child: Text('Bike Mechanic')),
              DropdownMenuItem(value: 'Car Mechanic', child: Text('Car Mechanic')),
              DropdownMenuItem(value: 'Puncher', child: Text('Puncher')),
            ],
            onChanged: (v) => mechanicType = v!,
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : primary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 2),
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
          Text('Upload CNIC Front (شناختی کارڈ سامنے wala حصہ)',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.titleMedium?.color)),
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
          Text('Upload CNIC Back (شناختی کارڈ پیچھے wala حصہ)',
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.titleMedium?.color)),
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
