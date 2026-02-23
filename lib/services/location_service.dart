import 'package:geolocator/geolocator.dart';

/// Helper to fetch the device's current GPS position.
class LocationService {
  /// Requests permission and returns the current position, or null on failure.
  static Future<Position?> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return pos;
    } catch (e) {
      return null;
    }
  }
}
