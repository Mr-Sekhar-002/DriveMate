import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Ride Alerts, Payments & Telemetry Updates', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
        actions: [
          TextButton(
            onPressed: () => provider.markNotificationsRead(),
            child: const Text('Mark All Read', style: TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Text('No notifications yet', style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                IconData icon;
                Color iconColor;

                switch (notif.type) {
                  case 'trip':
                    icon = Icons.navigation;
                    iconColor = AppColors.electricBlue;
                    break;
                  case 'payment':
                    icon = Icons.payment;
                    iconColor = AppColors.successGreen;
                    break;
                  case 'booking':
                    icon = Icons.event_available;
                    iconColor = AppColors.accentGold;
                    break;
                  default:
                    icon = Icons.notifications;
                    iconColor = AppColors.cyanAccent;
                }

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  color: notif.isRead ? AppColors.surfaceCard : const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    notif.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                      color: AppColors.navy900,
                                    ),
                                  ),
                                  Text(
                                    notif.timestamp,
                                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif.message,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
