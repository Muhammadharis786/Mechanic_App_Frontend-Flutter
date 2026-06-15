import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class SmoothRouteFrame {
  final LatLng position;
  final double bearing;
  final List<LatLng> polylinePoints;

  const SmoothRouteFrame({
    required this.position,
    required this.bearing,
    required this.polylinePoints,
  });
}

/// Keeps a marker gliding along a route like ride-hailing apps.
class SmoothRouteTracker {
  List<LatLng> _route = [];
  double _currentDistance = 0;
  double _targetDistance = 0;
  double _displayBearing = 0;
  LatLng? _displayPosition;
  Duration? _lastTickAt;

  static const double _maxSpeedMps = 22;
  static const double _bearingSmoothing = 0.14;

  void reset(LatLng position) {
    _displayPosition = position;
    _currentDistance = 0;
    _targetDistance = 0;
    _displayBearing = 0;
    _lastTickAt = null;
    _route = [position];
  }

  void setRoute(List<LatLng> points, {LatLng? anchor}) {
    if (points.length < 2) {
      if (points.isNotEmpty) {
        _route = List<LatLng>.from(points);
        _displayPosition ??= points.first;
      }
      return;
    }

    final nextRoute = List<LatLng>.from(points);
    final pivot = anchor ?? _displayPosition ?? nextRoute.first;
    final pivotDistance = _distanceAlongRoute(nextRoute, pivot);
    _route = nextRoute;
    _currentDistance = pivotDistance.clamp(0, _routeLength(nextRoute));
    _targetDistance = math.max(_targetDistance, _currentDistance);
    _displayPosition = _pointAtDistance(_currentDistance);
  }

  void pushGps(LatLng gps, {double? heading}) {
    if (_route.length < 2) {
      _displayPosition = gps;
      _route = [gps, gps];
      _currentDistance = 0;
      _targetDistance = 0;
      if (heading != null && heading.isFinite && heading >= 0) {
        _displayBearing = heading % 360;
      }
      return;
    }

    final snap = _snapToRoute(gps);
    _targetDistance = snap.distanceAlongRoute;

    if (heading != null && heading.isFinite && heading >= 0) {
      _displayBearing = _lerpAngle(_displayBearing, heading % 360, 0.35);
    }
  }

  SmoothRouteFrame? tick(Duration elapsed) {
    if (_route.isEmpty) return null;

    final previousTick = _lastTickAt;
    _lastTickAt = elapsed;
    if (previousTick == null) {
      _displayPosition ??= _route.first;
      return _buildFrame();
    }

    final deltaSeconds =
        (elapsed - previousTick).inMicroseconds / 1000000.0;
    if (deltaSeconds <= 0) return _buildFrame();

    final totalLength = _routeLength(_route);
    if (totalLength <= 0) return _buildFrame();

    final gap = (_targetDistance - _currentDistance).abs();
    final adaptiveSpeed = gap > 35
        ? _maxSpeedMps
        : gap > 12
            ? 14
            : 8;
    final step = adaptiveSpeed * deltaSeconds;

    if (_currentDistance < _targetDistance) {
      _currentDistance = math.min(_currentDistance + step, _targetDistance);
    } else if (_currentDistance > _targetDistance) {
      _currentDistance = math.max(_currentDistance - step, _targetDistance);
    }

    _currentDistance = _currentDistance.clamp(0, totalLength);
    _displayPosition = _pointAtDistance(_currentDistance);

    final segmentBearing = _bearingAtDistance(_currentDistance);
    _displayBearing = _lerpAngle(_displayBearing, segmentBearing, _bearingSmoothing);

    return _buildFrame();
  }

  LatLng? get displayPosition => _displayPosition;

  double get displayBearing => _displayBearing;

  SmoothRouteFrame? _buildFrame() {
    final position = _displayPosition;
    if (position == null) return null;

    return SmoothRouteFrame(
      position: position,
      bearing: _displayBearing,
      polylinePoints: _remainingRouteFrom(_currentDistance),
    );
  }

