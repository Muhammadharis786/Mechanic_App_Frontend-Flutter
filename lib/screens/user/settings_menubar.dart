import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mech_app/main.dart';
import 'package:mech_app/screens/homescreen.dart';
import 'package:mech_app/screens/role_selection_screen.dart';
import 'package:mech_app/screens/authentication/user_session.dart';
import 'package:mech_app/services/user_notification_controller.dart';
import 'package:mech_app/services/app_state.dart';
import 'package:mech_app/l10n/app_strings.dart';
import 'package:mech_app/widgets/app_back_button.dart';

class SettingsMenuBar extends StatefulWidget {
  const SettingsMenuBar({super.key});

  @override
  State<SettingsMenuBar> createState() => _SettingsMenuBarState();
}

class _SettingsMenuBarState extends State<SettingsMenuBar> {
  final Color primaryColor = const Color(0xFFFB3300);

  late String phoneNumber;
  String get languageCode => appLanguageController.value.languageCode;

  @override
  void initState() {
    super.initState();
    phoneNumber = UserSession().email ?? '';
    _loadPhoneNumber();
  }

  Future<void> _loadPhoneNumber() async {
    try {
      final url = Uri.parse(
        'https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/dashboard',
      );
      final response = await http.get(url, headers: UserSession().getAuthHeader());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'] ?? data;
        if (user != null && user['phonenumber'] != null && user['phonenumber'].toString().isNotEmpty) {
          setState(() {
            phoneNumber = user['phonenumber'].toString();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading phone number: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: languageNotifier,
      builder: (context, locale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, currentMode, _) {
            final isDark = currentMode == ThemeMode.dark;

            return WillPopScope(
              onWillPop: () async {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (_) => false,
                );
                return false;
              },
              child: Scaffold(
                backgroundColor: isDark ? Colors.black : Colors.white,
                appBar: AppBar(
                  backgroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFFB3300), size: 22),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (_) => false,
                      );
                    },
                  ),
                  title: Text(
                    AppStrings.t('settings'),
                    style: TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                    ),
                  ),
                ),
                body: Column(
                  children: [
                    _tile(AppStrings.t('phoneNumber'), phoneNumber, null, showArrow: false),
                    _tile(AppStrings.t('language'), locale.languageCode == 'ur' ? AppStrings.t('urdu') : AppStrings.t('english'), _languageBottomSheet),
                    _tile(
                      'Theme',
                      null,
                      () {
                        if (isDark) {
                          themeNotifier.setLight();
                        } else {
                          themeNotifier.setDark();
                        }
                      },
                      showArrow: false,
                      trailing: Icon(
                        isDark ? Icons.nights_stay : Icons.nights_stay_outlined,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const Divider(),
                    _tile(AppStrings.t('logout'), null, _logoutDialog, danger: true),
                    _tile(AppStrings.t('deleteAccount'), null, _deleteAccountSheet, danger: true),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _tile(String title, String? sub, VoidCallback? tap, {bool danger = false, bool showArrow = true, Widget? trailing}) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Bricolage Grotesque',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: danger
              ? Colors.red
              : isDark
                  ? Colors.white
                  : Colors.black,
        ),
      ),
      subtitle: sub != null
          ? Text(
              sub,
              style: TextStyle(
                fontFamily: 'Bricolage Grotesque',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            )
          : null,
      trailing: trailing ?? (showArrow ? Icon(Icons.arrow_forward_ios_rounded, color: primaryColor, size: 16) : null),
      onTap: tap,
    );
  }

  // ================= LANGUAGE =================
  void _languageBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppStrings.t('english')),
              trailing: languageCode == 'en'
                  ? Icon(Icons.check_rounded, color: primaryColor)
                  : null,
              onTap: () {
                appLanguageController.setEnglish();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(AppStrings.t('urdu')),
              trailing: languageCode == 'ur'
                  ? Icon(Icons.check_rounded, color: primaryColor)
                  : null,
              onTap: () {
                appLanguageController.setUrdu();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= LOGOUT =================
  void _logoutDialog() {
    final isDark = themeNotifier.value == ThemeMode.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? Colors.black : Colors.white,
        title: Text(
          AppStrings.t('logout'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          AppStrings.t('logoutQ'),
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              UserNotificationController().dispose();
              await UserSession().logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                  (_) => false,
                );
              }
            },
            child: Text(AppStrings.t('yes')),
          ),
        ],
      ),
    );
  }

  // ================= DELETE ACCOUNT =================
  void _deleteAccountSheet() {
    final isDark = themeNotifier.value == ThemeMode.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(
              AppStrings.t('deleteQ'),
              style: TextStyle(
                fontFamily: 'Bricolage Grotesque',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        content: Text(
          AppStrings.t('deleteSub'),
          style: TextStyle(
            fontFamily: 'Bricolage Grotesque',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.t('cancel'),
              style: TextStyle(
                fontFamily: 'Bricolage Grotesque',
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _performDeleteAccount(),
            child: Text(
              AppStrings.t('deleteBtn'),
              style: const TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount() async {
    final userId = UserSession().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('userIdNotFound'))),
      );
      return;
    }

    // Close the dialog first
    Navigator.pop(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.red),
      ),
    );

    try {
      final url = Uri.parse(
        "https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/delete/$userId",
      );

      final response = await http.delete(
        url,
        headers: UserSession().getAuthHeader(),
      );

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Parse backend message from response body
      String backendMessage;
      try {
        final body = jsonDecode(response.body);
        backendMessage = body['message'] ??
            body['error'] ??
            body.toString();
      } catch (_) {
        backendMessage = response.body.isNotEmpty
            ? response.body
            : (response.statusCode == 200 || response.statusCode == 204
                ? "Account deleted successfully"
                : "Failed to delete account (${response.statusCode})");
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Show green success SnackBar BEFORE navigating
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                backendMessage,
                style: const TextStyle(fontFamily: 'Bricolage Grotesque', color: Colors.white, fontWeight: FontWeight.w400),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await Future.delayed(const Duration(seconds: 2));

        // Clear session data
        await UserSession().logout();

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
            (_) => false,
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                backendMessage,
                style: const TextStyle(fontFamily: 'Bricolage Grotesque', color: Colors.white, fontWeight: FontWeight.w400),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
