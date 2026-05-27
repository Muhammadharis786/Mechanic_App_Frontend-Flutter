import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'service_request_map_screen.dart';

class ServiceRequestNotesScreen extends StatefulWidget {
  final String serviceType;
  const ServiceRequestNotesScreen({super.key, required this.serviceType});

  @override
  State<ServiceRequestNotesScreen> createState() => _ServiceRequestNotesScreenState();
}

class _ServiceRequestNotesScreenState extends State<ServiceRequestNotesScreen> {
  final TextEditingController _notesController = TextEditingController();
  final Color primaryColor = const Color(0xFFFB3300);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the problem first.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceRequestMapScreen(
          serviceType: widget.serviceType,
          userNotes: _notesController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Service Request",
          style: TextStyle(
            fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Requesting ${widget.serviceType}',
                style: TextStyle(
                  fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please describe the issue you are facing so the mechanic can better assist you.',
                style: TextStyle(
                  fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _notesController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'e.g. My car is not starting, battery might be dead...',
                  hintStyle: TextStyle(
                    fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                    color: Colors.grey,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
                style: TextStyle(
                  fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
