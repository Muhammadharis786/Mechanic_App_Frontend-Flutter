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
  int? _userId;

  @override
  void initState() {
    super.initState();
    // Pre-fill from session
    _nameController.text = ""; 
    _phoneController.text = UserSession().email ?? '';
    _emailController.text = UserSession().email ?? '';
    _passwordController.text = UserSession().password ?? '';
    _userId = UserSession().userId;
    
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
            _userId = user['userid'] ?? user['id'] ?? UserSession().userId;
            
            // Handle password if returned, else keep session one
            if (user['password'] != null && user['password'].toString().isNotEmpty) {
               _passwordController.text = user['password'];
            } else {
               _passwordController.text = UserSession().password ?? '';
            }
            
            _pickedImage = null;
            _pickedImageBytes = null;
          });
          
          if (_userId != null) {
            UserSession().setUserId(_userId!);
          }
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

  // ===== PICK IMAGE (just preview, no upload yet) =====
  Future<void> _pickImage() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _pickedImage = img;
      _pickedImageBytes = bytes;
    });
  }

  // ===== SAVE ALL — one multipart request (like mechanic registration) =====
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    
    try {
      final uri = Uri.parse(
        'https://mechanicapp-service-621632382478.asia-south1.run.app/api/save/user/userimage',
      );

      var request = http.MultipartRequest('PUT', uri);
      request.headers.addAll(UserSession().getAuthHeader());

      // 1. userData JSON part (Send EVERYTHING according to UserDto)
      final Map<String, dynamic> userData = {
        'userid': _userId ?? UserSession().userId,
        'username': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text, // Always send password
        'userimgurl': _imageUrl, // Current URL (backend updates this if new image uploaded)
      };

      request.files.add(http.MultipartFile.fromString(
        'userdata',
        jsonEncode(userData),
        contentType: MediaType('application', 'json'),
      ));

      // 2. userimage file part - ALWAYS added because backend `@RequestPart` is required
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
      } else if (_imageUrl.isNotEmpty && _imageUrl.startsWith('http')) {
        // If no new image, download current image to satisfy backend's mandatory requirement
        try {
          final response = await http.get(Uri.parse(_imageUrl));
          if (response.statusCode == 200) {
            request.files.add(http.MultipartFile.fromBytes(
              'userimage',
              response.bodyBytes,
              filename: 'existing_profile.jpg',
              contentType: MediaType('image', 'jpeg'),
            ));
          }
        } catch (e) {
          debugPrint('Failed to fetch existing image: $e');
          // Fallback to empty part if download fails
          request.files.add(http.MultipartFile.fromBytes(
            'userimage',
            [],
            filename: 'empty.jpg',
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      } else {
        // Fallback for no image whatsoever
        request.files.add(http.MultipartFile.fromBytes(
          'userimage',
          [],
          filename: 'empty.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      // 3. Send
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      // Parse backend message
      String message;
      try {
        final body = jsonDecode(response.body);
        message = body['message'] ?? body['error'] ?? response.body;
        if (body['userimage'] != null) {
          setState(() => _imageUrl = body['userimage']);
        }
        
        // Update Session if name or password changed
        if (response.statusCode == 200) {
           await UserSession().saveSession(
             UserSession().email!, 
             _passwordController.text, 
             'USER'
           );
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
        content: Text(msg,
            style: const TextStyle(
                fontFamily: 'Bricolage Grotesque',
                color: Colors.white,
                fontWeight: FontWeight.w400)),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ===== INDIVIDUAL UPDATE DIALOG =====
  void _showUpdateDialog(String title, String label, TextEditingController controller, {bool isPassword = false, bool isEmail = false}) {
    final TextEditingController tempController = TextEditingController(text: isPassword ? "" : controller.text);
    bool obscureTemp = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tempController,
                obscureText: isPassword ? obscureTemp : false,
                keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: GoogleFonts.poppins(fontSize: 14),
                  suffixIcon: isPassword 
                    ? IconButton(
                        icon: Icon(obscureTemp ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setDialogState(() => obscureTemp = !obscureTemp),
                      )
                    : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (isPassword && tempController.text.isEmpty) {
                   _showSnack("Password cannot be empty", isError: true);
                   return;
                }
                setState(() {
                  controller.text = tempController.text;
                });
                Navigator.pop(context);
                _saveProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Update', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.poppins(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFFB3300),
            size: 18,
          ),
          splashRadius: 20,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ===== PROFILE IMAGE =====
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: primaryColor, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _pickedImageBytes != null
                                    ? MemoryImage(_pickedImageBytes!)
                                    : (_imageUrl.startsWith('http')
                                        ? NetworkImage(_imageUrl)
                                        : const AssetImage('assets/images/user.jpg'))
                                        as ImageProvider,
                              ),
                            ),
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: GestureDetector(
                                onTap: _pickImageAndSave,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 35),

                      // ===== PROFILE TILES =====
                      _buildProfileTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Full Name',
                        value: _nameController.text,
                        onTap: () => _showUpdateDialog('Update Name', 'Enter your name', _nameController),
                        isDark: isDark,
                      ),
                      _buildProfileTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                        value: _phoneController.text,
                        onTap: null, // No change for phone
                        isDark: isDark,
                        showChange: false,
                      ),
                      _buildProfileTile(
                        icon: Icons.email_outlined,
                        label: 'Email Address',
                        value: _emailController.text.isEmpty ? 'Not set' : _emailController.text,
                        onTap: () => _showUpdateDialog('Update Email', 'Enter your email', _emailController, isEmail: true),
                        isDark: isDark,
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
                if (_isSaving)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Future<void> _pickImageAndSave() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _pickedImage = img;
      _pickedImageBytes = bytes;
    });
    _saveProfile();
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback? onTap,
    required bool isDark,
    bool showChange = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryColor, size: 22),
        ),
        title: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: showChange
            ? TextButton(
                onPressed: onTap,
                child: Text(
                  'Change',
                  style: GoogleFonts.poppins(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
