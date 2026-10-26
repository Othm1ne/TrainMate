import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double lat;
  final double lng;
  final String label; // "City, Country" when reverse geocoding works
  const LocationResult(this.lat, this.lng, this.label);
}

class LocationService {
  LocationService._();
  static final instance = LocationService._();

  /// Current position, or null if permission is denied / services are off.
  Future<LocationResult?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      return LocationResult(
          pos.latitude, pos.longitude, await _label(pos.latitude, pos.longitude));
    } catch (e) {
      debugPrint('Location unavailable: $e');
      return null;
    }
  }

  Future<String> _label(double lat, double lng) async {
    if (kIsWeb) return '';
    try {
      final marks = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return '';
      final p = marks.first;
      return [p.locality, p.country]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
    } catch (_) {
      return '';
    }
  }

  /// Coordinates of a free-text address (used for event places).
  Future<(double, double)?> geocode(String address) async {
    if (kIsWeb || address.trim().isEmpty) return null;
    try {
      final res = await Geocoding().locationFromAddress(address);
      if (res.isEmpty) return null;
      return (res.first.latitude, res.first.longitude);
    } catch (_) {
      return null;
    }
  }
}
