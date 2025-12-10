import 'dart:async';
import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _fadeLogoAnimation;
  late Animation<Offset> _logoSlideAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _fadeTextAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animations
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeLogoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    );

    _logoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ));

    // Text animations
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));

    _fadeTextAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    );

    // Start animations in sequence
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 700), () {
      _textController.forward();
    });

    // Navigate to Onboarding after splash
    Timer(const Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, __, ___) => const OnboardingScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ Full white background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: _logoSlideAnimation,
              child: FadeTransition(
                opacity: _fadeLogoAnimation,
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 220, // ✅ Bigger logo size
                ),
              ),
            ),
            const SizedBox(height: 30),
            SlideTransition(
              position: _textSlideAnimation,
              child: FadeTransition(
                opacity: _fadeTextAnimation,
                child: Column(
                  children: const [
                    Text(
                      'MechConnect',
                      style: TextStyle(
                        fontFamily: 'MontserratAlternates',
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 251, 42, 0),
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Smart Vehicle Assistance',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),
            FadeTransition(
              opacity: _fadeLogoAnimation,
              child: const CircularProgressIndicator(
                color: Color.fromARGB(212, 251, 67, 0),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
