import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mech_app/screens/authentication/user_session.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  final ImagePicker _picker = ImagePicker();

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscurePassword = true;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Image state
  String _imageUrl = '';
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ===== LOAD PROFILE FROM BACKEND =====
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);  
    try {
      final url = Uri.parse(
        'https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/dashboard',
      );
      final response = await http.get(url, headers: UserSession().getAuthHeader());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'] ?? data;
        if (user != null) {
          setState(() {
            _nameController.text = user['username'] ?? '';
            _phoneController.text = user['phonenumber'] ?? '';
            _emailController.text = user['email'] ?? '';
            _imageUrl = user['userimgurl'] ?? '';
            _pickedImage = null;
            _pickedImageBytes = null;
          });
        }
      } else {
        _showSnack('Failed to load profile (${response.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('Error loading profile: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ===== PICK IMAGE =====
  Future<void> _pickImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _pickedImage = img;
      _pickedImageBytes = bytes;
    });
  }

  // ===== SAVE PROFILE =====
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    
    if (_pickedImage == null && _imageUrl.isEmpty) {
      setState(() => _isSaving = false);
      _showSnack('Please select a profile image', isError: true);
      return;
    }

    try {
      final uri = Uri.parse(
        'https://mechanicapp-service-621632382478.asia-south1.run.app/api/save/user/userimage',
      );

      var request = http.MultipartRequest('PUT', uri);
      request.headers.addAll(UserSession().getAuthHeader());

      final Map<String, dynamic> userData = {
        'username': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      };
      if (_passwordController.text.isNotEmpty) {
        userData['password'] = _passwordController.text;
      } else {
        userData['password'] = UserSession().password;
      }
      if (_pickedImage == null && _imageUrl.isNotEmpty) {
        userData['userimgurl'] = _imageUrl;
      }

      request.files.add(http.MultipartFile.fromString(
        'userdata',
        jsonEncode(userData),
        contentType: MediaType('application', 'json'),
      ));

      if (_pickedImage != null) {
        if (kIsWeb) {
          final bytes = await _pickedImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'userimage',
            bytes,
            filename: _pickedImage!.name.isNotEmpty ? _pickedImage!.name : 'profile.jpg',
            contentType: MediaType('image', 'jpeg'),
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'userimage',
            _pickedImage!.path,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      String message;
      try {
        final body = jsonDecode(response.body);
        message = body['message'] ?? body['error'] ?? response.body;
        if (body['userimage'] != null) {
          setState(() => _imageUrl = body['userimage']);
        }
      } catch (_) {
        message = response.body.isNotEmpty
            ? response.body
            : (response.statusCode == 200 ? 'Profile updated!' : 'Update failed');
      }

      if (response.statusCode == 200) {
        setState(() {
          _isEditing = false;
          _pickedImage = null;
          _pickedImageBytes = null;
        });
        _passwordController.clear();
        _showSnack(message, isError: false);
      } else {
        _showSnack(message, isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _passwordController.clear();
        _pickedImage = null;
        _pickedImageBytes = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey.shade700;
    // ignore: unused_local_variable
    final fieldBgColor = isDark ? Colors.grey[900] : Colors.white;
    // ignore: unused_local_variable
    final disabledBgColor = isDark ? Colors.grey[800] : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600),
        ),
        backgroundColor: bgColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.deepOrange, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit, color: primaryColor),
              onPressed: _toggleEdit,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.grey.shade700,
                            backgroundImage: _pickedImageBytes != null
                                ? MemoryImage(_pickedImageBytes!)
                                : (_imageUrl.startsWith('http')
                                    ? NetworkImage(_imageUrl)
                                    : const AssetImage('assets/images/user.jpg'))
                                    as ImageProvider,
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_isEditing && _pickedImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '✓ New image selected — will upload on Save',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.green),
                        ),
                      ),
                    const SizedBox(height: 30),
                    _buildField('Full Name', _nameController, Icons.person_outline, isDark: isDark),
                    const SizedBox(height: 20),
                    _buildField('Phone Number', _phoneController, Icons.phone_outlined, isPhone: true, alwaysDisabled: true, isDark: isDark),
                    const SizedBox(height: 20),
                    _buildField('Email (Optional)', _emailController, Icons.email_outlined, isEmail: true, isDark: isDark),
                    const SizedBox(height: 20),
                    if (_isEditing) ...[
                      _buildPasswordField(isDark),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Leave blank to keep current password',
                          style: GoogleFonts.poppins(fontSize: 11, color: subTextColor),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'Save Changes',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon,
      {bool isPhone = false, bool isEmail = false, bool alwaysDisabled = false, required bool isDark}) {
    final textColor = alwaysDisabled ? (isDark ? Colors.grey[400] : Colors.black54) : (isDark ? Colors.white : Colors.black87);
    final prefixColor = (_isEditing && !alwaysDisabled) ? primaryColor : (isDark ? Colors.grey[400] : Colors.grey);
    final fillColor = alwaysDisabled ? (isDark ? Colors.grey[800] : Colors.grey.shade100) : (isDark ? Colors.grey[900] : Colors.white);
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[400] : Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: alwaysDisabled ? false : _isEditing,
          keyboardType: isPhone
              ? TextInputType.phone
              : isEmail
                  ? TextInputType.emailAddress
                  : TextInputType.text,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: prefixColor),
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Password',
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[400] : Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[900] : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
          ),
        ),
      ],
    );
  }
}