import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'otp_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/app_back_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _phoneC = TextEditingController();
  final TextEditingController _passC = TextEditingController();

  bool isValid = false;
  bool hidePassword = true;
  bool isLoading = false;

  final Color kButtonColor = const Color(0xFFFB3300);

  @override
  void initState() {
    super.initState();
    _phoneC.addListener(_validate);
    _passC.addListener(_validate);
  }

  void _validate() {
    final phone = _phoneC.text.trim();
    final pass = _passC.text.trim();
    setState(() {
      isValid = phone.length >= 10 && pass.length >= 6;
    });
  }

  // Register with WhatsApp Number
  Future<void> _register() async {
    final phone = '92${_phoneC.text.trim()}';
    final password = _passC.text.trim();

    final url = Uri.parse("https://mechanicapp-service-621632382478.asia-south1.run.app/api/user/register");

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phonenumber": phone,
          "password": password,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) { 
        Navigator.push(  
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(email: phone, password: password),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server not reachable ❌"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final fieldFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fieldBorderColor = isDark ? Colors.grey.shade700 : kButtonColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Row(
                children: [
<<<<<<< Updated upstream
                  const AppBackButton(),
=======
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Color(0xFFFB3300),
                      size: 20,
                    ),
                    padding: const EdgeInsets.all(4),
                    splashRadius: 20,
                  ),
>>>>>>> Stashed changes
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Register Account",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Register with your WhatsApp number and password",
                style: TextStyle(fontSize: 15, color: subTextColor, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 30),

              // WhatsApp Number FIELD
              Text(
                "WhatsApp Number",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: textColor,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneC,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: TextStyle(fontFamily: 'Poppins', color: textColor),
                decoration: _inputDecoration("3XXXXXXXXX", isDark, fieldFillColor, fieldBorderColor).copyWith(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      "+92",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // PASSWORD FIELD
              Text(
                "Password",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: textColor,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passC,
                obscureText: hidePassword,
                style: TextStyle(fontFamily: 'Poppins', color: textColor),
                decoration: _inputDecoration("Minimum 6 characters", isDark, fieldFillColor, fieldBorderColor).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () => setState(() => hidePassword = !hidePassword),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // REGISTER BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isValid && !isLoading ? _register : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? kButtonColor : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Register",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark, Color fillColor, Color borderColor) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontFamily: 'Poppins'),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: kButtonColor, width: 2),
      ),
    );
  }
}
