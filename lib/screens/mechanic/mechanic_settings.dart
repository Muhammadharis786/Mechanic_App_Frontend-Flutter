import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicSettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const MechanicSettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<MechanicSettingsScreen> createState() =>
      _MechanicSettingsScreenState();
}

class _MechanicSettingsScreenState extends State<MechanicSettingsScreen> {
  late bool _isDarkMode;

  final Color primaryColor = const Color(0xFFFB3300);

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
    widget.onThemeChanged(value); // Notify parent to update theme
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dark Mode Toggle Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Switch to Dark Mode',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Switch(
                  value: _isDarkMode,
                  activeColor: primaryColor,
                  onChanged: _toggleTheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}