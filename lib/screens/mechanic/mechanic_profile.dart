import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../authentication/user_session.dart';

class MechanicProfileScreen extends StatefulWidget {
  const MechanicProfileScreen({super.key});

  @override
  State<MechanicProfileScreen> createState() => _MechanicProfileScreenState();
}

class _MechanicProfileScreenState extends State<MechanicProfileScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

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
    _addressController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  // ===== LOAD PROFILE =====
  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        'https://mechanicapp-service-621632382478.asia-south1.run.app/api/mechanic/showprofile',
      );
      final response = await http.get(url, headers: UserSession().getAuthHeader());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _nameController.text = data['username'] ?? '';
            _phoneController.text = data['phonenumber'] ?? '';
            _addressController.text = data['shopaddress'] ?? '';
            _experienceController.text = (data['experience'] ?? 0).toString();
            _imageUrl = data['mechanicimage'] ?? '';
            
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===== SAVE PROFILE (Multipart) =====
  Future<void> _saveProfile() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final uri = Uri.parse(
        'https://mechanicapp-service-621632382478.asia-south1.run.app/api/save/mechanic/userimage',
      );

      var request = http.MultipartRequest('PUT', uri);
      request.headers.addAll(UserSession().getAuthHeader());

      // 1. mechanicdata JSON part
      final Map<String, dynamic> mechanicData = {
        'name': _nameController.text.trim(),
        'shopaddress': _addressController.text.trim(),
        'experience': int.tryParse(_experienceController.text.trim()) ?? 0,
        'mechurl': _imageUrl,
      };

      request.files.add(http.MultipartFile.fromString(
        'mechanicdata',
        jsonEncode(mechanicData),
        contentType: MediaType('application', 'json'),
      ));

      // 2. mechanicimage file part
      if (_pickedImage != null) {
        if (kIsWeb) {
          final bytes = await _pickedImage!.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'mechanicimage',
            bytes,
            filename: _pickedImage!.name.isNotEmpty ? _pickedImage!.name : 'profile.jpg',
            contentType: MediaType('image', 'jpeg'),
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'mechanicimage',
            _pickedImage!.path,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      } else if (_imageUrl.isNotEmpty && _imageUrl.startsWith('http')) {
        try {
          final response = await http.get(Uri.parse(_imageUrl));
          if (response.statusCode == 200) {
            request.files.add(http.MultipartFile.fromBytes(
              'mechanicimage',
              response.bodyBytes,
              filename: 'existing_profile.jpg',
              contentType: MediaType('image', 'jpeg'),
            ));
          }
        } catch (e) {
          debugPrint('Failed to fetch existing image: $e');
          request.files.add(http.MultipartFile.fromBytes(
            'mechanicimage',
            [],
            filename: 'empty.jpg',
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      } else {
        request.files.add(http.MultipartFile.fromBytes(
          'mechanicimage',
          [],
          filename: 'empty.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        try {
          // Handle both JSON and plain text responses
          if (response.body.isNotEmpty) {
            if (response.body.trim().startsWith('{')) {
              final body = jsonDecode(response.body);
              if (mounted) {
                if (body['mechanicimage'] != null) {
                  setState(() => _imageUrl = body['mechanicimage']);
                }
              }
            }
          }
          if (mounted) {
            setState(() {
              _pickedImage = null;
              _pickedImageBytes = null;
            });
          }
          _showSnack('Profile updated successfully!', isError: false);
        } catch (e) {
          // Fallback if parsing fails but status is 200
          debugPrint("Parse error but success status: $e");
          if (mounted) {
            setState(() {
              _pickedImage = null;
              _pickedImageBytes = null;
            });
          }
          _showSnack('Profile updated successfully!', isError: false);
        }
      } else {
        String errorMsg = 'Update failed';
        try {
          final body = jsonDecode(response.body);
          errorMsg = body['message'] ?? body['error'] ?? 'Update failed';
        } catch (_) {
          errorMsg = response.body.isNotEmpty ? response.body : 'Update failed';
        }
        _showSnack(errorMsg, isError: true);
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // ===== PICK IMAGE =====
  Future<void> _pickImageAndSave() async {
    final XFile? img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = img;
      _pickedImageBytes = bytes;
    });
    _saveProfile();
  }

  // ===== UPDATE DIALOG =====
  void _showUpdateDialog(String title, String label, TextEditingController controller, {bool isNumeric = false, int maxLines = 1}) {
    final TextEditingController tempController = TextEditingController(text: controller.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: tempController,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  controller.text = tempController.text;
                });
              }
              Navigator.pop(context);
              _saveProfile();
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text('Update', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Mechanic Profile',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Profile Image
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
                                radius: 60,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _pickedImageBytes != null
                                    ? MemoryImage(_pickedImageBytes!)
                                    : (_imageUrl.isNotEmpty && _imageUrl.startsWith('http')
                                        ? NetworkImage(_imageUrl)
                                        : const AssetImage('assets/images/user.jpg')) as ImageProvider,
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
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Profile Fields
                      _buildProfileTile(
                        icon: Icons.person,
                        label: 'Full Name',
                        value: _nameController.text,
                        onTap: () => _showUpdateDialog('Update Name', 'Enter your name', _nameController),
                        isDark: isDark,
                      ),
                      _buildProfileTile(
                        icon: Icons.phone,
                        label: 'Phone Number',
                        value: _phoneController.text,
                        onTap: null, 
                        showChange: false,
                        isDark: isDark,
                      ),
                      _buildProfileTile(
                        icon: Icons.location_on,
                        label: 'Workshop Address',
                        value: _addressController.text.isEmpty ? 'Not set' : _addressController.text,
                        onTap: () => _showUpdateDialog('Update Address', 'Enter workshop address', _addressController, maxLines: 2),
                        isDark: isDark,
                      ),
                      _buildProfileTile(
                        icon: Icons.history,
                        label: 'Experience (Years)',
                        value: '${_experienceController.text} Years',
                        onTap: () => _showUpdateDialog('Update Experience', 'Enter years of experience', _experienceController, isNumeric: true),
                        isDark: isDark,
                      ),
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
            color: Colors.black.withOpacity(0.05),
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
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryColor, size: 22),
        ),
        title: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        subtitle: Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        trailing: showChange
            ? TextButton(
                onPressed: onTap,
                child: Text('Change', style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.bold)),
              )
            : null,
      ),
    );
  }
}