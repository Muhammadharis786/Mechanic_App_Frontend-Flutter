import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Single, unified animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Shorter, smoother duration
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // Start animation immediately
    _animationController.forward();

    // Navigate after splash (adjusted to 3 seconds total)
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const OnboardingScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 251, 42, 0), // BG Color
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
              "ONFIX",
              style: GoogleFonts.luckiestGuy(   // <-- Google Font applied
                fontSize: 72,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
      ),
    );
  }
}