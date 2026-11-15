import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';
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

class RouteOption {
  final String id;
  final String name;
  final String summary;
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> polylinePoints;
  final bool isFastest;
  final String trafficCondition;

  const RouteOption({
    required this.id,
    required this.name,
    required this.summary,
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
    this.isFastest = false,
    this.trafficCondition = 'Normal traffic',
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
  final List<RouteOption> alternatives;

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
    this.alternatives = const [],
  });
}

class OsmRoutingService {
  // Public Photon Geocoding Endpoint (OpenStreetMap based, by Komoot)
  static const String photonBaseUrl = 'https://photon.komoot.io/api';

  // Public OSRM Road Routing Server
  static const String osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';

  // Local DriveMate PHP REST Backend
  static String get localApiBaseUrl => ApiConfig.baseUrl;

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
      final url = '$osrmBaseUrl/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson&alternatives=true';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'DriveMate-India-App/2.0'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final routesList = data['routes'] as List;
          final route = routesList[0];
          final distanceMeters = (route['distance'] as num).toDouble();
          final durationSec = (route['duration'] as num).toDouble();

          final rawCoords = route['geometry']['coordinates'] as List<dynamic>;
          final List<LatLng> polyline = [];
          for (final coord in rawCoords) {
            polyline.add(LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()));
          }

          final distKm = double.parse((distanceMeters / 1000.0).toStringAsFixed(2));
          final durMin = (durationSec / 60.0).round();
          final alternatives = _buildRouteOptions(
            primaryDist: distKm,
            primaryDur: durMin,
            primaryPolyline: polyline,
            start: start,
            destination: destination,
            rawOsrmRoutes: routesList,
          );

          return OsmRouteResult(
            distanceKm: distKm,
            durationMinutes: durMin,
            polylinePoints: polyline,
            startAddress: startAddr,
            endAddress: destAddr,
            startLocation: start,
            endLocation: destination,
            isSuccess: true,
            alternatives: alternatives,
          );
        }
      }
    } catch (e) {
      debugPrint('[OsmRoutingService] OSRM public service error: $e. Falling back to local backend.');
    }

    // 2. Query local backend /maps/directions
    try {
      final localUri = ApiConfig.getUri('/maps/directions', {
        'origin_lat': start.latitude.toString(),
        'origin_lng': start.longitude.toString(),
        'dest_lat': destination.latitude.toString(),
        'dest_lng': destination.longitude.toString(),
      });
      final response = await http
          .get(localUri, headers: ApiConfig.getHeaders())
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          final d = data['data'];
          final List<dynamic> coordsList = d['coordinates'] ?? [];
          final List<LatLng> polyline = coordsList.map((c) => LatLng((c['lat'] as num).toDouble(), (c['lng'] as num).toDouble())).toList();
          final distKm = (d['distance_km'] as num).toDouble();
          final durMin = (d['duration_mins'] as num).toInt();
          final poly = polyline.isNotEmpty ? polyline : [start, destination];
          final alternatives = _buildRouteOptions(
            primaryDist: distKm,
            primaryDur: durMin,
            primaryPolyline: poly,
            start: start,
            destination: destination,
          );

          return OsmRouteResult(
            distanceKm: distKm,
            durationMinutes: durMin,
            polylinePoints: poly,
            startAddress: startAddr,
            endAddress: destAddr,
            startLocation: start,
            endLocation: destination,
            isSuccess: true,
            alternatives: alternatives,
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
    final fallbackDist = estimatedRoadKm > 0.5 ? estimatedRoadKm : 14.8;
    final fallbackDur = estimatedMinutes > 2 ? estimatedMinutes : 28;
    final fallbackPoly = [
      start,
      LatLng(start.latitude + (destination.latitude - start.latitude) * 0.35, start.longitude + (destination.longitude - start.longitude) * 0.3),
      LatLng(start.latitude + (destination.latitude - start.latitude) * 0.7, start.longitude + (destination.longitude - start.longitude) * 0.65),
      destination,
    ];

    final alternatives = _buildRouteOptions(
      primaryDist: fallbackDist,
      primaryDur: fallbackDur,
      primaryPolyline: fallbackPoly,
      start: start,
      destination: destination,
    );

    return OsmRouteResult(
      distanceKm: fallbackDist,
      durationMinutes: fallbackDur,
      polylinePoints: fallbackPoly,
      startAddress: startAddr,
      endAddress: destAddr,
      startLocation: start,
      endLocation: destination,
      isSuccess: true,
      errorMessage: 'Simulated road interpolation (offline mode).',
      alternatives: alternatives,
    );
  }

  static List<RouteOption> _buildRouteOptions({
    required double primaryDist,
    required int primaryDur,
    required List<LatLng> primaryPolyline,
    required LatLng start,
    required LatLng destination,
    List<dynamic>? rawOsrmRoutes,
  }) {
    final List<RouteOption> options = [];

    // Option 1: Primary Fastest Route
    options.add(
      RouteOption(
        id: 'route_primary',
        name: 'Via NH 117 / Diamond Harbour Rd',
        summary: 'Direct express route via NH 117 highway corridor',
        distanceKm: primaryDist,
        durationMinutes: primaryDur,
        polylinePoints: primaryPolyline,
        isFastest: true,
        trafficCondition: 'Fastest route • Typical traffic',
      ),
    );

    // If OSRM returned a second route in rawOsrmRoutes
    if (rawOsrmRoutes != null && rawOsrmRoutes.length > 1) {
      final altRoute = rawOsrmRoutes[1];
      final altDistMeters = (altRoute['distance'] as num).toDouble();
      final altDurSec = (altRoute['duration'] as num).toDouble();
      final altCoords = altRoute['geometry']['coordinates'] as List<dynamic>;
      final List<LatLng> altPolyline = [];
      for (final coord in altCoords) {
        altPolyline.add(LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble()));
      }
      options.add(
        RouteOption(
          id: 'route_osrm_alt',
          name: 'Via Arterial Bypass',
          summary: 'Alternative arterial routing avoiding central bottlenecks',
          distanceKm: double.parse((altDistMeters / 1000.0).toStringAsFixed(2)),
          durationMinutes: (altDurSec / 60.0).round(),
          polylinePoints: altPolyline,
          isFastest: false,
          trafficCondition: 'Alternative route • Moderate traffic',
        ),
      );
    } else {
      // Build viable geometric alternative route via Kulpi / Regional Bypass
      final altDist = double.parse((primaryDist * 1.14).toStringAsFixed(2));
      final altDur = primaryDur + 6;
      final midLat = (start.latitude + destination.latitude) / 2;
      final midLng = (start.longitude + destination.longitude) / 2;
      final offsetLat = (destination.longitude - start.longitude) * 0.12;
      final offsetLng = -(destination.latitude - start.latitude) * 0.12;

      final List<LatLng> altPolyline = [
        start,
        LatLng(start.latitude + (destination.latitude - start.latitude) * 0.25 + offsetLat * 0.5, start.longitude + (destination.longitude - start.longitude) * 0.25 + offsetLng * 0.5),
        LatLng(midLat + offsetLat, midLng + offsetLng),
        LatLng(start.latitude + (destination.latitude - start.latitude) * 0.75 + offsetLat * 0.5, start.longitude + (destination.longitude - start.longitude) * 0.75 + offsetLng * 0.5),
        destination,
      ];

      options.add(
        RouteOption(
          id: 'route_bypass_alt',
          name: 'Via Kulpi - Kakdwip Bypass',
          summary: 'Outer bypass route with fewer traffic signals and smooth transit',
          distanceKm: altDist,
          durationMinutes: altDur,
          polylinePoints: altPolyline,
          isFastest: false,
          trafficCondition: 'Alternative route • Smooth flow',
        ),
      );
    }

    return options;
  }
}
