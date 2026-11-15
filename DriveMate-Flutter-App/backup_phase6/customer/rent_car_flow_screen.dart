import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class RentCarFlowScreen extends StatefulWidget {
  const RentCarFlowScreen({super.key});

  @override
  State<RentCarFlowScreen> createState() => _RentCarFlowScreenState();
}

class _RentCarFlowScreenState extends State<RentCarFlowScreen> {
  int _selectedDays = 2;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final filter = provider.selectedCarTypeFilter;

    // Self-drive or Both listings
    final availableListings = provider.carListings.where((l) {
      final matchesType = l.rentalType == RentalType.selfDrive || l.rentalType == RentalType.both;
      final matchesFilter = filter == 'All' || l.vehicle.type.toLowerCase() == filter.toLowerCase();
      return matchesType && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rent a Car', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Self-Drive • Verified Fleet & Instant Unlock', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips & Duration Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surfaceCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Vehicle Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondaryDark)),
                    Row(
                      children: [
                        const Text('Duration: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        DropdownButton<int>(
                          value: _selectedDays,
                          underline: const SizedBox(),
                          isDense: true,
                          items: [1, 2, 3, 5, 7].map((d) => DropdownMenuItem(value: d, child: Text('$d Days', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDays = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Sedan', 'SUV', 'Luxury', 'Hatchback'].map((type) {
                      final isSelected = filter == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(type, style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : AppColors.navy700, fontWeight: FontWeight.bold)),
                          selected: isSelected,
                          selectedColor: AppColors.electricBlue,
                          backgroundColor: AppColors.surfaceLight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onSelected: (val) {
                            if (val) provider.setCarTypeFilter(type);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.black12),

          // Available Cars List
          Expanded(
            child: availableListings.isEmpty
                ? const Center(
                    child: Text('No vehicles available for this filter', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: availableListings.length,
                    itemBuilder: (context, index) {
                      final listing = availableListings[index];
                      final totalRent = _selectedDays * listing.dailyRate + 25.0; // Daily rate * days + processing

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        listing.vehicle.model,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                                      ),
                                      Text(
                                        '${listing.vehicle.type} • ${listing.vehicle.transmission} • ${listing.vehicle.fuelType}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${listing.dailyRate.toInt()}',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.electricBlue),
                                      ),
                                      const Text('/day (Self-Drive)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              Text(
                                listing.description,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                              ),

                              const SizedBox(height: 12),

                              // Key Features Pill Bar
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildFeaturePill(Icons.shield_outlined, 'Deposit: ₹${listing.securityDeposit.toInt()}'),
                                  _buildFeaturePill(Icons.pin_drop_outlined, listing.location),
                                  _buildFeaturePill(Icons.event_available, 'Available Now'),
                                ],
                              ),

                              const SizedBox(height: 14),
                              Divider(color: Colors.grey.shade200, height: 1),
                              const SizedBox(height: 12),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$_selectedDays Days Total (inc fees):', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text('₹${totalRent.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                                    ],
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.electricBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    ),
                                    onPressed: () {
                                      provider.rentCar(
                                        listing: listing,
                                        startDate: 'Today',
                                        endDate: 'In $_selectedDays Days',
                                        days: _selectedDays,
                                        pickupLocation: listing.location,
                                      );
                                    },
                                    child: const Text('Book Self-Drive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _buildFeaturePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.navy700),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.navy700, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
