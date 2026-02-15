import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
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
    // debugPrint("Mechanic Detail: ${widget.mechanic.name}");
    // debugPrint("Lat: ${widget.mechanic.lat}, Lng: ${widget.mechanic.lng}");

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

              // Map Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                           height: 200, 
                           child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect( 
                                 borderRadius: BorderRadius.circular(12),
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
                                    liteModeEnabled: false, 
                                    myLocationButtonEnabled: false,
                                    onTap: (_) => _openFullScreenMap(context),
                                  ),
                              ),
                           ),
                        ),
                        // Overlay to capture tap if map doesn't
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openFullScreenMap(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _openFullScreenMap(context),
                        icon: const Icon(Icons.fullscreen, size: 18, color: Colors.grey),
                        label: const Text("View Full Map", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Call Mechanic Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.mechanic.phone.trim().isNotEmpty
                        ? () async {
                             final Uri launchUri = Uri(scheme: 'tel', path: widget.mechanic.phone);
                             if (await canLaunchUrl(launchUri)) {
                               await launchUrl(launchUri);
                             } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not launch dialer for ${widget.mechanic.phone}'))
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

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 36,
      backgroundImage: widget.mechanic.avatarUrl.startsWith('http')
          ? NetworkImage(widget.mechanic.avatarUrl)
          : (widget.mechanic.avatarUrl.isNotEmpty
              ? AssetImage(widget.mechanic.avatarUrl)
              : const AssetImage('assets/images/car.jpg')) as ImageProvider,
    );
  }

  Widget _buildMechanicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.mechanic.name,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.normal, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.work_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(widget.mechanic.mechanictype, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: Colors.redAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${widget.mechanic.mechanicLocName.isNotEmpty ? "${widget.mechanic.mechanicLocName} • " : ""}${widget.mechanic.distanceKm.toStringAsFixed(1)} km away',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
          Text(widget.mechanic.rating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor)),
        ],
      ),
    );
  }

  Widget _buildDistanceTile() {
    return Row(
      children: [
        Icon(Icons.place_outlined, size: 16, color: primaryColor),
        const SizedBox(width: 6),
        Text('${widget.mechanic.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
      ],
    );
  }

  Widget _buildStatusTag() {
    final color = widget.mechanic.isOnline ? Colors.green.shade600 : Colors.grey.shade600;
    final text = widget.mechanic.isOnline ? 'Online' : 'Offline';
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
      child: Text('${widget.mechanic.experienceYears} yrs experience', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primaryColor)),
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
