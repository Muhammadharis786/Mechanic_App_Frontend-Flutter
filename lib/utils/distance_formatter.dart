/// Formats distances for display in the mechanic tracking UI.
class DistanceFormatter {
  /// Under 1 km → meters (e.g. `444 m`, `80 m`).
  /// 1 km and above → kilometers (e.g. `1 km`, `1.6 km`, `12 km`).
  static String formatMeters(double meters) {
    if (meters.isNaN || meters.isInfinite || meters < 0) {
      return '--';
    }

    if (meters < 1000) {
      final rounded = meters.round();
      return '$rounded m';
    }

    final km = meters / 1000;
    final roundedKm = (km * 10).round() / 10;
    if (roundedKm == roundedKm.roundToDouble()) {
      return '${roundedKm.toInt()} km';
    }
    return '$roundedKm km';
  }

  /// Parses API error text like `NOT ARRIVED - mechanic is 4440 meters away`.
  static String? parseMetersFromNotArrivedBody(String body) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*meters?\s*away',
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) return null;
    final meters = double.tryParse(match.group(1)!);
    if (meters == null) return null;
    return formatMeters(meters);
  }

  /// Backend tracking APIs send distance in **kilometers** (e.g. `1.5` = 1.5 km).
  static String formatKilometers(dynamic value) {
    if (value == null) return '--';

    if (value is num) {
      return formatMeters(value.toDouble() * 1000);
    }

    final text = value.toString().trim();
    if (text.isEmpty || text == '--') return '--';

    final lower = text.toLowerCase();
    if (lower.endsWith('km')) {
      final km = double.tryParse(lower.replaceAll('km', '').trim());
      if (km != null) return formatMeters(km * 1000);
    }
    if (lower.endsWith('m') && !lower.endsWith('km')) {
      final meters = double.tryParse(lower.replaceAll('m', '').trim());
      if (meters != null) return formatMeters(meters);
    }

    final asKm = double.tryParse(text);
    if (asKm != null) {
      return formatMeters(asKm * 1000);
    }

    return text;
  }

  /// Values already in meters (e.g. haversine / isarrived error text).
  static String formatDynamic(dynamic value) {
    if (value == null) return '--';

    if (value is num) {
      return formatMeters(value.toDouble());
    }

    final text = value.toString().trim();
    if (text.isEmpty || text == '--') return '--';

    final lower = text.toLowerCase();
    if (lower.endsWith('km')) {
      final km = double.tryParse(lower.replaceAll('km', '').trim());
      if (km != null) return formatMeters(km * 1000);
    }
    if (lower.endsWith('m') && !lower.endsWith('km')) {
      final meters = double.tryParse(lower.replaceAll('m', '').trim());
      if (meters != null) return formatMeters(meters);
    }

    final asNumber = double.tryParse(text);
    if (asNumber != null) {
      return formatMeters(asNumber);
    }

    return text;
  }
}
