import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/drivemate_provider.dart';
import '../screens/customer/full_screen_map_screen.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

/// Premium interactive route calculator and live map preview component
class InteractiveRouteMapPreview extends StatefulWidget {
  const InteractiveRouteMapPreview({super.key});

  @override
  State<InteractiveRouteMapPreview> createState() => _InteractiveRouteMapPreviewState();
}

class _InteractiveRouteMapPreviewState extends State<InteractiveRouteMapPreview> {
  late final MapController _mapController;
  LatLng? _currentGpsLocation;
  bool _isLocating = false;
  int _mapStyleIndex = 0; // 0: Standard, 1: Dark, 2: Transit

  final List<Map<String, String>> _mapStyles = const [
    {
      'name': 'Standard',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    },
    {
      'name': 'Dark',
      'url': 'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
    },
    {
      'name': 'Transit',
      'url': 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
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
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
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
      _mapController.move(result.coordinates, 15.5);
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
    final isCalculating = provider.isCalculatingRoute;
    final routeAlternatives = provider.routeAlternatives;
    final selectedRouteIdx = provider.selectedRouteIndex;

    final markers = <Marker>[];

    // 1. Blue Location Indicator for Current Device GPS
    if (_currentGpsLocation != null) {
      markers.add(
        Marker(
          point: _currentGpsLocation!,
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.navigation_rounded, color: Colors.white, size: 13),
            ),
          ),
        ),
      );
    }

    // 2. Green Pickup Marker
    markers.add(
      Marker(
        point: pickup,
        width: 80,
        height: 52,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.successGreen,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 4),
                ],
              ),
              child: const Text(
                'PICKUP',
                style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(Icons.location_on, color: AppColors.successGreen, size: 26),
          ],
        ),
      ),
    );

    // 3. Red Destination Marker
    markers.add(
      Marker(
        point: destination,
        width: 80,
        height: 52,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.errorRed,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 4),
                ],
              ),
              child: const Text(
                'DESTINATION',
                style: TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(Icons.location_on, color: AppColors.errorRed, size: 26),
          ],
        ),
      ),
    );

    // Midpoint ETA duration tag on the route polyline (matching sample images)
    if (polyline.length > 2) {
      final midPoint = polyline[polyline.length ~/ 2];
      markers.add(
        Marker(
          point: midPoint,
          width: 96,
          height: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.navy900.withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cyanAccent, width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.cyanAccent, size: 12),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    '$durMin min',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Map Preview Container (245 logical pixels height)
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 245,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: AppColors.softShadow,
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: pickup,
                    initialZoom: 14.5,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    // OpenStreetMap Tiles Layer with Style Support
                    TileLayer(
                      urlTemplate: _mapStyles[_mapStyleIndex]['url']!,
                      userAgentPackageName: 'com.drivemate.drivemate_flutter',
                    ),

                    // Actual Blue Route Polyline
                    if (polyline.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: polyline,
                            color: AppColors.electricBlue,
                            strokeWidth: 5.5,
                            strokeJoin: StrokeJoin.round,
                            strokeCap: StrokeCap.round,
                          ),
                        ],
                      ),

                    // Markers
                    MarkerLayer(markers: markers),
                  ],
                ),

                // Top Left: Map Style Tag
                Positioned(
                  top: 10,
                  left: 10,
                  child: InkWell(
                    onTap: _cycleMapStyle,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.navy900.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers_rounded, color: AppColors.cyanAccent, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            _mapStyles[_mapStyleIndex]['name']!,
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Floating Map Controls (Right Side)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Full Screen Button
                      _buildFloatingMapButton(
                        icon: Icons.fullscreen_rounded,
                        tooltip: 'Full Screen Map',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FullScreenMapScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      // Zoom In Button
                      _buildFloatingMapButton(
                        icon: Icons.add,
                        tooltip: 'Zoom In',
                        onTap: () {
                          final z = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, z + 1);
                        },
                      ),
                      const SizedBox(height: 6),
                      // Zoom Out Button
                      _buildFloatingMapButton(
                        icon: Icons.remove,
                        tooltip: 'Zoom Out',
                        onTap: () {
                          final z = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, z - 1);
                        },
                      ),
                      const SizedBox(height: 6),
                      // Fit Route Bounds Button
                      _buildFloatingMapButton(
                        icon: Icons.center_focus_strong_rounded,
                        tooltip: 'Fit Route',
                        onTap: _fitRouteBounds,
                      ),
                      const SizedBox(height: 6),
                      // My Location Button
                      _buildFloatingMapButton(
                        icon: Icons.my_location,
                        tooltip: 'My Location',
                        isLoading: _isLocating,
                        onTap: _handleMyLocation,
                      ),
                    ],
                  ),
                ),

                // Loading Indicator Overlay while routing
                if (isCalculating)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.45),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.cyanAccent),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Calculating road route via OSRM...',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 2. Route Information Card (Below the map)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pickup & Destination Address Timeline
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indicators Column
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 24,
                          color: AppColors.borderSubtle,
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.errorRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Addresses Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pickup
                        Text(
                          provider.searchQuery.pickupLocation.isNotEmpty
                              ? provider.searchQuery.pickupLocation
                              : 'Kakdwip Railway Station, WB',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Destination
                        Text(
                          provider.searchQuery.destination.isNotEmpty
                              ? provider.searchQuery.destination
                              : 'Kakdwip Ferry Ghat (Lot 8)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Divider(color: AppColors.borderSubtle, height: 18),

              // Estimated Telemetry Bar: Distance, Travel Duration, Fare
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTelemetryPill(
                    icon: Icons.straighten_rounded,
                    label: 'Distance',
                    value: '$distKm km',
                    accent: AppColors.cyanAccent,
                  ),
                  Container(width: 1, height: 24, color: AppColors.borderSubtle),
                  _buildTelemetryPill(
                    icon: Icons.schedule_rounded,
                    label: 'Est. Duration',
                    value: '$durMin mins',
                    accent: AppColors.primaryBlue,
                  ),
                  Container(width: 1, height: 24, color: AppColors.borderSubtle),
                  _buildTelemetryPill(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Est. Fare',
                    value: '₹${provider.calculatedFare.toInt()}',
                    accent: AppColors.accentGold,
                  ),
                ],
              ),

              // Selected Route & Alternative Route Selection
              if (routeAlternatives.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Route Options:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Column(
                  children: List.generate(routeAlternatives.length, (idx) {
                    final opt = routeAlternatives[idx];
                    final isSel = selectedRouteIdx == idx;
                    return InkWell(
                      onTap: () {
                        provider.selectRouteOption(idx);
                        _fitRouteBounds();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        margin: const EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primaryBlue.withOpacity(0.12) : AppColors.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSel ? AppColors.primaryBlue : AppColors.borderSubtle,
                            width: isSel ? 1.4 : 1,
                          ),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.name,
                                    style: TextStyle(
                                      color: isSel ? Colors.white : AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    opt.trafficCondition,
                                    style: TextStyle(
                                      color: isSel ? AppColors.cyanAccent : AppColors.textMuted,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${opt.distanceKm} km • ${opt.durationMinutes}m',
                              style: TextStyle(
                                color: isSel ? AppColors.accentCyan : AppColors.textSecondary,
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
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingMapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.navy900.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 4),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(17),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyanAccent),
                    )
                  : Icon(icon, color: Colors.white, size: 17),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryPill({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: accent),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
