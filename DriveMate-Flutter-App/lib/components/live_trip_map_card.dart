import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/drivemate_models.dart';
import '../services/osm_routing_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class LiveTripMapCard extends StatefulWidget {
  final Trip? trip;
  final Booking? booking;
  final bool isOnline;
  final VoidCallback onSimulateStep;
  final VoidCallback? onCompleteTrip;
  final VoidCallback? onDismissCompleted;
  final Future<void> Function()? onCollectCash;

  const LiveTripMapCard({
    super.key,
    this.trip,
    this.booking,
    this.isOnline = true,
    required this.onSimulateStep,
    this.onCompleteTrip,
    this.onDismissCompleted,
    this.onCollectCash,
  });

  @override
  State<LiveTripMapCard> createState() => _LiveTripMapCardState();
}

class _LiveTripMapCardState extends State<LiveTripMapCard> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  LatLng? _currentGpsLocation;
  String? _locationPermissionError;
  bool _isDetectingLocation = false;
  List<LatLng> _routeCoordinates = [];
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(_pulseController);

    _detectDriverGpsLocation();

    if (widget.trip != null && widget.trip!.status != TripStatus.completed) {
      _loadOsrmRoute();
    }
  }

  @override
  void didUpdateWidget(covariant LiveTripMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tripChanged = widget.trip?.id != oldWidget.trip?.id ||
        widget.trip?.startLocation != oldWidget.trip?.startLocation ||
        widget.trip?.endLocation != oldWidget.trip?.endLocation ||
        widget.trip?.status != oldWidget.trip?.status;

    if (tripChanged) {
      if (widget.trip != null && widget.trip!.status != TripStatus.completed) {
        _loadOsrmRoute();
      } else {
        setState(() {
          _routeCoordinates = [];
          _isLoadingRoute = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Detects genuine device GPS location from hardware sensors.
  /// Never substitutes dummy, mock, sample, or hardcoded coordinates.
  Future<void> _detectDriverGpsLocation({bool animateCamera = false}) async {
    setState(() => _isDetectingLocation = true);
    try {
      final result = await LocationService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        _isDetectingLocation = false;
        if (result.isGpsDetected) {
          _currentGpsLocation = result.coordinates;
          _locationPermissionError = null;
        } else {
          _currentGpsLocation = null;
          _locationPermissionError = result.errorMessage;
        }
      });

      if (animateCamera && _currentGpsLocation != null) {
        _mapController.move(_currentGpsLocation!, 16.0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDetectingLocation = false;
        _currentGpsLocation = null;
        _locationPermissionError = 'Could not acquire device GPS: $e';
      });
    }
  }

  /// Loads OSRM road geometry using only genuine coordinates from database/geocoding.
  Future<void> _loadOsrmRoute() async {
    final trip = widget.trip;
    if (trip == null || trip.status == TripStatus.completed) return;

    // Strict requirement: Only fetch route if genuine coordinates exist
    if (trip.startLat == null || trip.startLng == null || trip.endLat == null || trip.endLng == null) {
      setState(() {
        _routeCoordinates = [];
        _isLoadingRoute = false;
      });
      return;
    }

    setState(() => _isLoadingRoute = true);

    final start = LatLng(trip.startLat!, trip.startLng!);
    final end = LatLng(trip.endLat!, trip.endLng!);

    final routeResult = await OsmRoutingService.fetchRoute(
      start: start,
      destination: end,
      startAddress: trip.startLocation,
      destinationAddress: trip.endLocation,
    );

    if (mounted) {
      setState(() {
        _routeCoordinates = routeResult.polylinePoints;
        _isLoadingRoute = false;
      });
      _fitRouteBounds();
    }
  }

  void _fitRouteBounds() {
    if (_routeCoordinates.length >= 2) {
      try {
        final bounds = LatLngBounds.fromPoints(_routeCoordinates);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          ),
        );
      } catch (_) {}
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  LatLng? _computeDriverPosition(Trip? trip, double progress) {
    if (trip == null) {
      return _currentGpsLocation;
    }
    if (_routeCoordinates.isEmpty) {
      if (trip.currentLat != null && trip.currentLng != null) {
        return LatLng(trip.currentLat!, trip.currentLng!);
      }
      return _currentGpsLocation;
    }
    if (progress <= 0.0) return _routeCoordinates.first;
    if (progress >= 1.0) return _routeCoordinates.last;

    final targetIndex = ((_routeCoordinates.length - 1) * progress).floor();
    return _routeCoordinates[targetIndex.clamp(0, _routeCoordinates.length - 1)];
  }

  String _getManeuverText(Trip? trip) {
    if (trip == null) {
      return widget.isOnline
          ? 'Waiting for Booking'
          : 'You are Offline – Go Online to accept ride requests';
    }

    if (trip.status == TripStatus.assigned) {
      return 'Going to Pickup: ${trip.startLocation}';
    } else if (trip.status == TripStatus.driverArrived) {
      return 'Arrived at Pickup • Ask passenger for Ride OTP';
    } else if (trip.status == TripStatus.onTrip) {
      return 'En Route to Destination: ${trip.endLocation}';
    } else if (trip.status == TripStatus.completed) {
      return 'Trip Completed';
    }

    return 'Waiting for Booking';
  }

  IconData _getManeuverIcon(Trip? trip) {
    if (trip == null) {
      return widget.isOnline ? Icons.radar : Icons.power_settings_new;
    }
    if (trip.status == TripStatus.assigned) return Icons.directions_car;
    if (trip.status == TripStatus.driverArrived) return Icons.pin_drop;
    if (trip.status == TripStatus.completed) return Icons.check_circle;
    return Icons.navigation;
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final isTripActive = trip != null && trip.status != TripStatus.completed;
    final isTripCompleted = trip != null && trip.status == TripStatus.completed;

    // In completed state, show the designated completed trip card
    if (isTripCompleted) {
      return _buildCompletedTripCard(context, trip);
    }

    final progress = trip?.currentProgress ?? 0.0;
    final maneuverText = _getManeuverText(trip);
    final maneuverIcon = _getManeuverIcon(trip);
    final driverPos = _computeDriverPosition(trip, progress);

    LatLng? pickupPoint;
    LatLng? destPoint;
    if (isTripActive) {
      if (trip.startLat != null && trip.startLng != null) {
        pickupPoint = LatLng(trip.startLat!, trip.startLng!);
      }
      if (trip.endLat != null && trip.endLng != null) {
        destPoint = LatLng(trip.endLat!, trip.endLng!);
      }
    }

    final effectiveCenter = isTripActive
        ? (driverPos ?? pickupPoint ?? _currentGpsLocation ?? LocationService.defaultLocation)
        : (_currentGpsLocation ?? LocationService.defaultLocation);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07172F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTripActive ? AppColors.cyanAccent : AppColors.electricBlue.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. Header: Status & Service Engine ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.isOnline
                                  ? AppColors.successGreen.withOpacity(_pulseAnimation.value)
                                  : Colors.grey,
                              boxShadow: widget.isOnline
                                  ? [
                                      BoxShadow(
                                        color: AppColors.successGreen.withOpacity(_pulseAnimation.value * 0.7),
                                        blurRadius: 6,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isTripActive ? 'ACTIVE TRIP NAVIGATION' : 'DRIVER LIVE GPS RADAR',
                          style: const TextStyle(
                            color: AppColors.cyanAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isLoadingRoute) ...[
                        const SizedBox(width: 6),
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.8, color: AppColors.cyanAccent),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF132B4F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTripActive ? AppColors.cyanAccent.withOpacity(0.6) : Colors.white24,
                    ),
                  ),
                  child: Text(
                    isTripActive ? trip.status.label.toUpperCase() : (widget.isOnline ? 'ONLINE' : 'OFFLINE'),
                    style: TextStyle(
                      color: isTripActive ? AppColors.cyanAccent : (widget.isOnline ? AppColors.successGreen : Colors.grey),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── 2. Turn-by-Turn Guidance Banner ──────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F264A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isTripActive ? AppColors.electricBlue : (widget.isOnline ? AppColors.cyanAccent : Colors.grey.shade800),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      maneuverIcon,
                      color: isTripActive || !widget.isOnline ? Colors.white : AppColors.navy900,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maneuverText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTripActive
                              ? '${trip.distanceKm} km • Fare: ₹${trip.fare.toInt()}'
                              : (widget.isOnline
                                  ? 'Online • Waiting for genuine ride requests from backend'
                                  : 'Offline • Toggle switch above to accept rides'),
                          style: TextStyle(
                            color: isTripActive ? AppColors.cyanAccent : Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Location Permission Warning (if denied) ───────────────────
          if (_locationPermissionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF451A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.errorRed.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off, color: AppColors.errorRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationPermissionError!,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.cyanAccent,
                      ),
                      onPressed: () => _detectDriverGpsLocation(animateCamera: true),
                      child: const Text('ENABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ─── 3. OpenStreetMap Modern Dark Navy Map Section ─────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: effectiveCenter,
                      initialZoom: isTripActive ? 14.5 : 15.5,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    ),
                    children: [
                            // OpenStreetMap Carto Tile Layer
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.drivemate.drivemate_flutter',
                            ),

                            // OSRM Road Route Polyline Layer (Active Booking only)
                            if (isTripActive && _routeCoordinates.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _routeCoordinates,
                                    color: AppColors.electricBlue,
                                    strokeWidth: 5.5,
                                    strokeJoin: StrokeJoin.round,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ],
                              ),

                            // Markers Layer
                            MarkerLayer(
                              markers: [
                                // A. Driver Live GPS Navigation Marker
                                if (driverPos != null)
                                  Marker(
                                    point: driverPos,
                                    width: 52,
                                    height: 52,
                                    child: AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        return Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Outer radar pulse
                                            Container(
                                              width: 48 * _pulseAnimation.value,
                                              height: 48 * _pulseAnimation.value,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.cyanAccent.withOpacity(0.35 * (1 - _pulseAnimation.value)),
                                              ),
                                            ),
                                            // Inner core navigation pin
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF0B1930),
                                                border: Border.all(color: AppColors.cyanAccent, width: 2),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.cyanAccent.withOpacity(0.5),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                              child: Transform.rotate(
                                                angle: ((trip?.bearing ?? 0.0) * 3.1415926535) / 180.0,
                                                child: const Icon(
                                                  Icons.navigation,
                                                  color: AppColors.cyanAccent,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),

                                // B. Pickup Marker (Active Booking only)
                                if (isTripActive && pickupPoint != null)
                                  Marker(
                                    point: pickupPoint,
                                    width: 80,
                                    height: 60,
                                    alignment: Alignment.bottomCenter,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.successGreen,
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                                            ],
                                          ),
                                          child: const Text(
                                            'PICKUP',
                                            style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        const Icon(Icons.location_on, color: AppColors.successGreen, size: 28),
                                      ],
                                    ),
                                  ),

                                // C. Destination Marker (Active Booking only)
                                if (isTripActive && destPoint != null)
                                  Marker(
                                    point: destPoint,
                                    width: 80,
                                    height: 60,
                                    alignment: Alignment.bottomCenter,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.errorRed,
                                            borderRadius: BorderRadius.circular(6),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                                            ],
                                          ),
                                          child: const Text(
                                            'DESTINATION',
                                            style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        const Icon(Icons.location_on, color: AppColors.errorRed, size: 28),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // OpenStreetMap Legal Attribution
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        // Map Floating Interaction Controls
                        Positioned(
                          right: 10,
                          bottom: 12,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTripActive && _routeCoordinates.isNotEmpty) ...[
                                _buildMapFloatingButton(
                                  icon: Icons.crop_free,
                                  tooltip: 'Fit Route',
                                  onTap: _fitRouteBounds,
                                ),
                                const SizedBox(height: 6),
                              ],
                              _buildMapFloatingButton(
                                icon: Icons.add,
                                tooltip: 'Zoom In',
                                onTap: _zoomIn,
                              ),
                              const SizedBox(height: 6),
                              _buildMapFloatingButton(
                                icon: Icons.remove,
                                tooltip: 'Zoom Out',
                                onTap: _zoomOut,
                              ),
                              const SizedBox(height: 6),
                              _buildMapFloatingButton(
                                icon: Icons.my_location,
                                tooltip: 'Current GPS Location',
                                color: _isDetectingLocation ? AppColors.accentGold : AppColors.cyanAccent,
                                onTap: () => _detectDriverGpsLocation(animateCamera: true),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // ─── 4. Telemetry & Action Footer ──────────────────────────────
          if (isTripActive)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.booking?.userName != null || trip.customerName != null) ...[
                              Text(
                                widget.booking?.userName ?? trip.customerName!,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            Text(
                              '${widget.booking?.customerCarModel ?? trip.vehicleModel} • ₹${trip.fare.toInt()}',
                              style: const TextStyle(color: AppColors.cyanAccent, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.electricBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.electricBlue),
                        ),
                        child: Text(
                          '${(progress * 100).toInt()}% Traveled',
                          style: const TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),

                  // Complete Trip Action Button (Driver only on active trip)
                  if (widget.onCompleteTrip != null && trip.status == TripStatus.onTrip) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: widget.onCompleteTrip,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Complete Trip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Material(
      color: const Color(0xFF07172F),
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  // ─── 5. Completed Trip Card ──────────────────────────────────────────
  Widget _buildCompletedTripCard(BuildContext context, Trip trip) {
    final customerName = widget.booking?.userName ?? trip.customerName ?? 'Customer';
    final vehicle = widget.booking?.customerCarModel ?? trip.vehicleModel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF07172F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.successGreen, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.successGreen.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.successGreen, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRIP COMPLETED SUCCESSFULLY',
                      style: TextStyle(
                        color: AppColors.successGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Fare credited to your driver wallet balance',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Trip summary grid from actual database
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1F3D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Passenger Name:', customerName),
                const SizedBox(height: 8),
                _buildReceiptRow('Vehicle Service:', vehicle),
                const SizedBox(height: 8),
                _buildReceiptRow('Pickup Point:', trip.startLocation),
                const SizedBox(height: 8),
                _buildReceiptRow('Destination:', trip.endLocation),
                const Divider(height: 20, color: Colors.white12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Net Earnings:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(
                      '₹${trip.fare.toInt()}',
                      style: const TextStyle(color: AppColors.cyanAccent, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cash Collection Button for Assigned Driver
          if (widget.onCollectCash != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.successGreen,
                  side: const BorderSide(color: AppColors.successGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  await widget.onCollectCash!();
                },
                icon: const Icon(Icons.payments, size: 18),
                label: Text(
                  'Confirm Cash Collected (₹${trip.fare.toInt()})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Return to Live Radar Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanAccent,
                foregroundColor: AppColors.navy900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: widget.onDismissCompleted,
              icon: const Icon(Icons.radar, size: 18),
              label: const Text(
                'Ready for Next Booking • Back to Radar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
