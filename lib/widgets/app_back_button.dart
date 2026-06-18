import 'package:flutter/material.dart';

/// Back button styled like [VerifyScreen].
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.pop(context),
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: Color(0xFFFB3300),
        size: 20,
      ),
      padding: const EdgeInsets.all(4),
      splashRadius: 20,
    );
  }
}
