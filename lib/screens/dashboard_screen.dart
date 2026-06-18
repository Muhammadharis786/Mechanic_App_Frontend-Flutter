import 'package:flutter/material.dart';
import '../widgets/app_back_button.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text("Dashboard"),
      ),
      body: Center(
        child: Text(
          "Welcome to Dashboard!",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
