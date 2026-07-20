import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/s_screen.dart';
import 'firebase_options.dart';
import 'services/fcm_notification_service.dart';
import 'services/connectivity_controller.dart';
import 'services/app_state.dart';

// ===== GLOBAL THEME NOTIFIER =====
final themeNotifier = appThemeController;
final languageNotifier = appLanguageController;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await themeNotifier.load();
  await languageNotifier.load();
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
        return ValueListenableBuilder<Locale>(
          valueListenable: languageNotifier,
          builder: (context, currentLocale, _) {
            final isUrdu = currentLocale.languageCode == 'ur';
            return MaterialApp(
              navigatorKey: navigatorKey,
              navigatorObservers: [routeObserver],
              debugShowCheckedModeBanner: false,
              title: 'OnFix',
              locale: currentLocale,
              builder: (context, child) {
                return Directionality(
                  textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                  child: child ?? const SizedBox.shrink(),
                );
              },

              // ===== THEMES =====
              theme: ThemeData(
                brightness: Brightness.light,
                primaryColor: const Color(0xFFFB3300),
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
                primaryColor: const Color(0xFFFF6D00),
                scaffoldBackgroundColor: const Color(0xFF000000),
                fontFamily: 'Poppins',
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFFFF6D00),
                  secondary: Color(0xFFFF8A50),
                  surface: Color(0xFF0F0F0F),
                  onPrimary: Colors.white,
                  surfaceTint: Colors.transparent,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF000000),
                  foregroundColor: Colors.white,
                ),
                cardColor: const Color(0xFF121212),
                dividerColor: Colors.white12,
              ),
              themeMode: currentMode,

              // ===== REMOVE OVERSCROLL GREY GLOW =====
              scrollBehavior: const _NoGlowScrollBehavior(),

              home: const SplashScreen(),
            );
          },
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
