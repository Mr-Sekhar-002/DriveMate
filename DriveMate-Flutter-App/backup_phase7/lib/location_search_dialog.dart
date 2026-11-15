import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/osm_routing_service.dart';
import '../theme/app_theme.dart';

class LocationSearchDialog extends StatefulWidget {
  final String title;
  final String initialQuery;
  final Function(String address, LatLng coordinates) onLocationSelected;

  const LocationSearchDialog({
    super.key,
    required this.title,
    required this.initialQuery,
    required this.onLocationSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String initialQuery,
    required Function(String address, LatLng coordinates) onLocationSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationSearchDialog(
        title: title,
        initialQuery: initialQuery,
        onLocationSelected: onLocationSelected,
      ),
    );
  }

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;
  bool _isGpsLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _suggestions = OsmRoutingService.curatedKakdwipPlaces;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = OsmRoutingService.curatedKakdwipPlaces;
        _isLoading = false;
      });
      return;
    }

    // 450 ms Debounce mechanism to prevent excessive API requests
    _debounceTimer = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _isLoading = true);
      final results = await OsmRoutingService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _useCurrentGpsLocation() async {
    setState(() => _isGpsLoading = true);
    final result = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _isGpsLoading = false);
      Navigator.pop(context);
      widget.onLocationSelected(
        result.address ?? LocationService.defaultAddress,
        result.coordinates,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search place, station, street or market...',
                prefixIcon: const Icon(Icons.search, color: AppColors.electricBlue),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onQueryChanged('');
                            },
                          )
                        : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.electricBlue, width: 2),
                ),
              ),
            ),
          ),

          // Use Current Location Quick Action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkWell(
              onTap: _isGpsLoading ? null : _useCurrentGpsLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cyanLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    _isGpsLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue),
                          )
                        : const Icon(Icons.my_location, color: AppColors.electricBlue, size: 22),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use Current GPS Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.electricBlue,
                          ),
                        ),
                        Text(
                          'Auto-detect using device GPS sensors',
                          style: TextStyle(fontSize: 11, color: AppColors.navy700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 20),

          // Suggestions List (Photon / Curated)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final place = _suggestions[index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.navy900.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getPlaceIcon(place.type),
                      color: AppColors.electricBlue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    place.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    place.subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onLocationSelected(place.subtitle, place.coordinates);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPlaceIcon(String type) {
    switch (type) {
      case 'railway_station':
        return Icons.train;
      case 'bus_station':
        return Icons.directions_bus;
      case 'airport':
        return Icons.flight;
      case 'ferry_terminal':
        return Icons.directions_boat;
      case 'hospital':
        return Icons.local_hospital;
      case 'market':
        return Icons.shopping_basket;
      default:
        return Icons.location_on;
    }
  }
}
