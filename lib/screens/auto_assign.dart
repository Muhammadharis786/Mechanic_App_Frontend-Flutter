import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'user/service_request_notes_screen.dart';

/// Shows bike / car / puncher picker then same flow as emergency service request.
class AutoAssignScreen extends StatelessWidget {
  const AutoAssignScreen({super.key});

  static const Color _primary = Color(0xFFFB3300);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAutoAssignOptions(context);
    });

    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }

  void _showAutoAssignOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose Service',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Select a category — same flow as emergency request',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              _serviceCard(ctx, title: 'Bike Mechanic', icon: Icons.motorcycle, serviceType: 'Bike Mechanic'),
              const SizedBox(height: 12),
              _serviceCard(ctx, title: 'Car Mechanic', icon: Icons.directions_car, serviceType: 'Car Mechanic'),
              const SizedBox(height: 12),
              _serviceCard(ctx, title: 'Puncher', icon: Icons.build_circle, serviceType: 'Puncher'),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  Widget _serviceCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String serviceType,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceRequestNotesScreen(serviceType: serviceType),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _primary.withOpacity(0.1),
              child: Icon(icon, color: _primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
