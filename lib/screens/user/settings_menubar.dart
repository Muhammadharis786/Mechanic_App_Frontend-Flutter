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

  String phoneNumber = "+92 3** ****45";
  String get languageCode => appLanguageController.value.languageCode;

  @override
  Widget build(BuildContext context) {
    return LanguageBuilder(
      builder: (context) {
        final isDark = themeNotifier.value == ThemeMode.dark;

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
                _tile(AppStrings.t('phoneNumber'), phoneNumber, _changePhoneBottomSheet),
                _tile(AppStrings.t('language'), languageCode == 'ur' ? AppStrings.t('urdu') : AppStrings.t('english'), _languageBottomSheet),
                _tile(
                  AppStrings.t('night'),
                  isDark ? AppStrings.t('dark') : AppStrings.t('light'),
                  _themeBottomSheet,
                ),
                const Divider(),
                _tile(AppStrings.t('logout'), null, _logoutDialog, danger: true),
                _tile(AppStrings.t('deleteAccount'), null, _deleteAccountSheet, danger: true),
              ],
            ),
          ),
        );
      },
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
          leading: AppBackButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false,
              );
            },
          ),
          title: Text(
            t("settings"),
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
            _tile(t("phone"), phoneNumber, _changePhoneBottomSheet),
            _tile(t("language"), language, _languageBottomSheet),
            _tile(
              t("night"),
              isDark ? "Dark Theme" : "Light Theme",
              _themeBottomSheet,
            ),
            const Divider(),
            _tile(t("logout"), null, _logoutDialog, danger: true),
            _tile(t("delete"), null, _deleteAccountSheet, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _tile(String title, String? sub, VoidCallback tap, {bool danger = false}) {
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
      trailing: Icon(Icons.arrow_forward_ios_rounded, color: primaryColor, size: 16),
      onTap: tap,
    );
  }

  // ================= PHONE =================
  void _changePhoneBottomSheet() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.t('changeNum'),
                style: const TextStyle(fontFamily: 'Bricolage Grotesque', fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.t('changeSub'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Bricolage Grotesque', fontSize: 13, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixText: "+92 ",
                  prefixStyle: const TextStyle(fontFamily: 'Bricolage Grotesque', color: Colors.black, fontWeight: FontWeight.w400),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: () {
                  setState(() {
                    phoneNumber = "+92 ${controller.text}";
                  });
                  Navigator.pop(context);
                },
                child: Text(AppStrings.t('next')),
              ),
            ],
          ),
        ),
      ),
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

  // ================= THEME =================
  void _themeBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppStrings.t('light')),
              trailing: themeNotifier.value == ThemeMode.light
                  ? Icon(Icons.check_rounded, color: primaryColor)
                  : null,
              onTap: () {
                themeNotifier.setLight();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(AppStrings.t('dark')),
              trailing: themeNotifier.value == ThemeMode.dark
                  ? Icon(Icons.check, color: primaryColor)
                  : null,
              onTap: () {
                themeNotifier.setDark();
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
            content: Text(AppStrings.t('errorGeneric', {'msg': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
