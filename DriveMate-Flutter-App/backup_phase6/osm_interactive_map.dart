import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class OsmInteractiveMap extends StatefulWidget {
  final LatLng? initialCenter;
  final double initialZoom;
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final LatLng? driverLocation;
  final double driverBearing;
  final LatLng? currentLocation;
  final List<LatLng> polylinePoints;
  final bool showControls;
  final bool isInteractive;
  final Function(LatLng point)? onTap;
  final VoidCallback? onLocationDetected;

  const OsmInteractiveMap({
    super.key,
    this.initialCenter,
    this.initialZoom = 14.5,
    this.pickupLocation,
    this.destinationLocation,
    this.driverLocation,
    this.driverBearing = 0.0,
    this.currentLocation,
    this.polylinePoints = const [],
    this.showControls = true,
    this.isInteractive = true,
    this.onTap,
    this.onLocationDetected,
  });

  @override
  State<OsmInteractiveMap> createState() => _OsmInteractiveMapState();
}

class _OsmInteractiveMapState extends State<OsmInteractiveMap> {
  late final MapController _mapController;
  LatLng? _detectedGpsLocation;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _detectedGpsLocation = widget.currentLocation;
  }

  @override
  void didUpdateWidget(covariant OsmInteractiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.polylinePoints != oldWidget.polylinePoints && widget.polylinePoints.isNotEmpty) {
      _fitRouteBounds();
    }
  }

  void _fitRouteBounds() {
    if (widget.polylinePoints.length >= 2) {
      final bounds = LatLngBounds.fromPoints(widget.polylinePoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
        ),
      );
    }
  }

  Future<void> _handleGpsButtonClick() async {
    setState(() => _isDetecting = true);
    final result = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _isDetecting = false;
        _detectedGpsLocation = result.coordinates;
      });

      _mapController.move(result.coordinates, 16.0);

      if (result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage!),
            backgroundColor: AppColors.errorRed,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS Location acquired successfully'),
            backgroundColor: AppColors.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }

      widget.onLocationDetected?.call();
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

  @override
  Widget build(BuildContext context) {
    final effectiveCenter = widget.initialCenter ??
        widget.pickupLocation ??
        widget.driverLocation ??
        _detectedGpsLocation ??
        LocationService.defaultLocation;

    final markers = <Marker>[];

    // 1. Current / Detected GPS Location Marker (Pulsing Cyan Dot)
    final gpsLoc = _detectedGpsLocation ?? widget.currentLocation;
    if (gpsLoc != null) {
      markers.add(
        Marker(
          point: gpsLoc,
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cyanAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyanAccent.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2. Pickup Location Marker (Green Pin)
    if (widget.pickupLocation != null) {
      markers.add(
        Marker(
          point: widget.pickupLocation!,
          width: 90,
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
      );
    }

    // 3. Destination Location Marker (Red Pin)
    if (widget.destinationLocation != null) {
      markers.add(
        Marker(
          point: widget.destinationLocation!,
          width: 90,
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
                ),
                child: const Text(
                  'DESTINATION',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                ),
              ),
              const Icon(Icons.location_on, color: AppColors.errorRed, size: 28),
            ],
          ),
        ),
      );
    }

    // 4. Driver Vehicle Marker (Rotatable Car Pin)
    if (widget.driverLocation != null) {
      markers.add(
        Marker(
          point: widget.driverLocation!,
          width: 48,
          height: 48,
          child: Transform.rotate(
            angle: (widget.driverBearing * 3.141592653589793) / 180.0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.navy900,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cyanAccent, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.navigation, color: AppColors.cyanAccent, size: 26),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: effectiveCenter,
            initialZoom: widget.initialZoom,
            interactionOptions: InteractionOptions(
              flags: widget.isInteractive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onTap: widget.onTap != null ? (_, point) => widget.onTap!(point) : null,
          ),
          children: [
            // OpenStreetMap Carto Tile Layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.drivemate.drivemate_flutter',
            ),

            // OSRM Road Route Polyline Layer
            if (widget.polylinePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.polylinePoints,
                    color: AppColors.electricBlue,
                    strokeWidth: 5.5,
                    strokeJoin: StrokeJoin.round,
                    strokeCap: StrokeCap.round,
                  ),
                ],
              ),

            // Markers Layer
            MarkerLayer(markers: markers),
          ],
        ),

        // OpenStreetMap Legal Attribution Badge
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(color: Colors.black87, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // Map Interaction Floating Controls
        if (widget.showControls)
          Positioned(
            right: 12,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current Location Button
                FloatingActionButton.small(
                  heroTag: 'osm_current_loc_${widget.hashCode}',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navy900,
                  elevation: 3,
                  onPressed: _isDetecting ? null : _handleGpsButtonClick,
                  child: _isDetecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue),
                        )
                      : const Icon(Icons.my_location, size: 20),
                ),
                const SizedBox(height: 10),

                // Zoom In Button
                FloatingActionButton.small(
                  heroTag: 'osm_zoom_in_${widget.hashCode}',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navy900,
                  elevation: 3,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, size: 20),
                ),
                const SizedBox(height: 6),

                // Zoom Out Button
                FloatingActionButton.small(
                  heroTag: 'osm_zoom_out_${widget.hashCode}',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navy900,
                  elevation: 3,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
