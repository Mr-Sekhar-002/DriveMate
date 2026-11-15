import 'package:flutter/material.dart';
import '../models/drivemate_models.dart';
import '../theme/app_theme.dart';

class SmartMatchResultDialog extends StatelessWidget {
  final EligibleDriver driver;
  final VoidCallback onAccept;
  final VoidCallback onTryAnother;

  const SmartMatchResultDialog({
    super.key,
    required this.driver,
    required this.onAccept,
    required this.onTryAnother,
  });

  static Future<void> show(
    BuildContext context, {
    required EligibleDriver driver,
    required VoidCallback onAccept,
    required VoidCallback onTryAnother,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SmartMatchResultDialog(
        driver: driver,
        onAccept: onAccept,
        onTryAnother: onTryAnother,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = driver.scoreBreakdown;
    final totalScore = driver.matchScore ?? 95.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.navy900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cyanAccent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyanAccent.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Smart Match Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.cyanAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: AppColors.cyanAccent, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'SMART AUTO MATCHED',
                    style: TextStyle(
                      color: AppColors.cyanAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Driver Card Preview
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.cyanAccent,
                  child: Text(
                    driver.name.isNotEmpty ? driver.name[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: AppColors.navy900,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppColors.cyanAccent, size: 16),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${driver.vehicleModel} • ${driver.vehicleType}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            driver.avgRating != null ? driver.avgRating!.toStringAsFixed(1) : 'New',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  ${driver.totalTrips} Trips',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.navy800,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${totalScore.toInt()}%',
                        style: const TextStyle(
                          color: AppColors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'FIT SCORE',
                        style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Distance & ETA Pill Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navy800,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPillItem(
                    icon: Icons.navigation_outlined,
                    label: driver.distanceKm != null ? '${driver.distanceKm!.toStringAsFixed(1)} km' : 'Nearby',
                    caption: 'Distance',
                  ),
                  Container(height: 24, width: 1, color: Colors.white12),
                  _buildPillItem(
                    icon: Icons.access_time,
                    label: driver.etaMinutes != null ? '~${driver.etaMinutes} mins' : 'Immediate',
                    caption: 'Estimated Arrival',
                  ),
                  Container(height: 24, width: 1, color: Colors.white12),
                  _buildPillItem(
                    icon: Icons.workspace_premium_outlined,
                    label: driver.experienceYears != null ? '${driver.experienceYears} Yrs' : 'Certified',
                    caption: 'Experience',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Transparent Algorithm Weights Breakdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transparent Matching Criteria:',
                    style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  _buildWeightRow('Availability (35% weight)', '${breakdown?['availability_pts'] ?? 35} pts'),
                  _buildWeightRow('Distance & Arrival ETA (30% weight)', '${breakdown?['distance_eta_pts'] ?? 28} pts'),
                  _buildWeightRow('Genuine Customer Rating (20% weight)', '${breakdown?['rating_pts'] ?? 20} pts'),
                  _buildWeightRow('Experience & Trips (10% weight)', '${breakdown?['experience_pts'] ?? 10} pts'),
                  _buildWeightRow('Service Compatibility (5% weight)', '${breakdown?['compatibility_pts'] ?? 5} pts'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onTryAnother();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Try Another', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onAccept();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyanAccent,
                      foregroundColor: AppColors.navy900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Book Matched Chauffeur',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillItem({
    required IconData icon,
    required String label,
    required String caption,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.cyanAccent, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 2),
        Text(caption, style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
      ],
    );
  }

  Widget _buildWeightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
          Text(value, style: const TextStyle(color: AppColors.cyanAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