  List<LatLng> _remainingRouteFrom(double distance) {
    if (_route.isEmpty) return const [];
    if (_route.length == 1) return List<LatLng>.from(_route);

    final points = <LatLng>[_pointAtDistance(distance)];
    var traveled = 0.0;

    for (var i = 0; i < _route.length - 1; i++) {
      final segLen = _distanceMeters(_route[i], _route[i + 1]);
      final segEnd = traveled + segLen;
      if (segEnd > distance + 1) {
        for (var j = i + 1; j < _route.length; j++) {
          points.add(_route[j]);
        }
        break;
      }
      traveled = segEnd;
    }

    if (points.length == 1) {
      points.add(_route.last);
    }
    return points;
  }

  _RouteSnap _snapToRoute(LatLng point) {
    if (_route.length < 2) {
      return _RouteSnap(point, 0);
    }

    var bestDistance = double.infinity;
    var bestAlongRoute = 0.0;
    var traveled = 0.0;

    for (var i = 0; i < _route.length - 1; i++) {
      final start = _route[i];
      final end = _route[i + 1];
      final segLen = _distanceMeters(start, end);
      if (segLen <= 0) continue;

      final projection = _projectOnSegment(point, start, end);
      final distToProjection = _distanceMeters(point, projection);

      if (distToProjection < bestDistance) {
        bestDistance = distToProjection;
        final alongSegment = _distanceMeters(start, projection);
        bestAlongRoute = traveled + alongSegment;
      }
      traveled += segLen;
    }

    return _RouteSnap(point, bestAlongRoute);
  }

  double _distanceAlongRoute(List<LatLng> route, LatLng point) {
    if (route.length < 2) return 0;
    return _snapToRouteOn(route, point).distanceAlongRoute;
  }

  _RouteSnap _snapToRouteOn(List<LatLng> route, LatLng point) {
    var bestDistance = double.infinity;
    var bestAlongRoute = 0.0;
    var traveled = 0.0;

    for (var i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final segLen = _distanceMeters(start, end);
      if (segLen <= 0) continue;

      final projection = _projectOnSegment(point, start, end);
      final distToProjection = _distanceMeters(point, projection);
      if (distToProjection < bestDistance) {
        bestDistance = distToProjection;
        bestAlongRoute = traveled + _distanceMeters(start, projection);
      }
      traveled += segLen;
    }

    return _RouteSnap(point, bestAlongRoute);
  }

  LatLng _pointAtDistance(double distance) {
    if (_route.isEmpty) return const LatLng(0, 0);
    if (_route.length == 1) return _route.first;

    var traveled = 0.0;
    for (var i = 0; i < _route.length - 1; i++) {
      final start = _route[i];
      final end = _route[i + 1];
      final segLen = _distanceMeters(start, end);
      if (segLen <= 0) continue;

      if (traveled + segLen >= distance) {
        final t = ((distance - traveled) / segLen).clamp(0.0, 1.0);
        return LatLng(
          start.latitude + (end.latitude - start.latitude) * t,
          start.longitude + (end.longitude - start.longitude) * t,
        );
      }
      traveled += segLen;
    }
    return _route.last;
  }

  double _bearingAtDistance(double distance) {
    if (_route.length < 2) return _displayBearing;

    var traveled = 0.0;
    for (var i = 0; i < _route.length - 1; i++) {
      final start = _route[i];
      final end = _route[i + 1];
      final segLen = _distanceMeters(start, end);
      if (segLen <= 0) continue;

      if (traveled + segLen >= distance || i == _route.length - 2) {
        return _bearingBetween(start, end);
      }
      traveled += segLen;
    }
    return _bearingBetween(_route[_route.length - 2], _route.last);
  }

  double _routeLength(List<LatLng> route) {
    if (route.length < 2) return 0;
    var total = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      total += _distanceMeters(route[i], route[i + 1]);
    }
    return total;
  }

  LatLng _projectOnSegment(LatLng point, LatLng start, LatLng end) {
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    if (dx == 0 && dy == 0) return start;

    final t = ((point.longitude - start.longitude) * dx +
            (point.latitude - start.latitude) * dy) /
        (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    return LatLng(
      start.latitude + dy * clamped,
      start.longitude + dx * clamped,
    );
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.asin(math.sqrt(h));
  }

  static double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double _lerpAngle(double from, double to, double t) {
    final delta = ((to - from + 540) % 360) - 180;
    return (from + delta * t + 360) % 360;
  }
}

class _RouteSnap {
  final LatLng point;
  final double distanceAlongRoute;

  const _RouteSnap(this.point, this.distanceAlongRoute);
}
