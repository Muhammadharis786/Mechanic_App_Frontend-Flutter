import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'otp_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailC = TextEditingController();
  final TextEditingController _passC = TextEditingController();

  bool isValid = false;
  bool hidePassword = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailC.addListener(_validate);
    _passC.addListener(_validate);
  }

  void _validate() {
    final email = _emailC.text.trim();
    final pass = _passC.text.trim();

    bool validEmail = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
        .hasMatch(email);
    bool validPass = pass.length >= 8;

    setState(() {
      isValid = validEmail && validPass;
    });
  }

  Future<void> _register() async {
    final email = _emailC.text.trim();
    final password = _passC.text.trim();

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/register");

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ Success → navigate OTP screen
       Navigator.push(
  context,
  MaterialPageRoute(
  builder: (_) => OtpScreen(
    email: email,
    password: password,
  ),
),

);
      } else {
        
        // ❌ Error → show backend message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.body),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Server not reachable ❌"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Register Account",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Register with your email and password",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 45),

              // ---------------- EMAIL ----------------
              Text("Email",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  hintText: "example@gmail.com",
                  hintStyle: GoogleFonts.poppins(color: Colors.black45),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFFB3300), width: 1.3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFFB3300), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ---------------- PASSWORD ----------------
              Text("Password",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 6),
              TextField(
                controller: _passC,
                obscureText: hidePassword,
                style: GoogleFonts.poppins(),
                decoration: InputDecoration(
                  hintText: "Minimum 8 characters",
                  hintStyle: GoogleFonts.poppins(color: Colors.black45),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black54,
                    ),
                    onPressed: () => setState(() => hidePassword = !hidePassword),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFFB3300), width: 1.3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFFB3300), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ---------------- REGISTER BUTTON ----------------
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isValid && !isLoading ? _register : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid
                        ? const Color(0xFFFB3300)
                        : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : Text(
                          "Send OTP",
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
