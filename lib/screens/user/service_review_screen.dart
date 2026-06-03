import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../authentication/user_session.dart';
import '../homescreen.dart';

class ServiceReviewScreen extends StatefulWidget {
  final String serviceId;
  final String serviceType;

  const ServiceReviewScreen({
    super.key,
    required this.serviceId,
    this.serviceType = 'EMERGENCY',
  });

  @override
  State<ServiceReviewScreen> createState() => _ServiceReviewScreenState();
}

class _ServiceReviewScreenState extends State<ServiceReviewScreen> {
  static const Color _primary = Color(0xFFFB3300);

  int _rating = 0;
  bool _isSubmitting = false;

  final TextEditingController _commentCtrl = TextEditingController();

  // Keep this list aligned with what you want to send
  final List<String> _tags = const [
    'Great quality overall',
    'Loved the service',
    'Arrived on time',
    'Minor issue, but still happy',
    'Would order again',
    'Helpful support',
  ];

  final Set<String> _selectedTags = {};

  bool get _hasTagsSelected => _selectedTags.isNotEmpty;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  String _commentValue() {
    if (_hasTagsSelected) return _selectedTags.join(', ');
    return _commentCtrl.text.trim();
  }

  /// Backend Review ServiceType enum: EMERGENCY | APPOINTMENT only.
  String _apiServiceType() {
    final type = widget.serviceType.trim().toUpperCase();
    if (type == 'APPOINTMENT') return 'APPOINTMENT';
    return 'EMERGENCY';
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    final comment = _commentValue();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a comment or select a tag')),
      );
      return;
    }

    final apiServiceType = _apiServiceType();
    final appointmentId = widget.serviceId.trim();

    if (apiServiceType == 'APPOINTMENT') {
      if (appointmentId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid appointment id')),
        );
        return;
      }
    } else {
      final serviceId = int.tryParse(appointmentId);
      if (serviceId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid service id')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final Map<String, dynamic> payload = {
        'serviceType': apiServiceType,
        'rating': _rating,
        'comment': comment,
      };
      if (apiServiceType == 'APPOINTMENT') {
        payload['appointmentId'] = appointmentId;
      } else {
        payload['serviceId'] = int.parse(appointmentId);
      }

      final response = await http.post(
        Uri.parse(
          'https://mechanicapp-service-621632382478.asia-south1.run.app/api/service-request/review/submit',
        ),
        headers: {
          'Content-Type': 'application/json',
          ...UserSession().getAuthHeader(),
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      final body = response.body.trim();
      final success = (response.statusCode == 200 || response.statusCode == 201) &&
          (body.toLowerCase().contains('success') ||
              body.toLowerCase().contains('submitted'));

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted. Thank you!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submit failed: ${response.body}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width > 420 ? 420.0 : width - 40;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Container(
              width: cardWidth,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Feedback Matters',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'It takes less than 60 seconds to complete',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded,
                              color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 16),
                  Text(
                    'How was your overall experience?',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final idx = i + 1;
                      final active = _rating >= idx;
                      return IconButton(
                        onPressed: () => setState(() => _rating = idx),
                        iconSize: 34,
                        splashRadius: 22,
                        icon: Icon(
                          active ? Icons.star_rounded : Icons.star_border_rounded,
                          color: active ? const Color(0xFFFFC107) : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final idx = i + 1;
                      final selected = _rating == idx;
                      final emoji = ['😡', '😕', '😐', '🙂', '😍'][i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          emoji,
                          style: TextStyle(
                            fontSize: selected ? 18 : 14,
                            color: selected ? Colors.black87 : Colors.grey.shade500,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'What did you think?',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _tags.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedTags.remove(tag);
                            } else {
                              _selectedTags.add(tag);
                              _commentCtrl.clear();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFFEAF8F0) : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF36B37E)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected)
                                const Padding(
                                  padding: EdgeInsets.only(right: 6),
                                  child: Icon(Icons.check_circle_rounded,
                                      size: 16, color: Color(0xFF36B37E)),
                                ),
                              Text(
                                tag,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? const Color(0xFF1E7F5A)
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "What could've made it perfect?",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AbsorbPointer(
                    absorbing: _hasTagsSelected,
                    child: Opacity(
                      opacity: _hasTagsSelected ? 0.55 : 1,
                      child: TextField(
                        controller: _commentCtrl,
                        minLines: 4,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: _hasTagsSelected
                              ? 'Tag selected (comment will be tag text)'
                              : 'Loved most of it! One small thing…',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _primary, width: 1.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Submit Feedback',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

