import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'payment_webview_screen.dart';
import '../authentication/user_session.dart';

class MechanicSubscriptionScreen extends StatefulWidget {
  const MechanicSubscriptionScreen({super.key});

  @override
  State<MechanicSubscriptionScreen> createState() =>
      _MechanicSubscriptionScreenState();
}

class _MechanicSubscriptionScreenState
    extends State<MechanicSubscriptionScreen> {
  int _selectedTabIndex = 0;
  bool _isProcessing = false;

  static const Color primaryColor = Color(0xFFFB3300);

  final List<Map<String, dynamic>> _plans = [
    {
      'title': 'Free',
      'price': 'Rs. 0',
      'period': '/month',
      'tagline': 'Basic access to start your journey.',
      'badge': null,
      'badgeColor': null,
      'amount': '0',
      'item': 'FreePlan',
      'features': [
        '3-4 service requests per month',
        'Standard search visibility (bottom of list)',
        'Basic profile listing only',
        'No trust badge',
        '20% commission per job',
      ],
    },
    {
      'title': 'Premium',
      'price': 'Rs. 700',
      'period': '/month',
      'tagline': 'Ideal for professionals scaling their business.',
      'badge': 'Most Popular',
      'badgeColor': primaryColor,
      'amount': '700',
      'item': 'PremiumPlan',
      'features': [
        'Unlimited service requests',
        'Improved search visibility (above Free tier)',
        '15% commission per job',
        'Faster payout processing',
      ],
    },
    {
      'title': 'Ultra Premium',
      'price': 'Rs. 1000',
      'period': '/month',
      'tagline': 'Maximum visibility and priority benefits.',
      'badge': 'Best Value',
      'badgeColor': primaryColor,
      'amount': '1000',
      'item': 'UltraPremiumPlan',
      'features': [
        'Unlimited service requests',
        'Top of search results (maximum visibility)',
        'Lowest commission — only 10% per job',
        '"Verified Pro" badge on profile',
        'Priority customer requests (sent first)',
      ],
    },
  ];

  // ── Show payment form as bottom sheet ──
  void _showPaymentForm(Map<String, dynamic> plan) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final itemCtrl = TextEditingController(text: plan['item']);
    final amountCtrl = TextEditingController(text: plan['amount']);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Payment Details',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${plan['title']} — ${plan['price']}/month',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildField(
                      nameCtrl, 'Payee Name', Icons.person_outline, isDark,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      emailCtrl, 'Email', Icons.email_outlined, isDark,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      phoneCtrl, 'Phone (03XXXXXXXXX)',
                      Icons.phone_outlined, isDark,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                        itemCtrl, 'Item', Icons.label_outline, isDark),
                    const SizedBox(height: 12),
                    _buildField(
                      amountCtrl, 'Amount (Rs.)',
                      Icons.currency_rupee, isDark,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    StatefulBuilder(
                      builder: (ctx2, setBtn) {
                        return SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setBtn(() => _isProcessing = true);
                                    Navigator.pop(ctx);
                                    await _processPayment(
                                      payeeName: nameCtrl.text.trim(),
                                      email: emailCtrl.text.trim(),
                                      msisdn: phoneCtrl.text.trim(),
                                      item: itemCtrl.text.trim(),
                                      amount: amountCtrl.text.trim(),
                                      planTitle: plan['title'],
                                    );
                                    if (mounted) {
                                      setState(() => _isProcessing = false);
                                    }
                                  },
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Proceed to Pay',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    bool isDark, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.poppins(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: isDark ? Colors.white54 : Colors.black54,
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        filled: true,
        fillColor:
            isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _processPayment({
    required String payeeName,
    required String email,
    required String msisdn,
    required String item,
    required String amount,
    required String planTitle,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://mechanicapp-service-621632382478.asia-south1.run.app/generate-url'),
        headers: UserSession().getAuthHeader(),
        body: jsonEncode({
          'payeeName': payeeName,
          'email': email,
          'msisdn': msisdn,
          'item': item,
          'amount': amount,
        }),
      );

      if (!mounted) return;

      debugPrint('🔵 generate-url status: ${response.statusCode}');
      debugPrint('🔵 generate-url response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final String? paymentUrl = decoded['paymentUrl']?.toString();

        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentWebViewScreen(
                paymentUrl: paymentUrl,
                planName: planTitle,
              ),
            ),
          );
        } else {
          _showError('Payment URL not received. Please try again.');
        }
      } else {
        _showError('Failed to generate payment link (${response.statusCode}).');
      }
    } catch (e) {
      if (mounted) _showError('Network error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final surfaceColor =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        iconTheme:
            IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          'Choose a Plan',
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabSelector(isDark),
              const SizedBox(height: 32),
              _buildPlanCard(
                  _plans[_selectedTabIndex], isDark, surfaceColor),
              const SizedBox(height: 24),
              Text(
                'Note: Your status badge is earned through performance and cannot be purchased — subscription only controls visibility and request limits.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  _plans[index]['title'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white60 : Colors.black54),
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPlanCard(
    Map<String, dynamic> plan,
    bool isDark,
    Color surfaceColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          if (plan['badge'] != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: (plan['badgeColor'] as Color).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                plan['badge'],
                style: GoogleFonts.poppins(
                  color: plan['badgeColor'] as Color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),

          // Title
          Text(
            plan['title'],
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan['price'],
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _selectedTabIndex == 0
                      ? (isDark ? Colors.white : Colors.black87)
                      : primaryColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  plan['period'],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tagline
          Text(
            plan['tagline'],
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Features
          ...List.generate(plan['features'].length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color: _selectedTabIndex == 0
                        ? Colors.grey
                        : primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      plan['features'][i],
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),

          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedTabIndex == 0
                    ? (isDark ? Colors.grey[800] : Colors.grey[300])
                    : primaryColor,
                elevation: _selectedTabIndex == 0 ? 0 : 4,
                shadowColor: primaryColor.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _selectedTabIndex == 0
                  ? null
                  : () => _showPaymentForm(plan),
              child: Text(
                _selectedTabIndex == 0 ? 'Current Plan' : 'Upgrade Now',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _selectedTabIndex == 0
                      ? (isDark ? Colors.white54 : Colors.black54)
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
