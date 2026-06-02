import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Top-right price block for approved inspection + visiting charges.
class ServiceChargesPriceBadge extends StatelessWidget {
  const ServiceChargesPriceBadge({
    super.key,
    required this.inspectionPrice,
    this.visitingPrice,
    this.primaryColor = const Color(0xFFFB3300),
  });

  final double? inspectionPrice;
  final double? visitingPrice;
  final Color primaryColor;

  String _formatRs(double? value) {
    if (value == null) return '--';
    if (value == value.roundToDouble()) {
      return 'Rs. ${value.toInt()}';
    }
    return 'Rs. ${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatRs(inspectionPrice),
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: primaryColor,
            height: 1.05,
            letterSpacing: -0.3,
          ),
        ),
        if (visitingPrice != null) ...[
          const SizedBox(height: 8),
          Text(
            'Visiting charge',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatRs(visitingPrice),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ],
    );
  }
}
