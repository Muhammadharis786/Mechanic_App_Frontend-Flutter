import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mech_app/main.dart';
import 'package:mech_app/screens/homescreen.dart';
import 'package:mech_app/screens/verify_screen.dart';

class SettingsMenuBar extends StatefulWidget {
  const SettingsMenuBar({super.key});

  @override
  State<SettingsMenuBar> createState() => _SettingsMenuBarState();
}

class _SettingsMenuBarState extends State<SettingsMenuBar> {
  final Color primaryColor = const Color(0xFFFB3300);

  String phoneNumber = "+92 3** ****45";
  String language = "English";

  final Map<String, Map<String, String>> text = {
    "English": {
      "settings": "Settings",
      "phone": "Phone Number",
      "language": "Language",
      "night": "Night Mode",
      "logout": "Logout",
      "delete": "Delete Account",
      "changeNum": "Change Number?",
      "changeSub": "Your account and data will be linked to this new number",
      "next": "Next",
      "logoutQ": "Do you want to log out?",
      "deleteQ": "Delete Account?",
      "deleteSub": "All data associated with your account will be erased",
    },
    "Urdu": {
      "settings": "سیٹنگز",
      "phone": "فون نمبر",
      "language": "زبان",
      "night": "نائٹ موڈ",
      "logout": "لاگ آؤٹ",
      "delete": "اکاؤنٹ ڈیلیٹ کریں",
      "changeNum": "نمبر تبدیل کریں؟",
      "changeSub": "آپ کا اکاؤنٹ اور ڈیٹا اس نئے نمبر سے منسلک ہوگا",
      "next": "اگلا",
      "logoutQ": "کیا آپ لاگ آؤٹ کرنا چاہتے ہیں؟",
      "deleteQ": "اکاؤنٹ ڈیلیٹ کریں؟",
      "deleteSub": "آپ کے اکاؤنٹ سے منسلک تمام ڈیٹا ختم ہو جائے گا",
    }
  };

  String t(String key) => text[language == "English" ? "English" : "Urdu"]![key]!;

  @override
  Widget build(BuildContext context) {
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
            icon: Icon(Icons.arrow_back_ios, color: primaryColor),
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
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
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
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
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
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            )
          : null,
      trailing: Icon(Icons.arrow_forward_ios, color: primaryColor, size: 18),
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
                t("changeNum"),
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                t("changeSub"),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixText: "+92 ",
                  prefixStyle: GoogleFonts.poppins(color: Colors.black),
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
                child: Text(t("next")),
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
              title: const Text("English"),
              trailing: language == "English"
                  ? Icon(Icons.check, color: primaryColor)
                  : null,
              onTap: () {
                setState(() => language = "English");
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("Urdu (Pakistan)"),
              trailing: language == "Urdu (Pakistan)"
                  ? Icon(Icons.check, color: primaryColor)
                  : null,
              onTap: () {
                setState(() => language = "Urdu (Pakistan)");
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
              title: const Text("Light Theme"),
              trailing: themeNotifier.value == ThemeMode.light
                  ? Icon(Icons.check, color: primaryColor)
                  : null,
              onTap: () {
                themeNotifier.setLight();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("Dark Theme"),
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
          t("logout"),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          t("logoutQ"),
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const VerifyScreen()),
                (_) => false,
              );
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  // ================= DELETE ACCOUNT =================
  void _deleteAccountSheet() {
    final isDark = themeNotifier.value == ThemeMode.dark;

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Text(
                t("deleteQ"),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t("deleteSub"),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: () {
                  // 🔴 BACKEND TASK:
                  // - Delete user account permanently
                  // - Block this phone number from re-login
                  // - Force user to register again with new number

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const VerifyScreen()),
                    (_) => false,
                  );
                },
                child: const Text("Delete"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
