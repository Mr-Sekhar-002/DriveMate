import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class CarOwnerDashboardScreen extends StatefulWidget {
  const CarOwnerDashboardScreen({super.key});

  @override
  State<CarOwnerDashboardScreen> createState() => _CarOwnerDashboardScreenState();
}

class _CarOwnerDashboardScreenState extends State<CarOwnerDashboardScreen> {
  void _showAddCarDialog(BuildContext context) {
    final modelController = TextEditingController(text: 'Tesla Model 3');
    final plateController = TextEditingController(text: 'NYC-4481');
    final descController = TextEditingController(text: 'All-electric premium sedan with autopilot features.');
    final dailyRateController = TextEditingController(text: '95');
    final hourlyRateController = TextEditingController(text: '18');
    String selectedType = 'Sedan';
    RentalType selectedRentalType = RentalType.both;
    int capacity = 5;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('List a Vehicle on DriveMate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: modelController,
                      decoration: const InputDecoration(labelText: 'Car Model (e.g. Toyota Camry)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                            items: ['Sedan', 'SUV', 'Luxury', 'Hatchback']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (v) => setDialogState(() => selectedType = v ?? 'Sedan'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: plateController,
                            decoration: const InputDecoration(labelText: 'Plate No', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dailyRateController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Daily Rate (₹)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: hourlyRateController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Hourly Rate (₹)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<RentalType>(
                      value: selectedRentalType,
                      decoration: const InputDecoration(labelText: 'Rental Mode Allowed', border: OutlineInputBorder()),
                      items: RentalType.values
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.label, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedRentalType = v ?? RentalType.both),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Vehicle Description', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electricBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final model = modelController.text.trim();
                    final plate = plateController.text.trim();
                    final daily = double.tryParse(dailyRateController.text) ?? 80.0;
                    final hourly = double.tryParse(hourlyRateController.text) ?? 15.0;
                    final desc = descController.text.trim();

                    if (model.isNotEmpty) {
                      context.read<DriveMateProvider>().listNewCar(
                            model: model,
                            type: selectedType,
                            numberPlate: plate,
                            capacity: capacity,
                            hourlyRate: hourly,
                            dailyRate: daily,
                            rentalType: selectedRentalType,
                            description: desc,
                          );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('List Vehicle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final listings = provider.carListings;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.electricBlue,
        foregroundColor: Colors.white,
        onPressed: () => _showAddCarDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('List My Car', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Revenue Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Car Owner Portal (DriveMate)',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Monetize your vehicle with Self-Drive or Chauffeur rentals',
                    style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withOpacity(0.12)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildOwnerStat('Fleet Size', '${listings.length} Cars', Colors.white),
                      _buildOwnerStat('Monthly Payout', '₹48,200', AppColors.cyanAccent),
                      _buildOwnerStat('Utilization', '84%', AppColors.successGreen),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Active Fleet Listings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                ),
                TextButton.icon(
                  onPressed: () => _showAddCarDialog(context),
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('Add Vehicle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ...listings.map((listing) {
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
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.directions_car, color: AppColors.navy900, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listing.vehicle.model,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                                  ),
                                  Text(
                                    'Plate: ${listing.vehicle.numberPlate} • ${listing.vehicle.type}',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: listing.isAvailable ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              listing.isAvailable ? 'AVAILABLE' : 'RENTED',
                              style: TextStyle(
                                color: listing.isAvailable ? AppColors.successGreen : AppColors.errorRed,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        listing.description,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily: ₹${listing.dailyRate.toInt()} • Hourly: ₹${listing.hourlyRate.toInt()} • Mode: ${listing.rentalType.label}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.navy700),
                          ),
                          Text(
                            listing.location,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
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

  static Widget _buildOwnerStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
