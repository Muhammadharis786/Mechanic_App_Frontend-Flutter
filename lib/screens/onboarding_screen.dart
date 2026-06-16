import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'role_selection_screen.dart';
import '../l10n/app_strings.dart';
import '../services/app_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _textController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  List<Map<String, String>> get onboardingData => [
    {
      "image": "assets/images/boardi1.png",
      "title": AppStrings.t('onboard1Title'),
      "desc": AppStrings.t('onboard1Desc'),
    },
    {
      "image": "assets/images/onboardd2.png",
      "title": AppStrings.t('onboard2Title'),
      "desc": AppStrings.t('onboard2Desc'),
    },
    {
      "image": "assets/images/onboardd3.png",
      "title": AppStrings.t('onboard3Title'),
      "desc": AppStrings.t('onboard3Desc'),
    },
    {
      "image": "assets/images/onboard4.png",
      "title": AppStrings.t('onboard4Title'),
      "desc": AppStrings.t('onboard4Desc'),
    },
  ];

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _textController, curve: Curves.easeIn);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textController.forward();
  }

  @override
  void dispose() {
    _textController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 10,
      width: _currentPage == index ? 24 : 10,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? const Color(0xFFFB3300)
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _currentPage == index
            ? [
                BoxShadow(
                  color: const Color(0xFFFB3300).withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
    );
  }

  void _nextPage() async {
    if (_currentPage < onboardingData.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstTime', false);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      );
    }
  }

  Widget _pageViewContent(int index) {
    return AnimatedOpacity(
      opacity: _currentPage == index ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            AnimatedScale(
              duration: const Duration(milliseconds: 500),
              scale: _currentPage == index ? (index == 1 ? 1.25 : 1.1) : 1.0,
              child: Image.asset(
                onboardingData[index]['image']!,
                height: index == 1 ? 290 : 260,
              ),
            ),
            const SizedBox(height: 40),
            FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: Column(
                  children: [
                    Text(
                      onboardingData[index]['title']!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.3,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      onboardingData[index]['desc']!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- SKIP BUTTON ----------------
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 20),
                child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isFirstTime', false);

                    if (!context.mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RoleSelectionScreen(),
                      ),
                    );
                  },
                  child: ValueListenableBuilder<Locale>(
                    valueListenable: appLanguageController,
                    builder: (_, __, ___) => Text(
                      AppStrings.t('skip'),
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 70, 68, 68),
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ---------------- PAGEVIEW + BOTTOM SECTION ----------------
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingData.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _textController.forward(from: 0);
                },
                itemBuilder: (context, index) {
                  return _pageViewContent(index);
                },
              ),
            ),

            // Dots + Next Button
            SizedBox(
              height: 120,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(onboardingData.length, _buildDot),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFB3300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(35),
                          ),
                        ),
                        child: Text(
                          _currentPage == onboardingData.length - 1
                              ? AppStrings.t('getStarted')
                              : AppStrings.t('next'),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
