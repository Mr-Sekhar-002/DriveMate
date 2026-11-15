import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationResult {
  final LatLng coordinates;
  final String? address;
  final bool isGpsDetected;
  final String? errorMessage;

  LocationResult({
    required this.coordinates,
    this.address,
    required this.isGpsDetected,
    this.errorMessage,
  });
}

class LocationService {
  // Default regional transit center for initial camera placement in customer UI
  static const LatLng defaultLocation = LatLng(21.8767, 88.1912);
  static const String defaultAddress = 'Kakdwip Railway Station, WB 743347';

  /// Determines genuine device GPS position with Android runtime permission workflow.
  /// Flags `isGpsDetected: false` when genuine GPS signal from device is unavailable.
  static Future<LocationResult> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          coordinates: defaultLocation,
          address: null,
          isGpsDetected: false,
          errorMessage: 'Location services (GPS) are disabled on your device.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            coordinates: defaultLocation,
            address: null,
            isGpsDetected: false,
            errorMessage: 'Location permission was denied. Please allow location access.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          coordinates: defaultLocation,
          address: null,
          isGpsDetected: false,
          errorMessage: 'Location permissions are permanently denied. Please enable them in App Settings.',
        );
      }

      // Permissions granted: Retrieve actual GPS position from device hardware
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final currentLatLng = LatLng(position.latitude, position.longitude);

      return LocationResult(
        coordinates: currentLatLng,
        address: 'Current Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
        isGpsDetected: true,
      );
    } catch (e) {
      debugPrint('[LocationService] GPS detection error: $e');
      return LocationResult(
        coordinates: defaultLocation,
        address: null,
        isGpsDetected: false,
        errorMessage: 'Unable to acquire genuine GPS position from device.',
      );
    }
  }

  /// Calculates straight-line distance between two coordinates in km
  static double calculateDistanceKm(LatLng start, LatLng end) {
    final distanceInMeters = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
    return distanceInMeters / 1000.0;
  }
}
