import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class RentCarAndDriverFlowScreen extends StatefulWidget {
  const RentCarAndDriverFlowScreen({super.key});

  @override
  State<RentCarAndDriverFlowScreen> createState() => _RentCarAndDriverFlowScreenState();
}

class _RentCarAndDriverFlowScreenState extends State<RentCarAndDriverFlowScreen> {
  late TextEditingController _pickupController;
  late TextEditingController _destController;
  final int _selectedHours = 6;

  @override
  void initState() {
    super.initState();
    final provider = context.read<DriveMateProvider>();
    _pickupController = TextEditingController(text: provider.searchQuery.pickupLocation);
    _destController = TextEditingController(text: provider.searchQuery.destination);
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();

    // Listings that support With Driver or Both
    final chauffeurListings = provider.carListings.where((l) {
      return l.rentalType == RentalType.withDriver || l.rentalType == RentalType.both;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rent Car + Driver', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Chauffeur Driven • Premium Comfort & Outstation', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Blueprint Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.workspace_premium, color: AppColors.accentGold, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Executive Chauffeur Package',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Car + Uniformed Professional Chauffeur included. Zero fuel hassle.',
                          style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pickup & Destination
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextField(
                      controller: _pickupController,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Pickup Point',
                        prefixIcon: const Icon(Icons.my_location, color: AppColors.electricBlue, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _destController,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        labelText: 'Dropoff / Destination',
                        prefixIcon: const Icon(Icons.location_on, color: AppColors.accentGold, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Select Premium Vehicle Package:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
            ),

            const SizedBox(height: 10),

            ...chauffeurListings.map((listing) {
              final total = _selectedHours * listing.hourlyRate;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.navy900,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.directions_car, color: AppColors.cyanAccent, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listing.vehicle.model,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                                  ),
                                  Text(
                                    '${listing.vehicle.type} • Includes Dedicated Chauffeur',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${listing.hourlyRate.toInt()}/hr',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.electricBlue),
                              ),
                              const Text('Package Rate', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$_selectedHours Hours Package Total:', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              Text('₹${total.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy900,
                              foregroundColor: AppColors.cyanAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () {
                              provider.rentCarWithDriver(
                                listing: listing,
                                startDate: 'Today, Immediate',
                                endDate: '$_selectedHours Hours Chauffeur Service',
                                pickupLocation: _pickupController.text.trim(),
                                destination: _destController.text.trim(),
                                total: total,
                              );
                            },
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Book Package', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
