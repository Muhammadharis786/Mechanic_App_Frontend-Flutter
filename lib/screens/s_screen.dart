import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'verify_screen.dart';
import 'authentication/user_session.dart';
import 'homescreen.dart';
import 'mechanic/mechanic_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Timer(const Duration(seconds: 3), () async {
      // 1. Check Login Session
      bool isLoggedIn = await UserSession().loadSession();

      if (!mounted) return;

      if (isLoggedIn) {
        if (UserSession().userType == 'MECHANIC') {
           Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
           );
        } else {
           Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
           );
        }
      } else {
        // 2. Check if First Time User
        final prefs = await SharedPreferences.getInstance();
        bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

        if (isFirstTime) {
          // Go to Onboarding
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        } else {
          // Not first time -> Go straight to Login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VerifyScreen()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFB2A00),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "ONFIX",
                  style: GoogleFonts.luckiestGuy(
                    fontSize: 68,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  "Your Vehicle Our Priority",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
