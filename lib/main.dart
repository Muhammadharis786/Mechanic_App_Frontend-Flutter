import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/s_screen.dart';
import 'firebase_options.dart';

// ===== GLOBAL THEME NOTIFIER =====
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);

  void setDark() => value = ThemeMode.dark;
  void setLight() => value = ThemeMode.light;
}

final themeNotifier = ThemeNotifier();

void main() async {
   WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MechConnectApp());
}

class MechConnectApp extends StatelessWidget {
  const MechConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MechConnect',

          // ===== THEMES =====
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.orange,
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Poppins',
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.deepOrange,
            scaffoldBackgroundColor: Colors.black,
            fontFamily: 'Poppins',
          ),
          themeMode: currentMode, // <-- GLOBAL CONTROL

          home: const SplashScreen(), // ya home screen
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Home Screen',
          style: TextStyle(
            fontFamily: 'MontserratAlternates',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ),
    );
  }
}
