import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../components/driver_profile_sheet.dart';
import '../../components/driver_reviews_sheet.dart';
import '../../components/smart_match_result_dialog.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class DriverSelectionScreen extends StatefulWidget {
  const DriverSelectionScreen({super.key});

  @override
  State<DriverSelectionScreen> createState() => _DriverSelectionScreenState();
}

class _DriverSelectionScreenState extends State<DriverSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  bool _showMap = true;

  final List<Map<String, String>> _filterOptions = const [
    {'key': 'all', 'label': 'All Drivers', 'icon': '🚗'},
    {'key': 'top_rated', 'label': 'Top Rated', 'icon': '⭐'},
    {'key': 'nearest', 'label': 'Nearest', 'icon': '📍'},
    {'key': 'available_now', 'label': 'Available Now', 'icon': '🟢'},
    {'key': 'experience', 'label': 'Most Experienced', 'icon': '🏆'},
    {'key': 'fare', 'label': 'Lowest Fare', 'icon': '💰'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DriveMateProvider>();
      provider.fetchEligibleDrivers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onDriverSelected(EligibleDriver driver, DriveMateProvider provider) {
    provider.selectDriver(driver);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.cyanAccent,
        content: Text(
          'Selected chauffeur ${driver.name} for your journey',
          style: const TextStyle(color: AppColors.navy900, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    provider.navigateTo(ActiveCustomerScreen.hireDriverFlow);
  }

  Future<void> _handleSmartAutoMatch(DriveMateProvider provider) async {
    final matched = await provider.performSmartAutoMatch();
    if (!mounted) return;

    if (matched != null) {
      SmartMatchResultDialog.show(
        context,
        driver: matched,
        onAccept: () {
          Navigator.of(context).pop();
          _onDriverSelected(matched, provider);
        },
        onTryAnother: () {
          Navigator.of(context).pop();
          // Clear and let customer browse manual list
          provider.clearSelectedDriver();
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.amber,
          content: Text(
            'Smart matching could not locate an immediate match. Please pick a driver manually from the list.',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final drivers = provider.eligibleDrivers;
    final isLoading = provider.isLoadingDrivers;
    final isMatching = provider.isSmartMatching;
    final currentSort = provider.driverSortFilter;
    final pickupCoords = provider.searchQuery.pickupCoordinates;

    // Filter drivers by client search string if typed
    final query = _searchController.text.trim().toLowerCase();
    final displayedDrivers = query.isEmpty
        ? drivers
        : drivers.where((d) {
            final nameMatch = d.name.toLowerCase().contains(query);
            final modelMatch = d.vehicleModel.toLowerCase().contains(query);
            final typeMatch = d.vehicleType.toLowerCase().contains(query);
            return nameMatch || modelMatch || typeMatch;
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy900,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Chauffeur',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Verified Professional Drivers',
              style: TextStyle(color: AppColors.cyanAccent, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showMap ? Icons.map : Icons.map_outlined,
              color: _showMap ? AppColors.cyanAccent : Colors.white70,
            ),
            tooltip: _showMap ? 'Hide Map' : 'Show Map',
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Drivers',
            onPressed: () => provider.fetchEligibleDrivers(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Route Summary Header Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navy800,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup: ${provider.searchQuery.pickupLocation.isNotEmpty ? provider.searchQuery.pickupLocation : "Kakdwip Railway Station"}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Destination: ${provider.searchQuery.destination.isNotEmpty ? provider.searchQuery.destination : "Kakdwip Ferry Ghat (Lot 8)"}',
                        style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Smart Auto Match Gradient Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2D4A), Color(0xFF0B1F33)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyanAccent.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cyanAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, color: AppColors.cyanAccent, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Auto Match',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '5-Point Weighted Match: ETA, Proximity, Rating & Vehicle fit',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isMatching ? null : () => _handleSmartAutoMatch(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyanAccent,
                    foregroundColor: AppColors.navy900,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: isMatching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy900),
                        )
                      : const Text(
                          'Match Now',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {});
              },
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search chauffeur by name or vehicle...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.cyanAccent, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.navy800,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cyanAccent),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Horizontal Filter Chips Bar (Phase 2)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filterOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final opt = _filterOptions[index];
                final isSelected = currentSort == opt['key'];
                return ChoiceChip(
                  label: Text('${opt['icon']} ${opt['label']}'),
                  selected: isSelected,
                  selectedColor: AppColors.cyanAccent,
                  backgroundColor: AppColors.navy800,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.navy900 : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.cyanAccent : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  onSelected: (val) {
                    if (val) {
                      provider.setDriverSortFilter(opt['key']!);
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Collapsible OpenStreetMap Mini Map (Phase 6)
          if (_showMap)
            Container(
              height: 160,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: pickupCoords,
                  initialZoom: 14.2,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.drivemate.app',
                  ),
                  MarkerLayer(
                    markers: [
                      // Pickup Location Marker
                      Marker(
                        point: pickupCoords,
                        width: 80,
                        height: 50,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.navy900,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.greenAccent, width: 1),
                              ),
                              child: const Text('Pickup', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const Icon(Icons.location_on, color: Colors.greenAccent, size: 28),
                          ],
                        ),
                      ),
                      // Driver Location Markers
                      ...displayedDrivers.where((d) => d.latitude != null && d.longitude != null).map((d) {
                        final point = LatLng(d.latitude!, d.longitude!);
                        final isChosen = provider.selectedDriver?.id == d.id;
                        return Marker(
                          point: point,
                          width: 80,
                          height: 54,
                          alignment: Alignment.bottomCenter,
                          child: GestureDetector(
                            onTap: () {
                              DriverProfileSheet.show(
                                context,
                                driver: d,
                                onSelect: () => _onDriverSelected(d, provider),
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isChosen ? AppColors.cyanAccent : AppColors.navy900,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.cyanAccent, width: 1),
                                  ),
                                  child: Text(
                                    '${d.name.split(" ").first} ★${(d.avgRating ?? 5.0).toStringAsFixed(1)}',
                                    style: TextStyle(
                                      color: isChosen ? AppColors.navy900 : Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.directions_car,
                                  color: isChosen ? AppColors.cyanAccent : Colors.orangeAccent,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // Driver List Count and Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${displayedDrivers.length} Available Chauffeurs',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (provider.selectedDriver != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.check_circle, color: AppColors.cyanAccent, size: 14),
                    label: Text(
                      'Selected: ${provider.selectedDriver!.name.split(" ").first}',
                      style: const TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      DriverProfileSheet.show(
                        context,
                        driver: provider.selectedDriver!,
                        onSelect: () => _onDriverSelected(provider.selectedDriver!, provider),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Drivers List View (Phase 1 & Phase 9 Empty/Error State)
          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.cyanAccent),
                        SizedBox(height: 12),
                        Text(
                          'Querying verified available drivers...',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : displayedDrivers.isEmpty
                    ? _buildEmptyState(provider)
                    : RefreshIndicator(
                        color: AppColors.cyanAccent,
                        backgroundColor: AppColors.navy800,
                        onRefresh: () => provider.fetchEligibleDrivers(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: displayedDrivers.length,
                          itemBuilder: (context, index) {
                            final driver = displayedDrivers[index];
                            return _buildDriverCard(context, driver, provider);
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomSheet: provider.selectedDriver != null
          ? Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.navy800,
                border: Border(top: BorderSide(color: AppColors.cyanAccent, width: 1.5)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chauffeur: ${provider.selectedDriver!.name}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '★ ${(provider.selectedDriver!.avgRating ?? 5.0).toStringAsFixed(1)} • ${provider.selectedDriver!.totalTrips} Trips • ${provider.selectedDriver!.experienceYears ?? 3} yrs exp',
                            style: const TextStyle(color: AppColors.cyanAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyanAccent,
                        foregroundColor: AppColors.navy900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => _onDriverSelected(provider.selectedDriver!, provider),
                      child: const Text('Proceed to Book', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // â”€â”€â”€ EMPTY STATE (Phase 9: Strictly Real Backend Data Only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildEmptyState(DriveMateProvider provider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.cyanAccent.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cyanAccent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.person_search, color: AppColors.cyanAccent, size: 40),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Drivers Available in this Radius',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'There are no verified chauffeurs matching your filter criteria or coverage radius at this moment. All records are retrieved in real-time from the backend database.',
              style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    provider.setDriverSortFilter('all');
                    provider.fetchEligibleDrivers();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy800,
                    foregroundColor: AppColors.cyanAccent,
                    side: const BorderSide(color: AppColors.cyanAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    provider.fetchEligibleDrivers(sort: 'all');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Expanded search radius to 25 km'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.explore_outlined, size: 16, color: Colors.white70),
                  label: const Text('Expand Radius', style: TextStyle(color: Colors.white70)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    provider.clearSelectedDriver();
                    provider.navigateTo(ActiveCustomerScreen.hireDriverFlow);
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Continue Anyway'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyanAccent,
                    foregroundColor: AppColors.navy900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ DRIVER CARD (Phase 1, 2, 3) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDriverCard(BuildContext context, EligibleDriver driver, DriveMateProvider provider) {
    final isSelected = provider.selectedDriver?.id == driver.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.cyanAccent : Colors.white.withOpacity(0.08),
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.cyanAccent.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          // Top Info Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.navy900,
                      backgroundImage: driver.profilePhoto != null && driver.profilePhoto!.isNotEmpty
                          ? NetworkImage(driver.profilePhoto!)
                          : null,
                      child: driver.profilePhoto == null || driver.profilePhoto!.isEmpty
                          ? Text(
                              driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'D',
                              style: const TextStyle(
                                color: AppColors.cyanAccent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: driver.isOnline ? Colors.greenAccent : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.navy800, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Name, Rating, Verification
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              driver.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${driver.vehicleModel} • ${driver.vehicleType}',
                        style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Badges Row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 13),
                                const SizedBox(width: 3),
                                Text(
                                  (driver.avgRating ?? 5.0).toStringAsFixed(1),
                                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                Text(
                                  ' (${driver.totalTrips})',
                                  style: TextStyle(color: Colors.amber.withOpacity(0.8), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.cyanAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${driver.experienceYears} yrs exp',
                              style: const TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (driver.distanceKm != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${driver.distanceKm!.toStringAsFixed(1)} km',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ETA & Fare
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (driver.etaMinutes != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '~${driver.etaMinutes} min ETA',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      driver.estimatedFare > 0
                          ? '₹${driver.estimatedFare.toStringAsFixed(0)}'
                          : '₹140/hr',
                      style: const TextStyle(
                        color: AppColors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Text('est. fare', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          // Action Buttons Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // View Profile
                TextButton.icon(
                  onPressed: () {
                    DriverProfileSheet.show(
                      context,
                      driver: driver,
                      onSelect: () => _onDriverSelected(driver, provider),
                    );
                  },
                  icon: const Icon(Icons.person_outline, size: 15, color: Colors.white70),
                  label: const Text('Profile', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                // Reviews
                TextButton.icon(
                  onPressed: () => DriverReviewsSheet.show(context, driver),
                  icon: const Icon(Icons.reviews_outlined, size: 15, color: Colors.white70),
                  label: const Text('Reviews', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                const Spacer(),
                // Select Driver Button
                ElevatedButton(
                  onPressed: () => _onDriverSelected(driver, provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? Colors.greenAccent : AppColors.cyanAccent,
                    foregroundColor: AppColors.navy900,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isSelected ? 'Selected ✓' : 'Select Driver',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
