import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Loads a map marker asset at an exact pixel size.
///
/// [BitmapDescriptor.fromAssetImage] can render 512×512 assets at full
/// resolution on Android; this helper always downsizes first.
Future<BitmapDescriptor> mapMarkerFromAsset(
  String assetPath, {
  int size = 48,
}) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: size,
    targetHeight: size,
  );
  final frame = await codec.getNextFrame();
  final byteData =
      await frame.image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
}
