import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'service_request_map_screen.dart';
import '../../widgets/app_back_button.dart';

class ServiceRequestNotesScreen extends StatefulWidget {
  final String serviceType;
  final String? selectedMechanicId;
  const ServiceRequestNotesScreen({super.key, required this.serviceType, this.selectedMechanicId});

  @override
  State<ServiceRequestNotesScreen> createState() =>
      _ServiceRequestNotesScreenState();
}

class _ServiceRequestNotesScreenState extends State<ServiceRequestNotesScreen> {
  final TextEditingController _notesController = TextEditingController();
  final Color primaryColor = const Color(0xFFFB3300);
  bool _fixedChargeAccepted = false;

  int get _fixedChargeAmount {
    final type = widget.serviceType.toLowerCase();
    if (type.contains('bike')) return 300;
    if (type.contains('car')) return 500;
    if (type.contains('puncher')) return 100;
    return 300;
  }

  String get _fixedChargeCheckboxLabel =>
      'Accept Rs.$_fixedChargeAmount fee if you cancel';

  bool get _canProceed =>
      _notesController.text.trim().isNotEmpty && _fixedChargeAccepted;

  @override
  void initState() {
    super.initState();
    _notesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the problem first.')),
      );
      return;
    }
    if (!_fixedChargeAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the fixed inspection charges.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceRequestMapScreen(
          serviceType: widget.serviceType,
          userNotes: _notesController.text.trim(),
          isFixedChargeAccepted: true,
          selectedMechanicId: widget.selectedMechanicId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Service Request',
          style: TextStyle(
            fontFamily: GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requesting ${widget.serviceType}',
                  style: TextStyle(
                    fontFamily:
                        GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Describe your problem so the mechanic can help you.',
                  style: TextStyle(
                    fontFamily:
                        GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _notesController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. My car is not starting, battery might be dead...',
                    hintStyle: TextStyle(
                      fontFamily:
                          GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  style: TextStyle(
                    fontFamily:
                        GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: isDark ? Colors.grey[850] : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _fixedChargeAccepted = !_fixedChargeAccepted;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _fixedChargeAccepted,
                            activeColor: primaryColor,
                            onChanged: (value) {
                              setState(() {
                                _fixedChargeAccepted = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _fixedChargeCheckboxLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canProceed ? _onNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 16,
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
    );
  }
}
