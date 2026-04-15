import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/main.dart';
import '../authentication/user_session.dart';
import '../role_selection_screen.dart';

class MechanicSettingsScreen extends StatefulWidget {
  const MechanicSettingsScreen({super.key});

  @override
  State<MechanicSettingsScreen> createState() => _MechanicSettingsScreenState();
}

class _MechanicSettingsScreenState extends State<MechanicSettingsScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  String language = "English";

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔹 Theme Options
  void _showThemeOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("Light Mode"),
                trailing: !isDarkMode ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  themeNotifier.setLight();
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
              ListTile(
                title: const Text("Dark Mode"),
                trailing: isDarkMode ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  themeNotifier.setDark();
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔹 Language Options
  void _showLanguageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("English"),
                trailing: language == "English" ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() => language = "English");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text("Urdu"),
                trailing: language == "Urdu" ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() => language = "Urdu");
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }


  // 🔹 Logout
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(context); // close dialog
              
              // ✅ Firebase logout
              await _auth.signOut();

              // ✅ Clear local session
              await UserSession().logout();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              // ✅ Navigate to role selection / login
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 🔹 Delete Account (optional, same pattern)
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("This action cannot be undone!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(context);
              await _auth.currentUser?.delete();
              await UserSession().logout();
              nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (route) => false);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(String title, String subtitle, Function() onTap, bool isDark) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      title: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTile("Language", language, _showLanguageOptions, isDarkMode),
          _buildTile("Night Mode", isDarkMode ? "Dark Theme" : "Light Theme", _showThemeOptions, isDarkMode),
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            title: Text("Logout", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w500)),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
            onTap: _confirmLogout,
          ),
          ListTile(
            title: Text("Delete Account", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w500)),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }
}