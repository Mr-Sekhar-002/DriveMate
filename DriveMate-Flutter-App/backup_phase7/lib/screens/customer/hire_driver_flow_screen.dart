import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../components/fare_negotiation_dialog.dart';
import '../../components/location_search_dialog.dart';
import '../../components/osm_interactive_map.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../services/location_service.dart';
import '../../services/osm_routing_service.dart';
import '../../theme/app_theme.dart';

class HireDriverFlowScreen extends StatefulWidget {
  const HireDriverFlowScreen({super.key});

  @override
  State<HireDriverFlowScreen> createState() => _HireDriverFlowScreenState();
}

class _HireDriverFlowScreenState extends State<HireDriverFlowScreen> {
  // Hiring Type State
  DriverHiringType _hiringType = DriverHiringType.oneWay;
  int _selectedHours = 4;

  // Location & Navigation State
  late TextEditingController _pickupController;
  late TextEditingController _destController;
  late LatLng _pickupCoords;
  late LatLng _destCoords;

  // Customer Vehicle State
  late TextEditingController _carModelController;
  String _carCategory = 'Sedan';
  String _transmission = 'Automatic';
  PaymentMethod _paymentMethod = PaymentMethod.razorpay;

  // OSRM Routing & Server Fare State
  List<LatLng> _routePolyline = [];
  double _roadDistanceKm = 14.8;
  int _journeyDurationMin = 28;
  bool _isRouting = false;
  bool _isEstimating = false;
  DriverHiringFareEstimate? _fareEstimate;
  String? _routingStatusMessage;

  @override
  void initState() {
    super.initState();
    final provider = context.read<DriveMateProvider>();
    _pickupController = TextEditingController(
      text: provider.searchQuery.pickupLocation.isNotEmpty
          ? provider.searchQuery.pickupLocation
          : 'Kakdwip Railway Station, WB 743347',
    );
    _destController = TextEditingController(
      text: provider.searchQuery.destination.isNotEmpty
          ? provider.searchQuery.destination
          : 'Kakdwip Ferry Ghat (Lot 8)',
    );
    _pickupCoords = provider.searchQuery.pickupCoordinates;
    _destCoords = provider.searchQuery.destinationCoordinates;
    _carModelController = TextEditingController(text: 'Honda City (Automatic)');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateRouteAndServerFare();
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destController.dispose();
    _carModelController.dispose();
    super.dispose();
  }

  /// Calculates actual road route via OSRM and queries server-side pricing engine
  Future<void> _calculateRouteAndServerFare() async {
    if (!mounted) return;
    setState(() {
      _isRouting = true;
      _isEstimating = true;
      _routingStatusMessage = 'Calculating road routing via OSRM...';
    });

    final provider = context.read<DriveMateProvider>();

    try {
      // 1. OSRM Road Routing
      final routeResult = await OsmRoutingService.fetchRoute(
        start: _pickupCoords,
        destination: _destCoords,
        startAddress: _pickupController.text,
        destinationAddress: _destController.text,
      );

      if (mounted) {
        setState(() {
          _routePolyline = routeResult.polylinePoints;
          _roadDistanceKm = routeResult.distanceKm;
          _journeyDurationMin = routeResult.durationMinutes;
          _isRouting = false;
          _routingStatusMessage = 'OSRM road route calculated (${routeResult.distanceKm} km, ${routeResult.durationMinutes} min)';
        });
      }

      // 2. Query PHP Backend Server Pricing Engine
      final estimate = await provider.calculateDriverHiringEstimate(
        pickup: _pickupController.text.trim(),
        destination: _destController.text.trim(),
        pickupCoords: _pickupCoords,
        destCoords: _destCoords,
        hiringType: _hiringType,
        hours: _selectedHours,
        distanceKm: _roadDistanceKm,
        durationMinutes: _journeyDurationMin,
      );

      if (mounted) {
        setState(() {
          _fareEstimate = estimate;
          _isEstimating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRouting = false;
          _isEstimating = false;
          _routingStatusMessage = 'Route estimated from network coordinates';
        });
      }
    }
  }

