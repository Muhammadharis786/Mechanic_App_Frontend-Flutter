import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/main.dart';
import '../authentication/user_session.dart';
import '../role_selection_screen.dart';
import '../../widgets/app_back_button.dart';
import '../../services/app_state.dart';
import '../../l10n/app_strings.dart';
import '../../services/mechanic_presence_service.dart';
import '../../services/mechanic_notification_controller.dart';
import '../../services/mechanic_live_location_service.dart';
import 'mechanic_subscription_screen.dart';

class MechanicSettingsScreen extends StatefulWidget {
  const MechanicSettingsScreen({super.key});

  @override
  State<MechanicSettingsScreen> createState() => _MechanicSettingsScreenState();
}

class _MechanicSettingsScreenState extends State<MechanicSettingsScreen> {
  final Color primaryColor = const Color(0xFFFB3300);
  String get languageCode => appLanguageController.value.languageCode;

  final FirebaseAuth _auth = FirebaseAuth.instance;

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
                title: Text(AppStrings.t('english')),
                trailing: languageCode == 'en' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  appLanguageController.setEnglish();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(AppStrings.t('urdu')),
                trailing: languageCode == 'ur' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  appLanguageController.setUrdu();
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
        title: Text(AppStrings.t('logout')),
        content: Text(AppStrings.t('logoutConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.t('cancel'))),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(context); // close dialog
              final currentThemeMode = themeNotifier.value == ThemeMode.dark ? 'dark' : 'light';
              final currentLanguageCode = appLanguageController.value.languageCode;

              // Stop online presence / heartbeat before logout
              await MechanicPresenceService.instance.updateOnlineStatus(false);
              MechanicNotificationController().dispose();
              await MechanicLiveLocationService.instance.stop();

              // ✅ Firebase logout
              await _auth.signOut();

              // ✅ Clear local session
              await UserSession().logout();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await prefs.setString('app_theme_mode', currentThemeMode);
              await prefs.setString('app_language_code', currentLanguageCode);

              // ✅ Navigate to role selection / login
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
            child: Text(AppStrings.t('logout'), style: const TextStyle(color: Colors.red)),
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
        title: Text(AppStrings.t('deleteAccount')),
        content: Text(AppStrings.t('deleteConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppStrings.t('cancel'))),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(context);
              await MechanicPresenceService.instance.updateOnlineStatus(false);
              MechanicNotificationController().dispose();
              await MechanicLiveLocationService.instance.stop();
              await _auth.currentUser?.delete();
              await UserSession().logout();
              nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (route) => false);
            },
            child: Text(AppStrings.t('deleteBtn'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(String title, String? subtitle, Function() onTap, bool isDark, {bool showArrow = true, Widget? trailing}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      title: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
      subtitle: subtitle != null ? Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey)) : null,
      trailing: trailing ?? (showArrow ? Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor) : null),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: languageNotifier,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            final isDarkMode = currentMode == ThemeMode.dark;

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  AppStrings.t('settings'),
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                leading: const AppBackButton(),
                iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTile(
                    AppStrings.t('language'),
                    locale.languageCode == 'ur' ? AppStrings.t('urdu') : AppStrings.t('english'),
                    _showLanguageOptions,
                    isDarkMode,
                  ),
                  _buildTile(
                    'Subscription Plan',
                    'Free Tier', // You can fetch this dynamically in future
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MechanicSubscriptionScreen(),
                        ),
                      );
                    },
                    isDarkMode,
                    trailing: const Icon(Icons.workspace_premium, color: Color(0xFFFB3300), size: 24),
                  ),
                  _buildTile(
                    'Theme',
                    null,
                    () {
                      if (isDarkMode) {
                        themeNotifier.setLight();
                      } else {
                        themeNotifier.setDark();
                      }
                      setState(() {});
                    },
                    isDarkMode,
                    showArrow: false,
                    trailing: Icon(
                      isDarkMode ? Icons.nights_stay : Icons.nights_stay_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    title: Text(
                      AppStrings.t('logout'),
                      style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
                    onTap: _confirmLogout,
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    title: Text(
                      AppStrings.t('deleteAccount'),
                      style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
                    onTap: _confirmDelete,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
