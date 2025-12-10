import 'package:flutter/material.dart';
import 'screens/s_screen.dart';


void main() {
  runApp(const MechConnectApp());
}

class MechConnectApp extends StatelessWidget {
  const MechConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MechConnect',
      theme: ThemeData(
        primaryColor: Colors.orange,
        fontFamily: 'Poppins',
      ),
      home: const SplashScreen(), // 👈 Splash se start hoga
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