  /// Photon location search modal for pickup
  void _openPickupSearch() {
    LocationSearchDialog.show(
      context: context,
      title: 'Select Pickup Location',
      initialQuery: _pickupController.text,
      onLocationSelected: (address, coords) {
        setState(() {
          _pickupController.text = address;
          _pickupCoords = coords;
        });
        _calculateRouteAndServerFare();
      },
    );
  }

  /// Direct GPS current location detector
  Future<void> _useCurrentGpsLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Detecting current GPS location...'),
        duration: Duration(seconds: 1),
      ),
    );

    final res = await LocationService.getCurrentLocation();
    if (!mounted) return;

    setState(() {
      _pickupController.text = res.address ?? 'Current Location (${res.coordinates.latitude.toStringAsFixed(4)}, ${res.coordinates.longitude.toStringAsFixed(4)})';
      _pickupCoords = res.coordinates;
    });

    _calculateRouteAndServerFare();
  }

  /// Photon location search modal for destination
  void _openDestinationSearch() {
    LocationSearchDialog.show(
      context: context,
      title: 'Select Destination',
      initialQuery: _destController.text,
      onLocationSelected: (address, coords) {
        setState(() {
          _destController.text = address;
          _destCoords = coords;
        });
        _calculateRouteAndServerFare();
      },
    );
  }

  /// Swap pickup and destination
  void _swapLocations() {
    final tempText = _pickupController.text;
    final tempCoords = _pickupCoords;
    setState(() {
      _pickupController.text = _destController.text;
      _pickupCoords = _destCoords;
      _destController.text = tempText;
      _destCoords = tempCoords;
    });
    _calculateRouteAndServerFare();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final double estimatedFare = _fareEstimate?.estimatedFare ?? 467.0;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hire a Driver',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Customer owns the car • Verified Chauffeur',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Blueprint Status Header
            _buildBlueprintHeader(),

            const SizedBox(height: 14),

            // Assigned / Selected Chauffeur Card (Driver Selection Integration)
            _buildSelectedDriverCard(provider),

            const SizedBox(height: 14),

            // Service Type Selector Tabs
            _buildHiringTypeSelector(),

            // Hourly duration selector (if hourly chosen)
            if (_hiringType == DriverHiringType.hourly) ...[
              const SizedBox(height: 12),
              _buildHourlyDurationSelector(),
            ],

            const SizedBox(height: 14),

            // Location Selection Card with Photon Autocomplete & GPS
            _buildLocationCard(),

            const SizedBox(height: 14),

            // Live OpenStreetMap Route Visualizer
            _buildOsmMapCard(),

            const SizedBox(height: 14),

            // Customer Vehicle to be Chauffeured Card
            _buildVehicleCard(),

            const SizedBox(height: 14),

            // Server-side Calculated Fare & Negotiation Breakdown Card
            _buildFareBreakdownCard(provider, estimatedFare),

            const SizedBox(height: 14),

            // Payment Method Selector
            _buildPaymentMethodSelector(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBlueprintHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PHASE 19: DRIVER HIRING ENGINE',
                style: TextStyle(
                  color: AppColors.cyanAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'OSRM + PHOTON + 2-WAY FARE',
                  style: TextStyle(color: AppColors.cyanAccent, fontSize: 8.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Chauffeur service for customer-owned vehicles. Select route, review server-calculated estimate, and agree on negotiated fare before booking.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDriverCard(DriveMateProvider provider) {
    final driver = provider.selectedDriver;
    if (driver != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.navy800,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cyanAccent, width: 1.2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.navy900,
              child: Text(
                driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'D',
                style: const TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          driver.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Colors.blueAccent, size: 14),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${driver.avgRating != null && driver.avgRating! > 0 ? "★ ${driver.avgRating!.toStringAsFixed(1)}" : "★ New"} (${driver.totalTrips} trips)${driver.experienceYears != null ? " • ${driver.experienceYears} yrs exp" : ""} • ${driver.vehicleModel}',
                    style: const TextStyle(color: AppColors.cyanAccent, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => provider.navigateTo(ActiveCustomerScreen.driverSelection),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.cyanAccent),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Change', style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search, color: AppColors.cyanAccent, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Specific Driver Selected',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  'Pick an available chauffeur or use 5-point Smart Match',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              provider.fetchEligibleDrivers();
              provider.navigateTo(ActiveCustomerScreen.driverSelection);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanAccent,
              foregroundColor: AppColors.navy900,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Choose', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHiringTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Driver Hiring Type:',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: 8),
        Row(
          children: DriverHiringType.values.map((type) {
            final isSelected = _hiringType == type;
            IconData icon;
            switch (type) {
              case DriverHiringType.oneWay:
                icon = Icons.trending_flat;
                break;
              case DriverHiringType.roundTrip:
                icon = Icons.sync_alt;
                break;
              case DriverHiringType.hourly:
                icon = Icons.access_time;
                break;
              case DriverHiringType.fullDay:
                icon = Icons.wb_sunny_outlined;
                break;
            }

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () {
                    setState(() => _hiringType = type);
                    _calculateRouteAndServerFare();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.electricBlue : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.electricBlue : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.electricBlue.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: isSelected ? Colors.white : AppColors.navy900, size: 18),
                        const SizedBox(height: 4),
                        Text(
                          type.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.navy900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHourlyDurationSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule, size: 16, color: AppColors.electricBlue),
              SizedBox(width: 6),
              Text(
                'Hourly Chauffeur Duration:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [2, 4, 8, 12].map((hours) {
              final isSel = _selectedHours == hours;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isSel ? AppColors.electricBlue : Colors.white,
                      foregroundColor: isSel ? Colors.white : AppColors.navy900,
                      side: BorderSide(color: isSel ? AppColors.electricBlue : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() => _selectedHours = hours);
                      _calculateRouteAndServerFare();
                    },
                    child: Text('$hours Hrs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.route, color: AppColors.electricBlue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Pickup & Destination Selection',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy900),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Swap Locations',
                  icon: const Icon(Icons.swap_vert, color: AppColors.electricBlue, size: 20),
                  onPressed: _swapLocations,
                ),
              ],
            ),
            const Divider(height: 12),
            // Pickup location field
            InkWell(
              onTap: _openPickupSearch,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location, color: AppColors.electricBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PICKUP LOCATION', style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(
                            _pickupController.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy900),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Use Current Location',
                      icon: const Icon(Icons.gps_fixed, color: AppColors.electricBlue, size: 18),
                      onPressed: _useCurrentGpsLocation,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Destination location field
            InkWell(
              onTap: _openDestinationSearch,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.accentGold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DESTINATION', style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(
                            _destController.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy900),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.search, color: Colors.grey, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOsmMapCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Stack(
            children: [
              SizedBox(
                height: 220,
                child: OsmInteractiveMap(
                  initialCenter: _pickupCoords,
                  pickupLocation: _pickupCoords,
                  destinationLocation: _destCoords,
                  polylinePoints: _routePolyline,
                  showControls: true,
                  isInteractive: true,
                ),
              ),
              // Floating Distance & Duration Info Pill
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.navy900.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.alt_route, color: AppColors.cyanAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _isRouting ? 'Routing...' : '${_roadDistanceKm.toStringAsFixed(1)} km Road Distance',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: AppColors.accentGold, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _isRouting ? '...' : '$_journeyDurationMin mins',
                            style: const TextStyle(color: AppColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_isRouting || _isEstimating)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.electricBlue),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _routingStatusMessage ?? 'OpenStreetMap & OSRM Engine Active',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _calculateRouteAndServerFare,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Refresh Route', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.directions_car, color: AppColors.electricBlue, size: 18),
                SizedBox(width: 8),
                Text(
                  'Your Vehicle to be Chauffeured',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.navy900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _carModelController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Make & Model (e.g. Honda City)',
                prefixIcon: const Icon(Icons.car_rental, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _carCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    items: ['Sedan', 'SUV', 'Luxury', 'Hatchback']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (val) => setState(() => _carCategory = val ?? 'Sedan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _transmission,
                    decoration: InputDecoration(
                      labelText: 'Transmission',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    items: ['Automatic', 'Manual']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (val) => setState(() => _transmission = val ?? 'Automatic'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareBreakdownCard(DriveMateProvider provider, double estimatedFare) {
    final estimate = _fareEstimate;
    final minOffer = estimate?.minSuggestedOffer ?? ((estimatedFare * 0.85) / 10).round() * 10.0;
    final maxOffer = estimate?.maxSuggestedOffer ?? ((estimatedFare * 1.15) / 10).round() * 10.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_hiringType.label} Pricing',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('SERVER FORMULA', style: TextStyle(color: AppColors.cyanAccent, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildFareRow('Base Chauffeur Charge', '₹${(estimate?.baseCharge ?? 150).toInt()}'),
          _buildFareRow('Road Distance Fare (${_roadDistanceKm.toStringAsFixed(1)} km)', '₹${(estimate?.distanceFare ?? 0).toInt()}'),
          _buildFareRow('Estimated Travel Duration ($_journeyDurationMin mins)', '₹${(estimate?.timeFare ?? 0).toInt()}'),
          _buildFareRow('Safety Allowance & Insurance', '₹${(estimate?.allowances ?? 50).toInt()}'),
          const Divider(color: Colors.white24, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Estimated Fare:',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${estimatedFare.toInt()}',
                style: const TextStyle(color: AppColors.cyanAccent, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Suggested Negotiation Range Banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.accentGold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suggested Negotiation Range: ₹${minOffer.toInt()} – ₹${maxOffer.toInt()}',
                        style: const TextStyle(color: AppColors.cyanAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Server suggested baseline. Submit your custom offer or book standard directly.',
                        style: TextStyle(color: Colors.white60, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Active Negotiation Status Banner (if negotiation is ongoing for this flow)
          if (provider.activeNegotiationBooking != null) ...[
            _buildActiveNegotiationBanner(context, provider, provider.activeNegotiationBooking!),
            const SizedBox(height: 12),
          ],

          // Actions: Negotiate Fare (Two-Way) + Book Standard
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyanAccent,
                    side: const BorderSide(color: AppColors.cyanAccent, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => _openNegotiateSheet(context, provider, estimatedFare, minOffer, maxOffer),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Negotiate Fare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyanAccent,
                    foregroundColor: AppColors.navy900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  onPressed: () => _bookStandardAtEstimatedFare(provider, estimatedFare),
                  child: Text('Book ₹${estimatedFare.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActiveNegotiationBanner(BuildContext context, DriveMateProvider provider, Booking booking) {
    final negotiations = provider.getNegotiationsForBooking(booking.id);
    final latestOffer = negotiations.isNotEmpty ? negotiations.last : null;
    final isAgreed = booking.negotiationStatus == 'AGREED';
    final isDriverCounter = latestOffer != null && latestOffer.senderRole == 'driver' && latestOffer.status == NegotiationStatus.pending;
    final offeredPrice = (booking.negotiatedFare ?? booking.totalAmount).toInt();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAgreed
            ? const Color(0xFF0D3326)
            : isDriverCounter
                ? const Color(0xFF0F264A)
                : const Color(0xFF2E2405),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAgreed
              ? AppColors.successGreen
              : isDriverCounter
                  ? AppColors.cyanAccent
                  : AppColors.accentGold,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAgreed
                      ? AppColors.successGreen
                      : isDriverCounter
                          ? AppColors.cyanAccent
                          : AppColors.accentGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAgreed
                      ? 'FARE AGREED & CONFIRMED'
                      : isDriverCounter
                          ? 'DRIVER COUNTER-OFFER RECEIVED'
                          : 'OFFER SUBMITTED • AWAITING DRIVER',
                  style: TextStyle(
                    color: isDriverCounter ? AppColors.navy900 : Colors.black,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '₹$offeredPrice',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAgreed
                ? 'Mutually agreed at ₹$offeredPrice. Ride Start OTP: ${booking.startOtp}'
                : isDriverCounter
                    ? 'Chauffeur Amitava proposed counter-offer of ₹$offeredPrice. You can accept or counter again.'
                    : 'Your offer of ₹$offeredPrice is awaiting response from Chauffeur Amitava Roy.',
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (isDriverCounter) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => provider.respondToFareOffer(booking.id, 'accept'),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text('Accept ₹$offeredPrice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => FareNegotiationDialog.show(context, booking),
                  icon: const Icon(Icons.history, size: 15),
                  label: Text(isAgreed ? 'View Agreed Details' : 'View Negotiation', style: const TextStyle(fontSize: 11)),
                ),
              ),
              if (!isAgreed) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Cancel Negotiation',
                  icon: const Icon(Icons.close, color: AppColors.errorRed, size: 18),
                  onPressed: () => provider.cancelActiveNegotiation(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _bookStandardAtEstimatedFare(DriveMateProvider provider, double estimatedFare) {
    provider.bookDriverHiring(
      hiringType: _hiringType,
      pickup: _pickupController.text.trim(),
      pickupCoords: _pickupCoords,
      destination: _destController.text.trim(),
      destCoords: _destCoords,
      distanceKm: _roadDistanceKm,
      durationMinutes: _journeyDurationMin,
      customerCarModel: '${_carModelController.text.trim()} ($_transmission)',
      estimatedFare: estimatedFare,
      hours: _selectedHours,
    );
  }

  void _openNegotiateSheet(
    BuildContext context,
    DriveMateProvider provider,
    double estimatedFare,
    double minOffer,
    double maxOffer,
  ) {
    final suggestedOffer = minOffer > 50 ? minOffer : (estimatedFare > 50 ? estimatedFare - 50 : estimatedFare);
    final offerCtrl = TextEditingController(text: suggestedOffer.toInt().toString());
    final notesCtrl = TextEditingController(text: 'Pickup at ${_pickupController.text}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentOffered = double.tryParse(offerCtrl.text.trim()) ?? suggestedOffer;

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.swap_horiz, color: AppColors.electricBlue, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Two-Way Fare Negotiation',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Propose a custom fare directly to verified chauffeur Amitava Roy for ${_hiringType.label}. Both parties must agree before booking is confirmed.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Server Estimated Fare:', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondaryDark)),
                        Text('₹${estimatedFare.toInt()}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: offerCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Your Proposed Fare (INR)',
                            prefixText: '₹ ',
                            prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy900),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final val = int.tryParse(offerCtrl.text) ?? estimatedFare.toInt();
                          if (val > 50) {
                            offerCtrl.text = '${val - 50}';
                            setSheetState(() {});
                          }
                        },
                        child: const Text('- ₹50', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final val = int.tryParse(offerCtrl.text) ?? estimatedFare.toInt();
                          offerCtrl.text = '${val + 50}';
                          setSheetState(() {});
                        },
                        child: const Text('+ ₹50', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Pickup Note for Chauffeur',
                      hintText: 'e.g. Kakdwip Station platform exit 1',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyanAccent,
                        foregroundColor: AppColors.navy900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final offered = double.tryParse(offerCtrl.text.trim()) ?? estimatedFare;
                        if (offered <= 0) return;
                        Navigator.pop(ctx);

                        provider.bookDriverHiring(
                          hiringType: _hiringType,
                          pickup: _pickupController.text.trim(),
                          pickupCoords: _pickupCoords,
                          destination: _destController.text.trim(),
                          destCoords: _destCoords,
                          distanceKm: _roadDistanceKm,
                          durationMinutes: _journeyDurationMin,
                          customerCarModel: '${_carModelController.text.trim()} ($_transmission)',
                          estimatedFare: estimatedFare,
                          hours: _selectedHours,
                          initialOffer: offered,
                          notes: notesCtrl.text.trim(),
                        );
                      },
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(
                        'Submit Offer of ₹${currentOffered.toInt()} to Chauffeur',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Gateway:',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: 8),
        ...PaymentMethod.values.map((method) {
          final isSelected = _paymentMethod == method;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.cyanLight : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? AppColors.electricBlue : Colors.grey.shade300),
            ),
            child: RadioListTile<PaymentMethod>(
              value: method,
              groupValue: _paymentMethod,
              title: Text(method.displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              activeColor: AppColors.electricBlue,
              dense: true,
              onChanged: (val) {
                if (val != null) setState(() => _paymentMethod = val);
              },
            ),
          );
        }),
      ],
    );
  }
}
