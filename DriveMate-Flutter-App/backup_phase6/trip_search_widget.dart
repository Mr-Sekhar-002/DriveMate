import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/drivemate_models.dart';
import '../services/location_service.dart';
import '../services/osm_routing_service.dart';
import '../theme/app_theme.dart';
import 'location_search_dialog.dart';

class TripSearchWidget extends StatefulWidget {
  final String initialPickup;
  final String initialDestination;
  final LatLng? initialPickupCoordinates;
  final LatLng? initialDestCoordinates;
  final String initialDate;
  final BookingType initialServiceType;
  final Function(String pickup, String destination, String travelDate, BookingType serviceType) onSearchAndBook;
  final Function(LatLng pickupCoord, LatLng destCoord)? onCoordinatesUpdated;

  const TripSearchWidget({
    super.key,
    required this.initialPickup,
    required this.initialDestination,
    this.initialPickupCoordinates,
    this.initialDestCoordinates,
    required this.initialDate,
    required this.initialServiceType,
    required this.onSearchAndBook,
    this.onCoordinatesUpdated,
  });

  @override
  State<TripSearchWidget> createState() => _TripSearchWidgetState();
}

class _TripSearchWidgetState extends State<TripSearchWidget> {
  late TextEditingController _pickupController;
  late TextEditingController _destinationController;
  late TextEditingController _dateController;
  late BookingType _selectedServiceType;

  LatLng? _pickupCoords;
  LatLng? _destCoords;

  Timer? _debounceTimer;
  List<PlaceSuggestion> _autocompleteSuggestions = [];
  bool _isSearchingPickup = false;
  bool _isSearchingDest = false;
  bool _isDetectingLocation = false;
  bool _isPhotonLoading = false;

