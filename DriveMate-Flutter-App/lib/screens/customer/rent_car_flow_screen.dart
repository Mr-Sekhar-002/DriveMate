import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/car_details_sheet.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class RentCarFlowScreen extends StatefulWidget {
  const RentCarFlowScreen({super.key});

  @override
  State<RentCarFlowScreen> createState() => _RentCarFlowScreenState();
}

class _RentCarFlowScreenState extends State<RentCarFlowScreen> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _favoriteIds = {};
  String _sortBy = 'recommended'; // recommended, price_asc, price_desc, rating

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortFilterModal() {
    final isDark = AppColors.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardBg : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sort & Filter Fleet',
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _buildSortOption('recommended', 'Recommended Fleet', Icons.auto_awesome_rounded),
            _buildSortOption('rating', 'Highest Rated First', Icons.star_rounded),
            _buildSortOption('price_asc', 'Lowest Daily Rate', Icons.arrow_downward_rounded),
            _buildSortOption('price_desc', 'Premium / Luxury First', Icons.arrow_upward_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String key, String label, IconData icon) {
    final isSelected = _sortBy == key;
    return InkWell(
      onTap: () {
        setState(() => _sortBy = key);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.12) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.cyanAccent : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.cyanAccent, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();

    // Search query filtering
    final query = _searchController.text.trim().toLowerCase();

    // Filter available listings matching selected category & query
    var listings = provider.carListings.where((l) {
      final matchesCategory = _selectedCategory == 'All' ||
          l.vehicle.type.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesQuery = query.isEmpty ||
          l.vehicle.model.toLowerCase().contains(query) ||
          l.vehicle.type.toLowerCase().contains(query) ||
          l.vehicle.fuelType.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    // Sorting
    if (_sortBy == 'price_asc') {
      listings.sort((a, b) => a.dailyRate.compareTo(b.dailyRate));
    } else if (_sortBy == 'price_desc') {
      listings.sort((a, b) => b.dailyRate.compareTo(a.dailyRate));
    } else if (_sortBy == 'rating') {
      listings.sort((a, b) => b.rating.compareTo(a.rating));
    }

    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.cardBgOf(context);
    final pageBg = AppColors.pageBgOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
        title: Text(
          'Rental Fleet',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.cyanAccent),
            tooltip: 'Sort & Filter Fleet',
            onPressed: _showSortFilterModal,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar (Mockup 1 & 5)
          Container(
            color: isDark ? AppColors.darkBg : AppColors.pageBgOf(context),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderSubtle),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Search cars by model or brand...',
                  hintStyle: TextStyle(color: AppColors.textMutedOf(context), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.cyanAccent, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Horizontal Category Tabs: All, Hatchback, Sedan, SUV, Luxury (Mockup 1 & 5)
          Container(
            color: isDark ? AppColors.darkCardBg : Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ['All', 'Hatchback', 'Sedan', 'SUV', 'Luxury', 'Electric'].map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = category),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : (isDark ? AppColors.darkCardElevated : AppColors.cardElevated),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryBlue : borderSubtle,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Active Fleet Count & Hub Info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${listings.length} Vehicles Available',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 13, color: AppColors.cyanAccent),
                    SizedBox(width: 3),
                    Text(
                      'West Bengal Hubs',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vehicle List
          Expanded(
            child: listings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_car_outlined, size: 60, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No vehicles match "$query"',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _selectedCategory = 'All');
                          },
                          child: const Text('Reset Filters', style: TextStyle(color: AppColors.cyanAccent)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final listing = listings[index];
                      return _buildPremiumCarCard(context, listing);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCarCard(BuildContext context, CarListing listing) {
    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.cardBgOf(context);
    final bgSecondary = AppColors.cardElevatedOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    final vehicle = listing.vehicle;
    final imageAsset = listing.imageUrl ?? vehicle.imageUrl ?? 'assets/images/car_honda_city.png';
    final perKm = vehicle.perKmRate > 0 ? vehicle.perKmRate.toInt() : 120;
    final dailyRate = listing.dailyRate.toInt();
    final isFavorite = _favoriteIds.contains(listing.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark ? null : AppColors.softShadow,
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Model Name, Category Tag, Heart Favorite
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.model,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${vehicle.type} • ${vehicle.transmission} • ${vehicle.fuelType}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isFavorite) {
                        _favoriteIds.remove(listing.id);
                      } else {
                        _favoriteIds.add(listing.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bgSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderSubtle),
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                      color: isFavorite ? AppColors.errorRed : textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Middle: High-Res 3D Car Image with Ambient Underglow
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radial Gradient Ambient Underglow
                Container(
                  width: 200,
                  height: 48,
                  margin: const EdgeInsets.only(top: 75),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(80),
                    gradient: RadialGradient(
                      colors: [
                        AppColors.cyanAccent.withOpacity(0.28),
                        AppColors.primaryBlue.withOpacity(0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                // 3D Car Image
                Container(
                  height: 125,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Image.asset(
                    imageAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.directions_car_filled_rounded,
                      size: 70,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Specs Bar: Seats, Mileage, Rating
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bgSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderSubtle.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniSpec(Icons.event_seat_rounded, '${vehicle.capacity} Seats'),
                  Container(width: 1, height: 16, color: borderSubtle),
                  _buildMiniSpec(Icons.local_gas_station_rounded, vehicle.fuelType),
                  Container(width: 1, height: 16, color: borderSubtle),
                  _buildMiniSpec(Icons.star_rounded, '${listing.rating.toStringAsFixed(1)} ★'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Bottom Bar: Dual Pricing & Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Dual Pricing in Indian Rupees
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹$dailyRate/day',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'or ₹$perKm/km',
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Action Buttons: "Details" & "Book"
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => CarDetailsSheet.show(context, listing),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cyanAccent,
                        side: const BorderSide(color: AppColors.cyanAccent, width: 1.2),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_outward_rounded, size: 14),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => CarDetailsSheet.show(context, listing),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Book', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSpec(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.cyanAccent),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
