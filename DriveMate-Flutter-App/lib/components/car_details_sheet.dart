import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drivemate_models.dart';
import '../providers/drivemate_provider.dart';
import '../theme/app_theme.dart';
import 'vehicle_inspection_sheet.dart';

/// Car Details Screen / Modal matching Mockup 5 (ref_rental_details.png)
class CarDetailsSheet extends StatefulWidget {
  final CarListing listing;

  const CarDetailsSheet({super.key, required this.listing});

  static Future<void> show(BuildContext context, CarListing listing) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CarDetailsSheet(listing: listing),
    );
  }

  @override
  State<CarDetailsSheet> createState() => _CarDetailsSheetState();
}

class _CarDetailsSheetState extends State<CarDetailsSheet> {
  int _selectedDays = 2;
  int _activeGalleryIndex = 0;
  bool _isFavorite = false;

  Map<String, String> _getSpecsForVehicle(Vehicle v) {
    final modelLower = v.model.toLowerCase();
    if (modelLower.contains('bmw')) {
      return {
        'power': '255 hp @ 5000 rpm',
        'speed': '250 km/h',
        'accel': '5.8 sec 0-100',
        'mileage': '15.3 km/L',
        'luggage': '480 Litres',
        'safety': '5-Star Euro NCAP',
        'units': '4 Hub Units',
        'era': '2024 Luxury',
      };
    } else if (modelLower.contains('fortuner')) {
      return {
        'power': '201 hp @ 3400 rpm',
        'speed': '190 km/h',
        'accel': '9.6 sec 0-100',
        'mileage': '14.2 km/L',
        'luggage': '296 L (7-Seat)',
        'safety': '5-Star Global NCAP',
        'units': '6 Hub Units',
        'era': '2024 4x4 Diesel',
      };
    } else if (modelLower.contains('creta')) {
      return {
        'power': '158 hp @ 5500 rpm',
        'speed': '190 km/h',
        'accel': '8.9 sec 0-100',
        'mileage': '17.4 km/L',
        'luggage': '433 Litres',
        'safety': '5-Star Global NCAP',
        'units': '9 Hub Units',
        'era': '2024 SX(O)',
      };
    } else if (modelLower.contains('corolla')) {
      return {
        'power': '138 hp @ 6400 rpm',
        'speed': '200 km/h',
        'accel': '8.5 sec 0-100',
        'mileage': '21.5 km/L (Hybrid)',
        'luggage': '470 Litres',
        'safety': '5-Star Global NCAP',
        'units': '8 Hub Units',
        'era': '2024 Hybrid',
      };
    } else if (modelLower.contains('verna')) {
      return {
        'power': '158 hp @ 5500 rpm',
        'speed': '210 km/h',
        'accel': '8.1 sec 0-100',
        'mileage': '18.6 km/L',
        'luggage': '528 Litres',
        'safety': '5-Star Global NCAP',
        'units': '7 Hub Units',
        'era': '2024 Turbo',
      };
    } else if (modelLower.contains('swift')) {
      return {
        'power': '89 hp @ 6000 rpm',
        'speed': '165 km/h',
        'accel': '11.8 sec 0-100',
        'mileage': '24.8 km/L',
        'luggage': '265 Litres',
        'safety': '4-Star Global NCAP',
        'units': '12 Hub Units',
        'era': '2024 Hatchback',
      };
    } else if (modelLower.contains('cayman') || modelLower.contains('porche') || modelLower.contains('porsche')) {
      return {
        'power': '325 hp @ 7400 rpm',
        'speed': '281 km/h',
        'accel': '4.9 sec 0-100',
        'mileage': '11.2 km/L',
        'luggage': '275 Litres',
        'safety': '5-Star Euro NCAP',
        'units': '2 Hub Units',
        'era': '2024 Sports Coupe',
      };
    } else {
      // Default / Honda City
      return {
        'power': '121 hp @ 6600 rpm',
        'speed': '195 km/h',
        'accel': '8.8 sec 0-100',
        'mileage': '17.8 km/L',
        'luggage': '506 Litres',
        'safety': '5-Star Global NCAP',
        'units': '10 Hub Units',
        'era': '2024 Edition',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DriveMateProvider>();
    final listing = widget.listing;
    final vehicle = listing.vehicle;
    final specs = _getSpecsForVehicle(vehicle);
    final imageAsset = listing.imageUrl ?? vehicle.imageUrl ?? 'assets/images/car_honda_city.png';
    final perKm = vehicle.perKmRate > 0 ? vehicle.perKmRate.toInt() : 120;
    final dailyRate = listing.dailyRate.toInt();
    final deposit = listing.securityDeposit.toInt();
    final totalPayable = (_selectedDays * dailyRate) + 500; // Daily rent + refundable cleaning fee

    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    final sheetBg = isDark ? AppColors.darkBg : AppColors.lightPage;
    final cardBg = isDark ? AppColors.darkCardBg : Colors.white;
    final cardElevated = isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: borderSubtle, width: 1.5)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Back, Title, Favorite Heart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textPrimary,
                      size: 16,
                    ),
                  ),
                ),
                Text(
                  'Car Details',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() => _isFavorite = !_isFavorite);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isFavorite
                              ? 'Added ${vehicle.model} to your favorites'
                              : 'Removed from favorites',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Icon(
                      _isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                      color: _isFavorite ? AppColors.errorRed : textSecondary,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle Name & Era/Category
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.model,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${vehicle.type} • ${specs['era']}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.successGreen.withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Available',
                              style: TextStyle(
                                color: AppColors.successGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Top 3 Metric Badges Row (Power, Max Speed, Acceleration - Mockup 5)
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecPill(
                          title: 'Power',
                          value: specs['power'] ?? '121 hp',
                          icon: Icons.flash_on_rounded,
                          accentColor: AppColors.accentCyan,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSpecPill(
                          title: 'Max Speed',
                          value: specs['speed'] ?? '195 km/h',
                          icon: Icons.speed_rounded,
                          accentColor: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSpecPill(
                          title: 'Acceleration',
                          value: specs['accel'] ?? '8.8 sec',
                          icon: Icons.timer_outlined,
                          accentColor: AppColors.accentGold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Large 3D Car Image Showcase with Ambient Underglow
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ambient Radial Gradient Underglow beneath vehicle wheels
                        Container(
                          width: 240,
                          height: 70,
                          margin: const EdgeInsets.only(top: 110),
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(100),
                            gradient: RadialGradient(
                              colors: [
                                AppColors.cyanAccent.withOpacity(0.35),
                                AppColors.primaryBlue.withOpacity(0.18),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),

                        // High Definition 3D Car Asset
                        Container(
                          height: 180,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Image.asset(
                            imageAsset,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.directions_car_filled_rounded,
                              size: 110,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),

                        // Left Arrow Indicator
                        Positioned(
                          left: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _activeGalleryIndex = (_activeGalleryIndex - 1) % 3;
                                if (_activeGalleryIndex < 0) _activeGalleryIndex = 2;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg.withOpacity(0.8),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 20),
                            ),
                          ),
                        ),

                        // Right Arrow Indicator
                        Positioned(
                          right: 0,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _activeGalleryIndex = (_activeGalleryIndex + 1) % 3;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg.withOpacity(0.8),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Carousel Pagination Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index == _activeGalleryIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        width: isActive ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.cyanAccent : AppColors.textMuted.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),

                  // Rental's Description Box (Mockup 5)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Rental's Description",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: cardElevated,
                                shape: BoxShape.circle,
                                border: Border.all(color: borderSubtle),
                              ),
                              child: const Icon(
                                Icons.north_east_rounded,
                                color: AppColors.cyanAccent,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listing.description.isNotEmpty
                              ? listing.description
                              : "Versatility meets reliability in this ${vehicle.model}. Equipped with precision handling, modern infotainment, and a comfort-focused cabin, every journey feels smooth, confident, and secure.",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Unit Available & Era Info Cards (Mockup 5)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Units Available',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                specs['units'] ?? '10 Hub Units',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: cardElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Era / Trim',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                specs['era'] ?? '2024 Edition',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Comprehensive Features Grid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle Specifications',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildFeatureRow(Icons.event_seat_rounded, 'Seating', '${vehicle.capacity} Seats', textPrimary)),
                            Expanded(child: _buildFeatureRow(Icons.settings_suggest_rounded, 'Transmission', vehicle.transmission, textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _buildFeatureRow(Icons.local_gas_station_rounded, 'Fuel Type', vehicle.fuelType, textPrimary)),
                            Expanded(child: _buildFeatureRow(Icons.eco_rounded, 'Mileage', specs['mileage'] ?? '17.8 km/L', textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _buildFeatureRow(Icons.luggage_rounded, 'Luggage Space', specs['luggage'] ?? '506 L', textPrimary)),
                            Expanded(child: _buildFeatureRow(Icons.security_rounded, 'Safety Rating', specs['safety'] ?? '5-Star NCAP', textPrimary)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Duration Selector: 1 d, 2 d, 3 d, 5 d, 7 d
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rental Duration:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [1, 2, 3, 5, 7].map((days) {
                          final isSel = _selectedDays == days;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () => setState(() => _selectedDays = days),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primaryBlue : AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? AppColors.primaryBlue : AppColors.borderSubtle,
                                  ),
                                  boxShadow: isSel ? AppColors.blueGlowShadow : null,
                                ),
                                child: Text(
                                  '$days d',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Transparent Cost Breakdown
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Base Rate (₹$dailyRate × $_selectedDays Days):',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              '₹${dailyRate * _selectedDays}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Refundable Security Deposit:',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              '₹$deposit',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentCyan),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sanitization & Insurance Support:',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            Text(
                              '₹500',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        Divider(color: AppColors.borderSubtle, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Payable ($_selectedDays Days):',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              '₹$totalPayable',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.accentCyan),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Digital Vehicle Inspection Shortcut
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_turned_in_outlined, color: AppColors.accentCyan, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pre-Rental Handover Inspection', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Verify odometer, fuel & condition checklist', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => VehicleInspectionSheet.show(context, listing.vehicle),
                          child: const Text('Inspect', style: TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Bottom Sticky Booking Bar (Mockup 5)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderSubtle, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Dual Pricing display
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹$dailyRate/day',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'or ₹$perKm/km self-drive',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 20),

                  // Confirm Booking Action Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          provider.rentCar(
                            listing: listing,
                            startDate: 'Today',
                            endDate: 'In $_selectedDays days',
                            days: _selectedDays,
                            pickupLocation: provider.searchQuery.pickupLocation.isNotEmpty
                                ? provider.searchQuery.pickupLocation
                                : 'Kakdwip Station Road Hub',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Rent This Vehicle',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
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

  Widget _buildSpecPill({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    final pillBg = isDark ? AppColors.darkCardElevated : Colors.white;
    final pillBorder = isDark ? AppColors.darkBorder : AppColors.borderSubtle;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pillBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label, String value, [Color? valueColor]) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.cyanAccent),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
