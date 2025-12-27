import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auto_assign.dart';
import 'user_session.dart'; 

class ServiceChatScreen extends StatefulWidget {
  final String serviceType;
  final int id; // Initial parentID

  const ServiceChatScreen({
    super.key,
    required this.serviceType,
    required this.id,
  });

  @override
  State<ServiceChatScreen> createState() => _ServiceChatScreenState();
}

class _ServiceChatScreenState extends State<ServiceChatScreen> {
  final Color primaryColor = const Color(0xFFFB3300);

  bool isLoading = true;
  bool isSubmitting = false;
  bool isFinished = false; // To show "Welcome" message

  // Current list of options being displayed
  List<Map<String, dynamic>> currentOptions = [];
  
  // Track the selection path for the summary
  List<String> selectionPath = [];
  int? lastSelectedId;

  final TextEditingController noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchOptions(widget.id);
  }

  // 1. Pehle UserSession file ko import karein


// ... baqi code ...

// ================= API CALL =================
Future<void> fetchOptions(int parentId) async {
  setState(() {
    isLoading = true;
  });

  final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/subproblems/$parentId" );

  try {
    // 🔐 AB YAHAN HARDCODED EMAIL/PASS KI ZAROORAT NAHI
    // UserSession se headers lein jo login ke waqt save huay thay
    final response = await http.get(
      url,
      headers: UserSession( ).getAuthHeader(), 
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);

      setState(() {
        if (data.isEmpty) {
          isFinished = true;
        } else {
          currentOptions = data
              .map((e) => {
                    "id": e["id"],
                    "text": e["text"],
                  })
              .toList();
        }
        isLoading = false;
      });
    } else {
      throw Exception("API Failed: ${response.statusCode}");
    }
  } catch (e) {
    setState(() => isLoading = false);
    debugPrint("API ERROR: $e");
  }
}

  void _handleOptionSelect(Map<String, dynamic> option) {
    setState(() {
      selectionPath.add(option["text"]);
      lastSelectedId = option["id"];
    });
    fetchOptions(option["id"]);
  }

  void _resetSelection() {
    setState(() {
      selectionPath = [];
      lastSelectedId = null;
      isFinished = false;
    });
    fetchOptions(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.serviceType} Assistant",
          style: const TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.bold),
        ),
        actions: [
          if (selectionPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _resetSelection,
            )
        ],
      ),

      // ================= BODY =================
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 1️⃣ DYNAMIC SELECTION SECTION
                    _questionCard(
                      isFinished ? "Selection Complete" : "Tell us about your problem",
                      isLoading
                          ? const Center(child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ))
                          : isFinished
                              ? _welcomeMessage()
                              : _optionsList(),
                    ),

                    // 2️⃣ NOTES
                    _questionCard(
                      "Additional details (optional)",
                      _noteField(),
                    ),

                    const SizedBox(height: 16),

                    // 3️⃣ SUMMARY
                    _summaryCard(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            _confirmButton(),
          ],
        ),
      ),
    );
  }

  // ================= WIDGETS =================

  Widget _optionsList() {
    if (currentOptions.isEmpty) {
      return const Text("No options available");
    }

    return Column(
      children: currentOptions.map((option) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              alignment: Alignment.centerLeft,
            ),
            onPressed: () => _handleOptionSelect(option),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    option["text"],
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _welcomeMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 12),
          const Text(
            "Welcome!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 4),
          const Text(
            "We have all the details we need.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          TextButton(
            onPressed: _resetSelection,
            child: const Text("Change Selection"),
          )
        ],
      ),
    );
  }

  Widget _questionCard(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _noteField() {
    return TextField(
      controller: noteController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: "Type here...",
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (v) => setState(() {}),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Summary",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.orange),
          _summaryRow("Service", widget.serviceType),
          if (selectionPath.isNotEmpty)
            _summaryRow("Selection", selectionPath.join(" > ")),
          _summaryRow(
            "Notes",
            noteController.text.isEmpty ? "-" : noteController.text,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: Text("$label:",
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }

  Widget _confirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: isSubmitting || (!isFinished && selectionPath.isEmpty)
            ? null
            : () async {
                setState(() => isSubmitting = true);
                await Future.delayed(const Duration(seconds: 1));
                setState(() => isSubmitting = false);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AutoAssignScreen()),
                );
              },
        child: isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "Confirm & Find Mechanic",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
