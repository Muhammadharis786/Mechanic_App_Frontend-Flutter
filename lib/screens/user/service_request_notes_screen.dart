import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'service_request_map_screen.dart';
import '../../widgets/app_back_button.dart';

class ServiceRequestNotesScreen extends StatefulWidget {
  final String serviceType;
  final String? selectedMechanicId;
  const ServiceRequestNotesScreen({
    super.key,
    required this.serviceType,
    this.selectedMechanicId,
  });

  @override
  State<ServiceRequestNotesScreen> createState() =>
      _ServiceRequestNotesScreenState();
}

class _ServiceRequestNotesScreenState extends State<ServiceRequestNotesScreen> {
  final TextEditingController _notesController = TextEditingController();
  final Color primaryColor = const Color(0xFFFB3300);
  bool _fixedChargeAccepted = false;

  // Service type selection (used when coming from mechanic card)
  late String _selectedServiceType;

  static const List<Map<String, dynamic>> _serviceOptions = [
    {'label': 'Bike Mechanic', 'icon': Icons.two_wheeler_rounded},
    {'label': 'Car Mechanic', 'icon': Icons.directions_car_rounded},
    {'label': 'Puncher', 'icon': Icons.tire_repair_rounded},
  ];

  int get _fixedChargeAmount {
    final type = _selectedServiceType.toLowerCase();
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
    _selectedServiceType = widget.serviceType;
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
          serviceType: _selectedServiceType,
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

    // Show service type selection only when coming from mechanic card
    final bool showServiceSelection = widget.selectedMechanicId != null;

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

                // ── Service Type Selection (only from mechanic card) ──
                if (showServiceSelection) ...[
                  Text(
                    'Select Service Type',
                    style: TextStyle(
                      fontFamily:
                          GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _serviceOptions.map((option) {
                      final isSelected =
                          _selectedServiceType == option['label'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedServiceType =
                                  option['label'] as String;
                              // Reset checkbox when service changes
                              _fixedChargeAccepted = false;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withOpacity(0.1)
                                  : (isDark
                                      ? Colors.grey[850]
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  option['icon'] as IconData,
                                  size: 22,
                                  color: isSelected
                                      ? primaryColor
                                      : (isDark
                                          ? Colors.white54
                                          : Colors.black54),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  (option['label'] as String)
                                      .replaceAll(' Mechanic', '\nMechanic'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily:
                                        GoogleFonts.getFont('Bricolage Grotesque')
                                            .fontFamily,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? primaryColor
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Title ──
                Text(
                  'Requesting $_selectedServiceType',
                  style: TextStyle(
                    fontFamily:
                        GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Describe your problem so the mechanic can help you.',
                  style: TextStyle(
                    fontFamily:
                        GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Problem TextField ──
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
                    fillColor:
                        isDark ? Colors.grey[850] : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  style: TextStyle(
                    fontFamily:
                        GoogleFonts.getFont('Bricolage Grotesque').fontFamily,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Fixed Charge Checkbox ──
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
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87,
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

                // ── Next Button ──
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
