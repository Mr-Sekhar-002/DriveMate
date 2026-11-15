import 'package:flutter/material.dart';
import '../models/drivemate_models.dart';
import '../theme/app_theme.dart';
import 'driver_reviews_sheet.dart';

class DriverProfileSheet extends StatelessWidget {
  final EligibleDriver driver;
  final VoidCallback onSelect;

  const DriverProfileSheet({
    super.key,
    required this.driver,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required EligibleDriver driver,
    required VoidCallback onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DriverProfileSheet(driver: driver, onSelect: onSelect),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.cyanAccent, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Driver Profile & Verification',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Driver Avatar & Name Card
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.cyanAccent, AppColors.electricBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyanAccent.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'D',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              driver.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: AppColors.cyanAccent, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.cyanAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cyanAccent.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'GOVERNMENT VERIFIED CHAUFFEUR',
                          style: TextStyle(
                            color: AppColors.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Key Performance Highlights Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.star,
                        iconColor: Colors.amber,
                        title: driver.avgRating != null ? driver.avgRating!.toStringAsFixed(1) : 'New',
                        subtitle: 'Average Rating',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.alt_route,
                        iconColor: AppColors.cyanAccent,
                        title: '${driver.totalTrips}',
                        subtitle: 'Completed Trips',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.workspace_premium,
                        iconColor: Colors.lightGreenAccent,
                        title: driver.experienceYears != null ? '${driver.experienceYears} Yrs' : 'Verified',
                        subtitle: 'Experience',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Languages & Professional Bio
                if ((driver.languages != null && driver.languages!.isNotEmpty) || (driver.bio != null && driver.bio!.isNotEmpty)) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.translate, color: AppColors.cyanAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Languages & Chauffeur Specialty',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (driver.languages != null && driver.languages!.isNotEmpty)
                          _buildInfoRow('Languages', driver.languages!),
                        if (driver.bio != null && driver.bio!.isNotEmpty)
                          _buildInfoRow('Chauffeur Note', driver.bio!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Vehicle & Fleet Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy800,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.directions_car, color: AppColors.cyanAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Vehicle Information',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Vehicle Model', driver.vehicleModel),
                      _buildInfoRow('Vehicle Category', driver.vehicleType),
                      if (driver.vehicleNumber != null && driver.vehicleNumber!.isNotEmpty)
                        _buildInfoRow('Registration Plate', driver.vehicleNumber!),
                      if (driver.licenseNumber != null)
                        _buildInfoRow('License Document', '${driver.licenseNumber!.substring(0, 4)}•••• verified'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Availability & Proximity
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy800,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.near_me, color: AppColors.cyanAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Proximity & Telemetry',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Live Status',
                        driver.isOnline ? 'Online • Ready for Booking' : 'Offline',
                        valueColor: driver.isOnline ? Colors.greenAccent : Colors.grey,
                      ),
                      if (driver.distanceKm != null)
                        _buildInfoRow('Pickup Distance', '${driver.distanceKm!.toStringAsFixed(1)} km away'),
                      if (driver.etaMinutes != null)
                        _buildInfoRow('Estimated Arrival (ETA)', '~${driver.etaMinutes} minutes'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Security & Privacy Shield Notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cyanAccent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cyanAccent.withOpacity(0.2)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.cyanAccent, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Privacy Protected Communication',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'To safeguard personal privacy, phone dialer access is enabled inside your live dashboard once a mutually negotiated booking is confirmed.',
                              style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Reviews Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    DriverReviewsSheet.show(context, driver);
                  },
                  icon: const Icon(Icons.rate_review, color: AppColors.cyanAccent, size: 18),
                  label: const Text('View Customer Reviews & Feedback', style: TextStyle(color: AppColors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.cyanAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 12),

                // Select Driver Button
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSelect();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyanAccent,
                    foregroundColor: AppColors.navy900,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Select ${driver.name} & Continue',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color valueColor = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
