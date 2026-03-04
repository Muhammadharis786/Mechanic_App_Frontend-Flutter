import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class Mechanic {
  final String id;
  final String name;
  final String mechanictype;
  final String avatarUrl;
  final double rating;
  final double distanceKm;
  final bool isOnline;
  final String phone;
  final double lat;
  final double lng;
  final int experienceYears;
  final String mechanicLocName;

  const Mechanic({
    required this.id,
    required this.name,
    required this.mechanictype,
    required this.avatarUrl,
    required this.rating,
    required this.distanceKm,
    required this.isOnline,
    required this.phone,
    required this.lat,
    required this.lng,
    this.experienceYears = 5,
    required this.mechanicLocName,
  });
}

class MechanicDetailScreen extends StatefulWidget {
  final Mechanic mechanic;
  final String serviceType;

  const MechanicDetailScreen({super.key, required this.mechanic, this.serviceType = ''});

  @override
  State<MechanicDetailScreen> createState() => _MechanicDetailScreenState();
}

class _MechanicDetailScreenState extends State<MechanicDetailScreen> {
  final Color primaryColor = const Color(0xFFFB3300); // Deep Orange
  final String uiFont = 'Poppins';
  BitmapDescriptor? _markerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  Future<void> _refresh() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mechanic details updated")),
      );
    }
  }

  Future<void> _loadCustomMarker() async {
    try {
      final marker = await _createCustomMarkerBitmap(widget.mechanic.avatarUrl);
      if (mounted) {
        setState(() {
          _markerIcon = marker;
        });
      }
    } catch (e) {
      debugPrint("Error creating custom marker: $e");
    }
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap(String imageUrl) async {
    final int size = 100; // Increased resolution for clarity, will look fine on map
    final double borderSize = 6.0;
    final double pointerHeight = 15.0;
    final double pointerWidth = 20.0;
    
    // 1. Get Image Bytes
    ui.Codec codec;
    try {
      if (imageUrl.startsWith('http')) {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode != 200) throw Exception('Failed to load image');
        final Uint8List bytes = response.bodyBytes;
        codec = await ui.instantiateImageCodec(bytes, targetWidth: size, targetHeight: size);
      } else {
         // Handle Asset Image or Empty
         if (imageUrl.isEmpty) imageUrl = 'assets/images/car.jpg'; // Fallback
         final ByteData data = await rootBundle.load(imageUrl);
         final Uint8List bytes = data.buffer.asUint8List();
         codec = await ui.instantiateImageCodec(bytes, targetWidth: size, targetHeight: size);
      }
    } catch (e) {
      // Fallback if image fails to load
       final ByteData data = await rootBundle.load('assets/images/car.jpg');
       final Uint8List bytes = data.buffer.asUint8List();
       codec = await ui.instantiateImageCodec(bytes, targetWidth: size, targetHeight: size);
    }
    
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ui.Image image = fi.image;

    // 2. Setup Canvas
    final int canvasHeight = size + pointerHeight.toInt() + 10; // Extra space for badge overlap
    final int canvasWidth = size; // Width matches circle

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..isAntiAlias = true;
    final double radius = size / 2.0; // 50
    final Offset center = Offset(size / 2.0, size / 2.0); // (50, 50)

    // A. Draw Pointer (Triangle) at bottom of circle
    final Paint pointerPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final Path pointerPath = Path();
    pointerPath.moveTo(center.dx - pointerWidth / 2, size.toDouble() - 5); // Left of tip
    pointerPath.lineTo(center.dx, size.toDouble() + pointerHeight); // Tip
    pointerPath.lineTo(center.dx + pointerWidth / 2, size.toDouble() - 5); // Right of tip
    pointerPath.close();
    
    // Draw pointer shadow first
    canvas.drawPath(pointerPath.shift(const Offset(0, 2)), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(pointerPath, pointerPaint);
    // Draw red border for pointer
    canvas.drawPath(pointerPath, Paint()..color = Colors.red..style = PaintingStyle.stroke..strokeWidth = 2);

    // B. Draw Main Circle Border (Red)
    paint.color = Colors.red;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // C. Draw White Padding
    paint.color = Colors.white;
    canvas.drawCircle(center, radius - 3, paint);

    // D. Clip & Draw Image
    final Path clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius - borderSize));
    canvas.save();
    canvas.clipPath(clipPath);

    paint.filterQuality = FilterQuality.high;
    final double imageWidth = image.width.toDouble();
    final double imageHeight = image.height.toDouble();
           
    final Rect srcRect = Rect.fromLTWH(0, 0, imageWidth, imageHeight);
    final Rect dstRect = Rect.fromCircle(center: center, radius: radius - borderSize);
    
    canvas.drawImageRect(image, srcRect, dstRect, paint);
    canvas.restore();

    // E. Draw Distance Badge
    // Adjust font size relative to size
    final double fontSize = size * 0.18; // ~18 for size 100
    final String distanceText = '${widget.mechanic.distanceKm.toStringAsFixed(1)} km';
    final TextSpan span = TextSpan(
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        fontFamily: uiFont,
      ),
      text: distanceText,
    );
    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final double badgeWidth = tp.width + 12;
    final double badgeHeight = tp.height + 6;
    // Position badge overlapping the bottom of the circle, above the pointer
    final Offset badgeTopLeft = Offset((size - badgeWidth) / 2, size - badgeHeight + 5);

    // Badge Shadow
    final RRect badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeTopLeft.dx, badgeTopLeft.dy, badgeWidth, badgeHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      badgeRect.shift(const Offset(0, 2)), 
      Paint()..color = Colors.black38..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
    );

    // Badge Background
    final Paint badgePaint = Paint()..color = Colors.red..style = PaintingStyle.fill;
    canvas.drawRRect(badgeRect, badgePaint);
    
    // Badge Text
    tp.paint(canvas, badgeTopLeft + const Offset(6, 3));

    // 4. Convert to BitmapDescriptor
    final ui.Image markerAsImage = await pictureRecorder.endRecording().toImage(canvasWidth, canvasHeight);
    final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Background Map (Full Screen)
          Positioned.fill(
            child: GoogleMap(
              key: ValueKey(widget.mechanic.id),
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.mechanic.lat, widget.mechanic.lng),
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('mechanic_loc'),
                  position: LatLng(widget.mechanic.lat, widget.mechanic.lng),
                  icon: _markerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              // Re-enable gestures with EagerGestureRecognizer to handle specific map interactions
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
              },
              onTap: (_) => _openFullScreenMap(context),
            ),
          ),

          // 2. Custom Back Button (Floating)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // 3. Floating Bottom Panel
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Top Section with Contrast Color
                      Container(
                        padding: const EdgeInsets.only(bottom: 25),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: Column(
                          children: [
                            // Handle Bar (White on colored bg)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 12),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),

                            // Profile Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                              child: Row(
                                children: [
                                  _buildAvatarLarge(),
                                  const SizedBox(width: 15),
                                  Expanded(child: _buildHeaderInfo(isHeaderFilled: true)),
                                ],
                              ),
                            ),

                            // Quick Info Chips
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: IntrinsicHeight(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildCapsuleTag(
                                      icon: Icons.star_rounded, 
                                      label: widget.mechanic.rating.toStringAsFixed(1),
                                      color: Colors.white,
                                      iconColor: Colors.yellowAccent,
                                      bgColor: Colors.transparent
                                    ),
                                    _buildVerticalDivider(),
                                    _buildCapsuleTag(
                                      icon: Icons.location_on_rounded, 
                                      label: '${widget.mechanic.distanceKm.toStringAsFixed(1)} KM',
                                      color: Colors.white,
                                      bgColor: Colors.transparent
                                    ),
                                    _buildVerticalDivider(),
                                    _buildCapsuleTag(
                                      icon: Icons.history_rounded, 
                                      label: '${widget.mechanic.experienceYears} Years',
                                      color: Colors.white,
                                      bgColor: Colors.transparent
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Details Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Service Details",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 15),
                            _buildDetailRow(Icons.settings_outlined, "Service Type", widget.mechanic.mechanictype),
                            const SizedBox(height: 12),
                            _buildDetailRow(Icons.map_outlined, "Location", widget.mechanic.mechanicLocName),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                onPressed: widget.mechanic.phone.trim().isNotEmpty
                                    ? () async {
                                        final Uri launchUri = Uri(scheme: 'tel', path: widget.mechanic.phone);
                                        if (await canLaunchUrl(launchUri)) {
                                          await launchUrl(launchUri);
                                        }
                                      }
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  side: BorderSide(color: primaryColor, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                                child: Icon(Icons.call_rounded, color: primaryColor),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Request sent to mechanic'))
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Send Request', 
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarLarge() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: CircleAvatar(
        radius: 40,
        backgroundImage: widget.mechanic.avatarUrl.startsWith('http')
            ? NetworkImage(widget.mechanic.avatarUrl)
            : (widget.mechanic.avatarUrl.isNotEmpty
                ? AssetImage(widget.mechanic.avatarUrl)
                : const AssetImage('assets/images/car.jpg')) as ImageProvider,
      ),
    );
  }

  Widget _buildHeaderInfo({bool isHeaderFilled = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.mechanic.name,
                style: GoogleFonts.luckiestGuy(
                  fontSize: 24, 
                  fontWeight: FontWeight.normal, 
                  color: isHeaderFilled ? Colors.white : Colors.black87,
                  letterSpacing: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildOnlineBadge(isHeaderFilled: isHeaderFilled),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.mechanic.mechanictype,
          style: TextStyle(
            fontSize: 14, 
            color: isHeaderFilled ? Colors.white.withOpacity(0.9) : Colors.grey.shade600, 
            fontWeight: FontWeight.w500
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineBadge({bool isHeaderFilled = false}) {
    final bool isOnline = widget.mechanic.isOnline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHeaderFilled 
            ? (isOnline ? Colors.green.shade400.withOpacity(0.3) : Colors.white.withOpacity(0.2))
            : (isOnline ? Colors.green.shade50 : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(8),
        border: isHeaderFilled ? Border.all(color: Colors.white.withOpacity(0.5), width: 0.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? (isHeaderFilled ? Colors.greenAccent : Colors.green) : (isHeaderFilled ? Colors.white70 : Colors.grey),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? "Online" : "Offline",
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.bold, 
              color: isHeaderFilled ? Colors.white : (isOnline ? Colors.green.shade700 : Colors.grey.shade700)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleTag({required IconData icon, required String label, required Color color, Color? bgColor, Color? iconColor}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: iconColor ?? color),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color, 
              fontWeight: FontWeight.bold, 
              fontSize: 13,
              letterSpacing: 0.5
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : "Not specified",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openFullScreenMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenMapScreen(
          mechanic: widget.mechanic,
          markerIcon: _markerIcon,
        ),
      ),
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
      mechanictype: ' Mechanic',
      avatarUrl: '',
      rating: 4.8,
      distanceKm: 2.6,
      isOnline: true,
      phone: '+1234567890',
      lat: 37.4219983,
      lng: -122.084,
      experienceYears: 6,
      mechanicLocName: 'Downtown Garage',
    );

    return MechanicDetailScreen(mechanic: mechanic);
  }
}

// Full Screen Map Implementation
class FullScreenMapScreen extends StatelessWidget {
  final Mechanic mechanic;
  final BitmapDescriptor? markerIcon;

  const FullScreenMapScreen({super.key, required this.mechanic, this.markerIcon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(mechanic.lat, mechanic.lng),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('mechanic_loc'),
                position: LatLng(mechanic.lat, mechanic.lng),
                icon: markerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: mechanic.name,
                  snippet: '${mechanic.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
            },
            zoomControlsEnabled: false, 
            myLocationButtonEnabled: false,
          ),
          // Close Button
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // Optional: Bottom Card for context
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: mechanic.avatarUrl.startsWith('http')
                        ? NetworkImage(mechanic.avatarUrl)
                        : (mechanic.avatarUrl.isNotEmpty ? AssetImage(mechanic.avatarUrl) : const AssetImage('assets/images/car.jpg')) as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mechanic.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                      Text('${mechanic.distanceKm.toStringAsFixed(1)} km away', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
