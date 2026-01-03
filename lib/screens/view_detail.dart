import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Mechanic {
  final String id;
  final String name;
  final String avatarUrl; 
  final double rating; 
  final double distanceKm;
  final bool isOnline;
  final String phone;
  final double lat;
  final double lng;
  final int experienceYears;

  const Mechanic({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.rating,
    required this.distanceKm,
    required this.isOnline,
    required this.phone,
    required this.lat,
    required this.lng,
    this.experienceYears = 5,
  });
}

class MechanicDetailScreen extends StatelessWidget {
  final Mechanic mechanic;
  final String serviceType;

  const MechanicDetailScreen({super.key, required this.mechanic, this.serviceType = ''});

  final Color primaryColor = const Color(0xFFFB3300); // Deep Orange
  final String uiFont = 'Poppins';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Mechanic Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mechanic Avatar & Info Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    Flexible(child: _buildMechanicInfo()),
                    const SizedBox(width: 8),
                    _buildStatusTag(),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.grey),

              // Rating, Distance & Experience
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildRatingChip(),
                        const SizedBox(width: 12),
                        _buildDistanceTile(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildExperienceTag(),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Map Placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AspectRatio(
                  aspectRatio: 1.6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.grey.shade100,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/m1.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned.fill(
                            child: Container(color: Colors.black.withOpacity(0.03)),
                          ),
                          Center(
                            child: Icon(Icons.map_outlined, size: 56, color: primaryColor.withOpacity(0.8)),
                          ),
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.my_location, size: 18, color: primaryColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Mechanic is at near ${mechanic.distanceKm.toStringAsFixed(1)} km — tap for directions',
                                      style: TextStyle(fontFamily: uiFont, fontSize: 13),
                                    ),
                                  ),
                                  Icon(Icons.directions, color: primaryColor),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Call Mechanic Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: mechanic.phone.trim().isNotEmpty
                        ? () async {
                             final Uri launchUri = Uri(scheme: 'tel', path: mechanic.phone);
                             if (await canLaunchUrl(launchUri)) {
                               await launchUrl(launchUri);
                             } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not launch dialer for ${mechanic.phone}'))
                                );
                             }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    child: const Text('Call Mechanic', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Request Mechanic Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Request sent to mechanic'))
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    child: const Text('Request Mechanic', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 36,
      backgroundImage: mechanic.avatarUrl.startsWith('http')
          ? NetworkImage(mechanic.avatarUrl)
          : (mechanic.avatarUrl.isNotEmpty
              ? AssetImage(mechanic.avatarUrl)
              : const AssetImage('assets/images/car.jpg')) as ImageProvider,
    );
  }

  Widget _buildMechanicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mechanic.name,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.normal, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.work_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text('Mobile Mechanic', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: Colors.redAccent),
            const SizedBox(width: 6),
            Text('${mechanic.distanceKm.toStringAsFixed(1)} km away', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.star, size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Text(mechanic.rating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor)),
        ],
      ),
    );
  }

  Widget _buildDistanceTile() {
    return Row(
      children: [
        Icon(Icons.place_outlined, size: 16, color: primaryColor),
        const SizedBox(width: 6),
        Text('${mechanic.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
      ],
    );
  }

  Widget _buildStatusTag() {
    final color = mechanic.isOnline ? Colors.green.shade600 : Colors.grey.shade600;
    final text = mechanic.isOnline ? 'Online' : 'Offline';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildExperienceTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('${mechanic.experienceYears} yrs experience', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primaryColor)),
    );
  }
}

// Preview helper
class MechanicDetailPreview extends StatelessWidget {
  const MechanicDetailPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final mechanic = const Mechanic(
      id: 'm1',
      name: 'Alex Johnson',
      avatarUrl: '',
      rating: 4.8,
      distanceKm: 2.6,
      isOnline: true,
      phone: '+1234567890',
      lat: 37.4219983,
      lng: -122.084,
      experienceYears: 6,
    );

    return MechanicDetailScreen(mechanic: mechanic);
  }
}
