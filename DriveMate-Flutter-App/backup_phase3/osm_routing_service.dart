import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'location_service.dart';

class PlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng coordinates;
  final String type;

  PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.coordinates,
    this.type = 'location',
  });
}

class OsmRouteResult {
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> polylinePoints;
  final String startAddress;
  final String endAddress;
  final LatLng startLocation;
  final LatLng endLocation;
  final bool isSuccess;
  final String? errorMessage;

  OsmRouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
    required this.startAddress,
    required this.endAddress,
    required this.startLocation,
    required this.endLocation,
    required this.isSuccess,
    this.errorMessage,
  });
}

class OsmRoutingService {
  // Public Photon Geocoding Endpoint (OpenStreetMap based, by Komoot)
  static const String photonBaseUrl = 'https://photon.komoot.io/api';

  // Public OSRM Road Routing Server
  static const String osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';

  // Local DriveMate PHP REST Backend
  static const String localApiBaseUrl = 'http://localhost/drivemate-api/public/index.php/api';

  // Curated Kakdwip & Regional Transit Centers
  static final List<PlaceSuggestion> curatedKakdwipPlaces = [
    PlaceSuggestion(
      title: 'Kakdwip Railway Station',
      subtitle: 'South 24 Parganas, West Bengal 743347',
      coordinates: const LatLng(21.8767, 88.1912),
      type: 'railway_station',
    ),
    PlaceSuggestion(
      title: 'Kakdwip Bus Stand',
      subtitle: 'NH 117 (Diamond Harbour - Kakdwip Highway), WB 743347',
      coordinates: const LatLng(21.8742, 88.1873),
      type: 'bus_station',
    ),
    PlaceSuggestion(
      title: 'Kakdwip Market',
      subtitle: 'Station Road, Kakdwip Central, WB 743347',
      coordinates: const LatLng(21.8755, 88.1890),
      type: 'market',
    ),
    PlaceSuggestion(
      title: 'Kakdwip Ferry Ghat (Lot 8)',
      subtitle: 'Ferry terminal to Sagar Island (Ganga Sagar), WB 743347',
      coordinates: const LatLng(21.8712, 88.1824),
      type: 'ferry_terminal',
    ),
    PlaceSuggestion(
      title: 'Kakdwip Sub-Divisional Hospital',
      subtitle: 'Hospital More, Kakdwip, West Bengal 743347',
      coordinates: const LatLng(21.8780, 88.1865),
      type: 'hospital',
    ),
    PlaceSuggestion(
      title: 'Diamond Harbour Station',
      subtitle: 'Diamond Harbour, South 24 Parganas, WB 743331',
      coordinates: const LatLng(22.1918, 88.1925),
      type: 'railway_station',
    ),
    PlaceSuggestion(
      title: 'Namkhana Railway Station',
      subtitle: 'Namkhana, South 24 Parganas, WB 743357',
      coordinates: const LatLng(21.7694, 88.2325),
      type: 'railway_station',
    ),
    PlaceSuggestion(
      title: 'Kolkata Airport (CCU)',
      subtitle: 'Netaji Subhash Chandra Bose Intl Airport, Kolkata, WB',
      coordinates: const LatLng(22.6547, 88.4467),
      type: 'airport',
    ),
    PlaceSuggestion(
      title: 'Howrah Railway Station',
      subtitle: 'Howrah, West Bengal 711101',
      coordinates: const LatLng(22.5839, 88.3426),
      type: 'railway_station',
    ),
  ];

  /// Queries Photon OpenStreetMap autocomplete with local fallback
  static Future<List<PlaceSuggestion>> searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final List<PlaceSuggestion> results = [];
    final lower = cleanQuery.toLowerCase();

    // 1. Check curated Kakdwip / Regional stations first for instant matching
    for (final place in curatedKakdwipPlaces) {
      if (place.title.toLowerCase().contains(lower) || place.subtitle.toLowerCase().contains(lower)) {
        results.add(place);
      }
    }

