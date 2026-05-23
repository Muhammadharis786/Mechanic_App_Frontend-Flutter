import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection_screen.dart';
import 'authentication/user_session.dart';
import 'homescreen.dart';
import 'mechanic/mechanic_dashboard.dart';
import '../services/fcm_notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _shutterController;

  final String _logoText = "ONFIX";
  final String _taglineText = "Your Vehicle Our Priority";

  @override
  void initState() {
    super.initState();

    // 1️⃣ Entrance Controller (Character Drop)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // 2️⃣ Shutter Controller (Diagonal Slide)
    _shutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _entranceController.forward();

    // Trigger Shutter and Navigation
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _shutterController.forward().then((_) => _navigateNext());
      }
    });
  }

  Future<void> _navigateNext() async {
    bool isLoggedIn = await UserSession().loadSession();
    if (!mounted) return;

    if (isLoggedIn) {
      await FcmNotificationService.instance.syncTokenWithBackend();
      if (!mounted) return;

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
      final prefs = await SharedPreferences.getInstance();
      bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
      if (!mounted) return;

      if (isFirstTime) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shutterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🔴 LAYER 1: Red Background with White Text
          _buildContentLayer(
            backgroundColor: const Color(0xFFFB2A00),
            textColor: Colors.white,
            taglineColor: Colors.white70,
          ),

          // ⚪ LAYER 2: White Shutter with Red Text (Diagonal Clip)
          AnimatedBuilder(
            animation: _shutterController,
            builder: (context, child) {
              return ClipPath(
                clipper: SlantedShutterClipper(_shutterController.value),
                child: _buildContentLayer(
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFFFB2A00),
                  taglineColor: Colors.grey.withValues(alpha: 0.8),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContentLayer({
    required Color backgroundColor,
    required Color textColor,
    required Color taglineColor,
  }) {
    return Container(
      color: backgroundColor,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // LOGO (Character Drop)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_logoText.length, (index) {
                return _CharacterDrop(
                  text: _logoText[index],
                  controller: _entranceController,
                  index: index,
                  totalItems: _logoText.length,
                  color: textColor,
                );
              }),
            ),

            const SizedBox(height: 12),

            // TAGLINE
            FadeTransition(
              opacity: CurvedAnimation(
                parent: _entranceController,
                curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
              ),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _entranceController,
                        curve: const Interval(
                          0.6,
                          1.0,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                    ),
                child: Text(
                  _taglineText,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: taglineColor,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterDrop extends StatelessWidget {
  final String text;
  final AnimationController controller;
  final int index;
  final int totalItems;
  final Color color;

  const _CharacterDrop({
    required this.text,
    required this.controller,
    required this.index,
    required this.totalItems,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double start = (index / totalItems) * 0.5;
    final double end = start + 0.3;

    final Animation<double> fade = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeIn),
    );

    final Animation<Offset> slide =
        Tween<Offset>(begin: const Offset(0, -1.8), end: Offset.zero).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(start, end, curve: Curves.bounceOut),
          ),
        );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Text(
          text,
          style: GoogleFonts.luckiestGuy(
            fontSize: 72,
            color: color,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class SlantedShutterClipper extends CustomClipper<Path> {
  final double progress;

  SlantedShutterClipper(this.progress);

  @override
  Path getClip(Size size) {
    // Top-Left to Bottom-Right diagonal sweep
    double totalDistance = size.width + size.height;
    double currentLimit = totalDistance * progress;

    Path path = Path();
    if (progress <= 0) return path;
    if (progress >= 1) {
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      return path;
    }

    path.moveTo(0, 0);
    if (currentLimit <= size.width) {
      path.lineTo(currentLimit, 0);
    } else {
      path.lineTo(size.width, 0);
      path.lineTo(size.width, currentLimit - size.width);
    }

    if (currentLimit <= size.height) {
      path.lineTo(0, currentLimit);
    } else {
      path.lineTo(currentLimit - size.height, size.height);
      path.lineTo(0, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(SlantedShutterClipper oldClipper) =>
      oldClipper.progress != progress;
}
