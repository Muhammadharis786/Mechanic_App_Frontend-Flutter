import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MechanicProfileScreen extends StatefulWidget {
  const MechanicProfileScreen({super.key});

  @override
  State<MechanicProfileScreen> createState() => _MechanicProfileScreenState();
}

class _MechanicProfileScreenState extends State<MechanicProfileScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  bool isEditing = false;
  
  // FORM KEY: Validation ke liye zaroori hai
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController nameController = TextEditingController(text: "Ali Khan");
  final TextEditingController phoneController = TextEditingController(text: "923267081272");
  final TextEditingController emailController = TextEditingController(text: "hamnabasit22@gmail.com");
  final TextEditingController workshopController = TextEditingController(text: "Ali Auto Care Center");
  final TextEditingController addressController = TextEditingController(text: "Main Saddar Road, Karachi");
  final TextEditingController experienceController = TextEditingController(text: "8");

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nameController.text = prefs.getString('mech_name') ?? "Ali Khan";
      phoneController.text = prefs.getString('mech_phone') ?? "923267081272";
      emailController.text = prefs.getString('mech_email') ?? "hamnabasit22@gmail.com";
      workshopController.text = prefs.getString('mech_workshop') ?? "Ali Auto Care Center";
      addressController.text = prefs.getString('mech_address') ?? "Main Saddar Road, Karachi";
      experienceController.text = prefs.getString('mech_experience') ?? "8";

      final savedImagePath = prefs.getString('mech_profile_image');
      if (savedImagePath != null && savedImagePath.isNotEmpty) {
        pickedProfileImage = XFile(savedImagePath);
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    workshopController.dispose();
    addressController.dispose();
    experienceController.dispose();
    super.dispose();
  }

  XFile? pickedProfileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    if (!isEditing) return;
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          pickedProfileImage = pickedFile;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.orange, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("My Profile", style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        actions: [
          if (!isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    isEditing = true;
                  });
                },
                icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                label: const Text("Edit", style: TextStyle(color: Colors.orange, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    isEditing = false;
                  });
                },
                child: const Text("Cancel", style: TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Form(
          key: _formKey, 
          // autovalidateMode ko change kiya taake user jab likhay tabhi check kare
          autovalidateMode: isEditing ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: pickedProfileImage != null
                            ? (kIsWeb
                                ? Image.network(
                                    pickedProfileImage!.path,
                                    fit: BoxFit.cover,
                                    width: 110,
                                    height: 110,
                                  )
                                : Image.file(
                                    File(pickedProfileImage!.path),
                                    fit: BoxFit.cover,
                                    width: 110,
                                    height: 110,
                                  ))
                            : Icon(Icons.person, size: 55, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      ),
                    ),
                    if (isEditing)
                      Positioned(
                        bottom: 5, right: 5,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              _buildLabel("Full Name", isDark),
              _buildTextField(nameController, Icons.person_outline, isReadOnly: true, isDark: isDark),

              _buildLabel("Phone Number", isDark),
              _buildTextField(phoneController, Icons.phone_outlined, isReadOnly: true, isDark: isDark),

              _buildLabel("Email Address", isDark),
              _buildTextField(
                emailController, 
                Icons.email_outlined, 
                isDark: isDark,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  // Proper Email Regex
                  final bool emailValid = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value);
                  if (!emailValid) {
                    return 'Enter a valid email (e.g. name@mail.com)';
                  }
                  return null;
                },
              ),

              _buildLabel("Workshop Name", isDark),
              _buildTextField(workshopController, Icons.home_repair_service_outlined, 
                isDark: isDark, validator: (v) => v!.isEmpty ? "Workshop name required" : null),

              _buildLabel("Workshop Address", isDark),
              _buildTextField(addressController, Icons.location_on_outlined, 
                isDark: isDark, validator: (v) => v!.isEmpty ? "Workshop address required" : null),

              _buildLabel("Experience", isDark),
              _buildTextField(
                experienceController, 
                Icons.timer_outlined, 
                isDark: isDark,
                isNumber: true,
                suffix: isEditing ? null : " Years", // Edit ke waqt 'Years' hat jaye ga
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final n = int.tryParse(value);
                  if (n == null) return 'Enter numbers only';
                  if (n >= 100) return 'Must be less than 100 years';
                  return null;
                },
              ),

              const SizedBox(height: 25),

              if (isEditing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        // Keyboard band karne ke liye
                        final messenger = ScaffoldMessenger.of(context);
                        // 💾 Save to local storage
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('mech_name', nameController.text);
                        await prefs.setString('mech_phone', phoneController.text);
                        await prefs.setString('mech_email', emailController.text);
                        await prefs.setString('mech_workshop', workshopController.text);
                        await prefs.setString('mech_address', addressController.text);
                        await prefs.setString('mech_experience', experienceController.text);
                        
                        if (pickedProfileImage != null) {
                          await prefs.setString('mech_profile_image', pickedProfileImage!.path);
                        }

                        if (mounted) {
                          setState(() {
                            isEditing = false;
                          });
                          messenger.showSnackBar(
                            const SnackBar(backgroundColor: Colors.green, content: Text("Profile Updated Successfully!")),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData icon, 
      {bool isReadOnly = false, required bool isDark, String? Function(String?)? validator, bool isNumber = false, String? suffix}) {
    
    bool canEdit = isEditing && !isReadOnly;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        readOnly: !canEdit,
        validator: validator,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: !canEdit ? (isDark ? Colors.grey[400] : Colors.grey[700]) : (isDark ? Colors.white : Colors.black)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: canEdit ? primaryColor : (isDark ? Colors.grey[600] : Colors.grey[400]), size: 20),
          suffixText: suffix,
          suffixStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          filled: true,
          fillColor: canEdit ? (isDark ? Colors.grey[850] : Colors.white) : (isDark ? Colors.grey[900] : Colors.grey[100]),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          
          errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
          // Error aane par border red ho jaye gi
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        ),
      ),
    );
  }
}