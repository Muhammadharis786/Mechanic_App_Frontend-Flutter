import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  bool _isEditing = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController(text: "Ali Khan");
  final TextEditingController _phoneController = TextEditingController(text: "03001234567");
  final TextEditingController _addressController = TextEditingController(text: "Shop #12, Mechanic Market, Karachi");
  final TextEditingController _emailController = TextEditingController(text: "alikhan@example.com");

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveProfile() {
    // Here you would typically save data to API or SharedPreferences
    setState(() {
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile Saved Successfully!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "My Profile",
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: primaryColor),
              onPressed: _toggleEdit,
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Image
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: const AssetImage('assets/images/user.jpg'),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
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
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildField("Full Name", _nameController, Icons.person_outline),
            const SizedBox(height: 20),
            _buildField("Phone Number", _phoneController, Icons.phone_outlined, isPhone: true),
            const SizedBox(height: 20),
            _buildField("Shop Address", _addressController, Icons.store_outlined, maxLines: 2),
             const SizedBox(height: 20),
            _buildField("Email (Optional)", _emailController, Icons.email_outlined),

            const SizedBox(height: 40),

            if (_isEditing)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    "Save Changes",
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon,
      {bool isPhone = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: _isEditing,
          maxLines: maxLines,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _isEditing ? primaryColor : Colors.grey),
            filled: true,
            fillColor: _isEditing ? Colors.white : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }
}