  final List<String> _quickLocations = [
    'Kakdwip Railway Station',
    'Kakdwip Bus Stand',
    'Kakdwip Market',
    'Lot 8 Ferry Ghat',
    'Kolkata Airport (CCU)',
  ];

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController(text: widget.initialPickup);
    _destinationController = TextEditingController(text: widget.initialDestination);
    _dateController = TextEditingController(text: widget.initialDate);
    _selectedServiceType = widget.initialServiceType;
    _pickupCoords = widget.initialPickupCoordinates ?? const LatLng(21.8767, 88.1912);
    _destCoords = widget.initialDestCoordinates ?? const LatLng(21.8712, 88.1824);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onLocationQueryChanged(String query, bool isPickup) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _autocompleteSuggestions = [];
        _isSearchingPickup = false;
        _isSearchingDest = false;
        _isPhotonLoading = false;
      });
      return;
    }

    // 450 ms Debounce mechanism as required by OpenStreetMap & Photon guidelines
    _debounceTimer = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _isPhotonLoading = true);
      final results = await OsmRoutingService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _autocompleteSuggestions = results;
          _isSearchingPickup = isPickup;
          _isSearchingDest = !isPickup;
          _isPhotonLoading = false;
        });
      }
    });
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    setState(() {
      if (_isSearchingPickup) {
        _pickupController.text = suggestion.subtitle;
        _pickupCoords = suggestion.coordinates;
      } else {
        _destinationController.text = suggestion.subtitle;
        _destCoords = suggestion.coordinates;
      }
      _autocompleteSuggestions = [];
      _isSearchingPickup = false;
      _isSearchingDest = false;
    });

    if (_pickupCoords != null && _destCoords != null) {
      widget.onCoordinatesUpdated?.call(_pickupCoords!, _destCoords!);
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);
    final result = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _pickupController.text = result.address ?? LocationService.defaultAddress;
        _pickupCoords = result.coordinates;
        _isDetectingLocation = false;
      });

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
          SnackBar(
            content: Text('GPS Fix Acquired: (${result.coordinates.latitude.toStringAsFixed(4)}, ${result.coordinates.longitude.toStringAsFixed(4)})'),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      if (_pickupCoords != null && _destCoords != null) {
        widget.onCoordinatesUpdated?.call(_pickupCoords!, _destCoords!);
      }
    }
  }

  void _openPickupSearchDialog() {
    LocationSearchDialog.show(
      context: context,
      title: 'Select Pickup Location',
      initialQuery: _pickupController.text,
      onLocationSelected: (address, coords) {
        setState(() {
          _pickupController.text = address;
          _pickupCoords = coords;
        });
        if (_destCoords != null) {
          widget.onCoordinatesUpdated?.call(_pickupCoords!, _destCoords!);
        }
      },
    );
  }

  void _openDestinationSearchDialog() {
    LocationSearchDialog.show(
      context: context,
      title: 'Select Destination (Where to?)',
      initialQuery: _destinationController.text,
      onLocationSelected: (address, coords) {
        setState(() {
          _destinationController.text = address;
          _destCoords = coords;
        });
        if (_pickupCoords != null) {
          widget.onCoordinatesUpdated?.call(_pickupCoords!, _destCoords!);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service Type Tabs
          Row(
            children: BookingType.values.map((type) {
              final isSelected = _selectedServiceType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedServiceType = type);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.navy900 : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.navy900 : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          type == BookingType.hireDriver
                              ? Icons.airline_seat_recline_extra
                              : type == BookingType.rentCar
                                  ? Icons.directions_car
                                  : Icons.car_rental,
                          color: isSelected ? Colors.white : AppColors.navy700,
                          size: 18,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          type.title,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.navy900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Pickup Location Field
          TextField(
            controller: _pickupController,
            onChanged: (val) => _onLocationQueryChanged(val, true),
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Pickup Location',
              labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
              prefixIcon: const Icon(Icons.my_location, color: AppColors.successGreen, size: 20),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.map, size: 18, color: AppColors.electricBlue),
                    tooltip: 'Search on Map',
                    onPressed: _openPickupSearchDialog,
                  ),
                  _isDetectingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue),
                          ),
                        )
                      : TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _detectCurrentLocation,
                          icon: const Icon(Icons.gps_fixed, size: 14, color: AppColors.electricBlue),
                          label: const Text(
                            'GPS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.electricBlue),
                          ),
                        ),
                ],
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.electricBlue, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),

          // Autocomplete Dropdown Overlay for Pickup
          if (_isSearchingPickup && _autocompleteSuggestions.isNotEmpty)
            _buildSuggestionsList(),

          const SizedBox(height: 10),

          // Destination Field
          TextField(
            controller: _destinationController,
            onChanged: (val) => _onLocationQueryChanged(val, false),
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Destination (Where to?)',
              labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
              prefixIcon: const Icon(Icons.location_on, color: AppColors.errorRed, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.map, size: 18, color: AppColors.electricBlue),
                tooltip: 'Search Destination',
                onPressed: _openDestinationSearchDialog,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.electricBlue, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),

          // Autocomplete Dropdown Overlay for Destination
          if (_isSearchingDest && _autocompleteSuggestions.isNotEmpty)
            _buildSuggestionsList(),

          const SizedBox(height: 10),

          // Travel Date & Time
          TextField(
            controller: _dateController,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Travel Date & Time',
              labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
              prefixIcon: const Icon(Icons.calendar_month, color: AppColors.cyanAccent, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.electricBlue, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),

          const SizedBox(height: 10),

          // Quick Kakdwip Destination Suggestions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickLocations.map((loc) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    label: Text(loc, style: const TextStyle(fontSize: 11, color: AppColors.navy700)),
                    backgroundColor: AppColors.surfaceLight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: Colors.grey.shade300),
                    onPressed: () {
                      setState(() {
                        _destinationController.text = loc;
                        _autocompleteSuggestions = [];
                        _destCoords = const LatLng(21.8712, 88.1824);
                      });
                      if (_pickupCoords != null && _destCoords != null) {
                        widget.onCoordinatesUpdated?.call(_pickupCoords!, _destCoords!);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Search & Book Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                widget.onSearchAndBook(
                  _pickupController.text.trim(),
                  _destinationController.text.trim(),
                  _dateController.text.trim(),
                  _selectedServiceType,
                );
              },
              icon: const Icon(Icons.search, size: 20),
              label: Text(
                'Find & Book ${_selectedServiceType.title}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.electricBlue.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isPhotonLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue)),
                  SizedBox(width: 8),
                  Text('Searching OpenStreetMap Photon...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ..._autocompleteSuggestions.map((suggestion) {
            return InkWell(
              onTap: () => _selectSuggestion(suggestion),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.electricBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.title,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.navy900, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            suggestion.subtitle,
                            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
