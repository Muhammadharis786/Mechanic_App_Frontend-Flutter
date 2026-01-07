import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mech_app/screens/homescreen.dart';
import 'package:mech_app/screens/user/mechanic_list_book_appointment.dart';
import 'package:url_launcher/url_launcher.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  String selectedService = "Bike Mechanic";
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  final TextEditingController addressController = TextEditingController();
  final TextEditingController detailController = TextEditingController();

  Map<String, dynamic>? selectedMechanic;

  final List<String> services = [
    "Bike Mechanic",
    "Car Mechanic",
    "Puncture Repair",
  ];

  final List<Map<String, dynamic>> mechanics = [
    {
      "id": "1",
      "name": "Ali Mechanic",
      "rating": 4.8,
      "distance": 2.5,
      "available": true,
      "phone": "03123456789",
      "image": "assets/m1.jpg",
    },
    {
      "id": "2",
      "name": "Ahmed Mechanic",
      "rating": 4.5,
      "distance": 3.2,
      "available": false,
      "phone": "03129876543",
      "image": "assets/m2.png",
    },
    {
      "id": "3",
      "name": "Bilal Mechanic",
      "rating": 4.9,
      "distance": 1.8,
      "available": true,
      "phone": "03121234567",
      "image": "assets/mechanic3.png",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryColor),
          onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeScreen())),
        ),
        title: Text(
          "Book Appointment",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Select Service"),
            const SizedBox(height: 8),
            _dropdown(services, selectedService, (v) {
              setState(() => selectedService = v!);
            }, isDark),
            const SizedBox(height: 20),

            _sectionTitleWithSeeAll(
              "Select Nearby Mechanic",
              "See All",
              () async {
                final selected = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MechanicListScreenn(
                      serviceType: selectedService,
                      mechanics: mechanics,
                      showViewOption: true, // show view button in vertical list
                      selectedMechanicId: selectedMechanic?['id'],
                    ),
                  ),
                );
                if (selected != null) setState(() => selectedMechanic = selected);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: mechanics.length,
                itemBuilder: (context, index) {
                  final mechanic = mechanics[index];
                  final isSelected = selectedMechanic != null &&
                      selectedMechanic!['id'] == mechanic['id'];
                  return Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 12),
                    child: _mechanicCard(mechanic, isDark, isSelected),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _autoAssignMechanic,
                icon: const Icon(Icons.auto_fix_high, color: Colors.white),
                label: Text("Auto Assign Mechanic",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _sectionTitle("Service Detail"),
            const SizedBox(height: 8),
            _inputField(
              controller: detailController,
              hint: "Describe your problem briefly",
              icon: Icons.build,
              isDark: isDark,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            _sectionTitle("Service Location"),
            const SizedBox(height: 8),
            _inputField(
              controller: addressController,
              hint: "Enter your home address",
              icon: Icons.location_on,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            _sectionTitle("Select Date"),
            _dateTile(isDark),
            const SizedBox(height: 16),
            _sectionTitle("Select Time"),
            _timeTile(isDark),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  if (selectedMechanic == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select a mechanic")));
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (_) => _successDialog(),
                  );
                },
                child: Text(
                  "Confirm Appointment",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15));

  Widget _sectionTitleWithSeeAll(String title, String seeAllText, VoidCallback onSeeAll) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          TextButton(
            onPressed: onSeeAll,
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.white),
              overlayColor: MaterialStateProperty.all(Colors.deepOrange.shade100),
            ),
            child: Text(
              seeAllText,
              style: GoogleFonts.poppins(color: Colors.deepOrange, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );

  Widget _dropdown(List<String> items, String value, Function(String?) onChanged, bool isDark) =>
      DropdownButtonFormField<String>(
        value: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark ? Colors.grey[900] : Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      );

  Widget _inputField(
          {required TextEditingController controller,
          required String hint,
          required IconData icon,
          required bool isDark,
          int maxLines = 1}) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryColor),
          hintText: hint,
          filled: true,
          fillColor: isDark ? Colors.grey[900] : Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      );

  Widget _mechanicCard(Map<String, dynamic> mechanic, bool isDark, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? primaryColor : Colors.transparent, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 28, backgroundImage: AssetImage(mechanic['image'])),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mechanic['name'],
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text("${mechanic['rating']}", style: GoogleFonts.poppins(fontSize: 12)),
                        const SizedBox(width: 6),
                        Icon(Icons.location_on, size: 14, color: primaryColor),
                        Text("${mechanic['distance']} km", style: GoogleFonts.poppins(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: mechanic['available'] ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => selectedMechanic = mechanic),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isSelected ? "Selected" : "Select",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              ElevatedButton.icon(
                onPressed: () => _callMechanic(mechanic['phone']),
                icon: const Icon(Icons.call, size: 16, color: Colors.white),
                label: const Text("Call", style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _callMechanic(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Cannot call mechanic")));
    }
  }

  void _autoAssignMechanic() {
    final available = mechanics.where((m) => m['available']).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No available mechanics nearby")));
      return;
    }
    available.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    setState(() => selectedMechanic = available.first);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Auto assigned ${available.first['name']}")));
  }

  Widget _dateTile(bool isDark) => ListTile(
        tileColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(Icons.calendar_today, color: primaryColor),
        title: Text(selectedDate == null
            ? "Choose Date"
            : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            firstDate: DateTime.now(),
            lastDate: DateTime(2030),
            initialDate: DateTime.now(),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                ),
              ),
              child: child!,
            ),
          );
          if (date != null) setState(() => selectedDate = date);
        },
      );

  Widget _timeTile(bool isDark) => ListTile(
        tileColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(Icons.access_time, color: primaryColor),
        title: Text(selectedTime == null
            ? "Choose Time"
            : selectedTime!.format(context)),
        onTap: () async {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                ),
              ),
              child: child!,
            ),
          );
          if (time != null) setState(() => selectedTime = time);
        },
      );

  Widget _successDialog() => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Icon(Icons.check_circle, color: primaryColor, size: 50),
        content: Text(
          "Your appointment has been booked successfully with ${selectedMechanic!['name']}!",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(),
        ),
      );
}
