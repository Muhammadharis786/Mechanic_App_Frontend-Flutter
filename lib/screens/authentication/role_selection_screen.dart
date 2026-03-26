import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../verify_screen.dart';
import '../mechanic/mechanic_login.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const Color primary = Color(0xFFFB3300);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo / Title
              Text(
                "ONFIX",
                style: GoogleFonts.luckiestGuy(
                  fontSize: 52,
                  color: primary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your Vehicle Our Priority",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),

              const Spacer(flex: 2),

              // Subtitle
              Text(
                "Continue As",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color.fromARGB(248, 223, 220, 220),
                ),
              ),
              const SizedBox(height: 30),

              // Customer Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VerifyScreen()),
                    );
                  },
                  icon: const Icon(Icons.person_outline, color: Colors.white),
                  label: Text(
                    "Customer",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mechanic Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MechanicLoginScreen()),
                    );
                  },
                  icon: Icon(Icons.build_outlined, color: primary),
                  label: Text(
                    "Mechanic",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
