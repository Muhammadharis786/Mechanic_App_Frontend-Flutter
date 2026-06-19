import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'verify_screen.dart';
import 'mechanic/mechanic_login.dart';
import 'homescreen.dart';
import 'mechanic/mechanic_dashboard.dart';
import 'authentication/user_session.dart';
import '../l10n/app_strings.dart';
import '../services/app_state.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const Color primary = Color(0xFFFB3300);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<Locale>(
      valueListenable: appLanguageController,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    AppStrings.t('appTagline'),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Subtitle
                  Text(
                    AppStrings.t('continueAs'),
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color.fromARGB(221, 223, 222, 222),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Customer Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        bool success = await UserSession().trySwitchTo('USER');
                        if (success) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                            (route) => false,
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const VerifyScreen()),
                          );
                        }
                      },
                      icon: const Icon(Icons.person_outline, color: Colors.white),
                      label: Text(
                        AppStrings.t('customer'),
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
                      onPressed: () async {
                        bool success = await UserSession().trySwitchTo('MECHANIC');
                        if (success) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const MechanicDashboardScreen()),
                            (route) => false,
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MechanicLoginScreen()),
                          );
                        }
                      },
                      icon: Icon(Icons.build_outlined, color: primary),
                      label: Text(
                        AppStrings.t('mechanic'),
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
      },
    );
  }
}
