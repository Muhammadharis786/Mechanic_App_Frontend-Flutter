import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mechanic App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color contrastColor = const Color(0xFFFB3300);
  final Color silverColor = const Color(0xFFF5F5F5);

  bool _isLocationEnabled = false;
  Position? _currentPosition;

  final List<Map<String, dynamic>> _mechanics = [
    {'name': 'Hli Mechanic', 'distance': '1.2 km', 'type': 'Bike Mechanic', 'rating': '4.5', 'isOnline': true},
    {'name': 'Ahmad Auto', 'distance': '3.5 km', 'type': 'Car Mechanic', 'rating': '4.8', 'isOnline': false},
    {'name': 'Raza Repair', 'distance': '0.5 km', 'type': 'Bike Mechanic', 'rating': '4.2', 'isOnline': true},
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();

    // Listen for location service changes
    Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      setState(() {
        _isLocationEnabled = status == ServiceStatus.enabled;
      });
      if (_isLocationEnabled) {
        _getCurrentPosition();
      }
    });

    _pageController.addListener(() {
      final page = _pageController.page ?? 0;
      if (page.round() != _currentPage) {
        setState(() {
          _currentPage = page.round();
        });
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients) {
        int nextPage = (_pageController.page!.round() + 1) % _mechanics.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeIn,
        );
      }
    });

    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    setState(() {
      _isLocationEnabled = serviceEnabled;
    });
  }

  Future<void> _getCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
      print('User location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _promptForLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Location permission denied forever. Enable from settings.')),
      );
      return;
    }
    _getCurrentPosition();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!_isLocationEnabled) _buildLocationBanner(),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildTitleSection(),
              const SizedBox(height: 15),
              _buildMechanicProfileCard(),
              const SizedBox(height: 25),
              _buildServiceGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBanner() {
    return Container(
      color: contrastColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Location is off. Tap to enable for better service.',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          GestureDetector(
            onTap: _promptForLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'ON',
                style: TextStyle(
                  color: contrastColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.menu, size: 30),
            const SizedBox(width: 15),
            const CircleAvatar(
              radius: 15,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'User123',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Icon(Icons.notifications_none, size: 30, color: contrastColor),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mechanics',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          height: 2,
          width: 100,
          color: contrastColor,
        ),
      ],
    );
  }

  Widget _buildMechanicProfileCard() {
    const double cardHeight = 150;
    return Column(
      children: [
        Container(
          height: cardHeight,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: PageView.builder(
            controller: _pageController,
            itemCount: _mechanics.length,
            itemBuilder: (context, index) {
              return _buildMechanicDetails(_mechanics[index]);
            },
          ),
        ),
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _mechanics.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _currentPage ? contrastColor : Colors.grey.shade300,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMechanicDetails(Map<String, dynamic> mechanic) {
    final Color statusColor = mechanic['isOnline'] ? Colors.green : Colors.grey;
    final String statusText = mechanic['isOnline'] ? 'Online' : 'Offline';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white, size: 40),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                mechanic['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                mechanic['distance'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  mechanic['type'],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  mechanic['rating'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceGrid() {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: _serviceBox(title: 'Car Mechanic', imagePath: 'assets/images/car.jpg', borderRadius: 20),
        ),
        const SizedBox(height: 15),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  SizedBox(height: 95, child: _serviceBox(title: 'Bike Puncher', imagePath: 'assets/images/bike_puncher.jpg', borderRadius: 16)),
                  const SizedBox(height: 10),
                  SizedBox(height: 95, child: _serviceBox(title: 'Car Puncher', imagePath: 'assets/images/car_puncher.jpg', borderRadius: 16)),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 1,
              child: SizedBox(height: 200, child: _serviceBox(title: 'Bike Mechanic', imagePath: 'assets/images/bike.jpg', borderRadius: 16)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _serviceBox({required String title, required String imagePath, double borderRadius = 20}) {
    const labelBg = Color(0xFFFB3300);
    return Container(
      decoration: BoxDecoration(
        color: silverColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.18))),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: labelBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
