import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/s_screen.dart';
import 'firebase_options.dart';
import 'services/fcm_notification_service.dart';
import 'services/connectivity_controller.dart';

// ===== GLOBAL THEME NOTIFIER =====
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);

  void setDark() => value = ThemeMode.dark;
  void setLight() => value = ThemeMode.light;
}

final themeNotifier = ThemeNotifier();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmNotificationService.instance.initialize();
  ConnectivityController().init();
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
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'MechConnect',

          // ===== THEMES =====
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.orange,
            scaffoldBackgroundColor: Colors.white,
            fontFamily: 'Poppins',
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFB3300),
              secondary: Colors.deepOrange,
              surface: Colors.white,
              onPrimary: Colors.white,
              surfaceTint: Colors.transparent,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.deepOrange,
            scaffoldBackgroundColor: Colors.black,
            fontFamily: 'Poppins',
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepOrange,
              secondary: Colors.orange,
              surface: Colors.black,
              onPrimary: Colors.white,
              surfaceTint: Colors.transparent,
            ),
          ),
          themeMode: currentMode,

          // ===== REMOVE OVERSCROLL GREY GLOW =====
          scrollBehavior: const _NoGlowScrollBehavior(),

          home: const SplashScreen(),
        );
      },
    );
  }
}

// Removes the grey/blue glow on overscroll (Android)
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // No glow indicator
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
