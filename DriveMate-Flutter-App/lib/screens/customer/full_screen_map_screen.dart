import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

class FullScreenMapScreen extends StatefulWidget {
  const FullScreenMapScreen({super.key});

  @override
  State<FullScreenMapScreen> createState() => _FullScreenMapScreenState();
}

class _FullScreenMapScreenState extends State<FullScreenMapScreen> {
  late final MapController _mapController;
  LatLng? _currentGpsLocation;
  bool _isLocating = false;
  int _mapStyleIndex = 0; // 0: Standard, 1: Dark Carto, 2: Transit/HOT

  final List<Map<String, String>> _mapStyles = const [
    {
      'name': 'Standard OSM',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors',
    },
    {
      'name': 'Dark Navigation',
      'url': 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
      'attribution': '© CARTO, © OpenStreetMap',
    },
    {
      'name': 'Humanitarian / Transit',
      'url': 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors, Humanitarian',
    },
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitRouteBounds();
    });
  }

  void _fitRouteBounds() {
    final provider = context.read<DriveMateProvider>();
    final points = <LatLng>[];
    if (provider.currentRoutePolyline.isNotEmpty) {
      points.addAll(provider.currentRoutePolyline);
    } else {
      points.add(provider.searchQuery.pickupCoordinates);
      points.add(provider.searchQuery.destinationCoordinates);
    }

    if (points.length >= 2) {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(top: 80, bottom: 220, left: 40, right: 40),
        ),
      );
    }
  }

  Future<void> _handleMyLocation() async {
    setState(() => _isLocating = true);
    final result = await LocationService.getCurrentLocation();
    if (!mounted) return;

    setState(() {
      _isLocating = false;
      if (result.isGpsDetected) {
        _currentGpsLocation = result.coordinates;
      }
    });

    if (result.isGpsDetected) {
      _mapController.move(result.coordinates, 16.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS Location acquired'),
          backgroundColor: AppColors.successGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Could not acquire GPS position'),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _cycleMapStyle() {
    setState(() {
      _mapStyleIndex = (_mapStyleIndex + 1) % _mapStyles.length;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Map Style: ${_mapStyles[_mapStyleIndex]['name']}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final pickup = provider.searchQuery.pickupCoordinates;
    final destination = provider.searchQuery.destinationCoordinates;
    final polyline = provider.currentRoutePolyline;
    final distKm = provider.routeDistanceKm;
    final durMin = provider.routeDurationMins;
    final routeAlternatives = provider.routeAlternatives;
    final selectedRouteIdx = provider.selectedRouteIndex;

    final markers = <Marker>[];

    // 1. Current GPS Location Marker (Pulsing Blue Indicator)
    if (_currentGpsLocation != null) {
      markers.add(
        Marker(
          point: _currentGpsLocation!,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.55),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      );
    }

    // 2. Green Pickup Marker
    markers.add(
      Marker(
        point: pickup,
        width: 100,
        height: 65,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.successGreen,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: const Text(
                'PICKUP',
                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(Icons.location_on, color: AppColors.successGreen, size: 30),
          ],
        ),
      ),
    );

    // 3. Red Destination Marker
    markers.add(
      Marker(
        point: destination,
        width: 100,
        height: 65,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.errorRed,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: const Text(
                'DESTINATION',
                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(Icons.location_on, color: AppColors.errorRed, size: 30),
          ],
        ),
      ),
    );

    // Midpoint marker with ETA Tag on polyline
    if (polyline.length > 2) {
      final midPoint = polyline[polyline.length ~/ 2];
      markers.add(
        Marker(
          point: midPoint,
          width: 96,
          height: 32,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.navy900.withOpacity(0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cyanAccent, width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.speed_rounded, color: AppColors.cyanAccent, size: 13),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '$durMin min',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Full Screen Map View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: pickup,
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: _mapStyles[_mapStyleIndex]['url']!,
                userAgentPackageName: 'com.drivemate.drivemate_flutter',
              ),
              if (polyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polyline,
                      color: AppColors.electricBlue,
                      strokeWidth: 6.0,
                      strokeJoin: StrokeJoin.round,
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.bgDark.withOpacity(0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderSubtle),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),

                    // Map Style Badge / Switcher
                    InkWell(
                      onTap: _cycleMapStyle,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bgDark.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderSubtle),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.layers_rounded, color: AppColors.cyanAccent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _mapStyles[_mapStyleIndex]['name']!,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating Controls (Right side)
          Positioned(
            right: 16,
            bottom: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In
                _buildFloatingButton(
                  icon: Icons.add,
                  onTap: () {
                    final z = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, z + 1);
                  },
                ),
                const SizedBox(height: 8),
                // Zoom Out
                _buildFloatingButton(
                  icon: Icons.remove,
                  onTap: () {
                    final z = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, z - 1);
                  },
                ),
                const SizedBox(height: 8),
                // Fit Route Bounds
                _buildFloatingButton(
                  icon: Icons.center_focus_strong_rounded,
                  onTap: _fitRouteBounds,
                ),
                const SizedBox(height: 8),
                // My Location
                _buildFloatingButton(
                  icon: Icons.my_location,
                  isLoading: _isLocating,
                  onTap: _handleMyLocation,
                ),
              ],
            ),
          ),

          // Bottom Route Details Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg.withOpacity(0.96),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Distance & Duration Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.route_rounded, color: AppColors.cyanAccent, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '$distKm km • $durMin mins',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '₹${provider.calculatedFare.toInt()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: AppColors.borderSubtle, height: 1),
                  const SizedBox(height: 10),

                  // Route Alternatives Selector
                  if (routeAlternatives.isNotEmpty) ...[
                    const Text(
                      'Select Route:',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Column(
                      children: List.generate(routeAlternatives.length, (idx) {
                        final opt = routeAlternatives[idx];
                        final isSel = selectedRouteIdx == idx;
                        return InkWell(
                          onTap: () => provider.selectRouteOption(idx),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primaryBlue.withOpacity(0.14) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSel ? AppColors.primaryBlue : Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSel ? AppColors.cyanAccent : AppColors.textSecondary,
                                  size: 15,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    opt.name,
                                    style: TextStyle(
                                      color: isSel ? Colors.white : AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${opt.distanceKm} km',
                                  style: TextStyle(
                                    color: isSel ? AppColors.cyanAccent : AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Confirm and Book Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        provider.navigateTo(ActiveCustomerScreen.hireDriverFlow);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Proceed with this Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.bgDark.withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyanAccent),
                  )
                : Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