    // 2. Query Photon Geocoding API (OpenStreetMap data)
    try {
      final photonUri = Uri.parse('$photonBaseUrl/?q=${Uri.encodeComponent(cleanQuery)}&limit=6&lang=en');
      final response = await http.get(
        photonUri,
        headers: {'User-Agent': 'DriveMate-India-App/2.0 (contact: support@drivemate.in)'},
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];

        for (final item in features) {
          final props = item['properties'] as Map<String, dynamic>? ?? {};
          final geom = item['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geom['coordinates'] as List<dynamic>? ?? [];

          if (coords.length >= 2) {
            final lng = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();

            final name = props['name']?.toString() ?? props['street']?.toString() ?? 'Location';
            final city = props['city'] ?? props['district'] ?? props['state'] ?? 'India';
            final country = props['country'] ?? 'India';

            // Avoid adding duplicates
            if (!results.any((r) => (r.coordinates.latitude - lat).abs() < 0.001 && (r.coordinates.longitude - lng).abs() < 0.001)) {
              results.add(PlaceSuggestion(
                title: name,
                subtitle: '$name, $city, $country',
                coordinates: LatLng(lat, lng),
                type: props['osm_value']?.toString() ?? 'place',
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OsmRoutingService] Photon network query error: $e');
    }

    // If query didn't return any Photon results and curated is empty, return popular defaults
    if (results.isEmpty) {
      return curatedKakdwipPlaces.take(4).toList();
    }

    return results;
  }

  /// Calculates actual road route using OSRM driving engine
  static Future<OsmRouteResult> fetchRoute({
    required LatLng start,
    required LatLng destination,
    String? startAddress,
    String? destinationAddress,
  }) async {
    final startAddr = startAddress ?? 'Pickup (${start.latitude.toStringAsFixed(4)}, ${start.longitude.toStringAsFixed(4)})';
    final destAddr = destinationAddress ?? 'Destination (${destination.latitude.toStringAsFixed(4)}, ${destination.longitude.toStringAsFixed(4)})';

    // 1. Query live OSRM public routing server with GeoJSON coordinates
    try {
      final url = '$osrmBaseUrl/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'DriveMate-India-App/2.0'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSec = (route['duration'] as num).toDouble();

          final rawCoords = route['geometry']['coordinates'] as List<dynamic>;
          final List<LatLng> polyline = [];
          for (final coord in rawCoords) {
            polyline.add(LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()));
          }

          return OsmRouteResult(
            distanceKm: double.parse((distanceMeters / 1000.0).toStringAsFixed(2)),
            durationMinutes: (durationSec / 60.0).round(),
            polylinePoints: polyline,
            startAddress: startAddr,
            endAddress: destAddr,
            startLocation: start,
            endLocation: destination,
            isSuccess: true,
          );
        }
      }
    } catch (e) {
      debugPrint('[OsmRoutingService] OSRM public service error: $e. Falling back to local backend.');
    }

    // 2. Query local backend /maps/directions
    try {
      final localUrl = '$localApiBaseUrl/maps/directions?origin_lat=${start.latitude}&origin_lng=${start.longitude}&dest_lat=${destination.latitude}&dest_lng=${destination.longitude}';
      final response = await http.get(Uri.parse(localUrl)).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          final d = data['data'];
          final List<dynamic> coordsList = d['coordinates'] ?? [];
          final List<LatLng> polyline = coordsList.map((c) => LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble())).toList();

          return OsmRouteResult(
            distanceKm: (d['distance_km'] as num).toDouble(),
            durationMinutes: (d['duration_mins'] as num).toInt(),
            polylinePoints: polyline.isNotEmpty ? polyline : [start, destination],
            startAddress: startAddr,
            endAddress: destAddr,
            startLocation: start,
            endLocation: destination,
            isSuccess: true,
          );
        }
      }
    } catch (e) {
      debugPrint('[OsmRoutingService] Local backend fallback error: $e');
    }

    // 3. Mathematical geometric fallback with straight-line interpolation
    final directDistanceKm = LocationService.calculateDistanceKm(start, destination);
    final estimatedRoadKm = double.parse((directDistanceKm * 1.25).toStringAsFixed(2));
    final estimatedMinutes = (estimatedRoadKm * 2.2).round();

    return OsmRouteResult(
      distanceKm: estimatedRoadKm > 0.5 ? estimatedRoadKm : 14.8,
      durationMinutes: estimatedMinutes > 2 ? estimatedMinutes : 28,
      polylinePoints: [
        start,
        LatLng(start.latitude + (destination.latitude - start.latitude) * 0.35, start.longitude + (destination.longitude - start.longitude) * 0.3),
        LatLng(start.latitude + (destination.latitude - start.latitude) * 0.7, start.longitude + (destination.longitude - start.longitude) * 0.65),
        destination,
      ],
      startAddress: startAddr,
      endAddress: destAddr,
      startLocation: start,
      endLocation: destination,
      isSuccess: true,
      errorMessage: 'Simulated road interpolation (offline mode).',
    );
  }
}
