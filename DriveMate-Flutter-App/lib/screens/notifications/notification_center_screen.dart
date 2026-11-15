import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String _selectedCategory = 'All'; // 'All', 'Rides', 'Payments', 'Safety', 'Offers'

  void _showSettingsModal(BuildContext context, DriveMateProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notification Settings',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.accentCyan,
                title: const Text('Sound Alerts', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: const Text('Play audible ringtone on ride updates and messages', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                value: provider.notificationSound,
                onChanged: (val) {
                  provider.setNotificationSound(val);
                  setModalState(() {});
                },
              ),
              const Divider(color: AppColors.borderSubtle),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.accentCyan,
                title: const Text('Haptic Vibration', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                subtitle: const Text('Vibrate device on chauffeur arrival and safety alarms', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                value: provider.notificationVibration,
                onChanged: (val) {
                  provider.setNotificationVibration(val);
                  setModalState(() {});
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('SAVE PREFERENCES', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final allNotifications = provider.notifications;

    final filteredList = allNotifications.where((n) {
      if (_selectedCategory == 'Rides') {
        return n.type == 'trip' || n.type == 'booking' || n.type == 'driver' || n.type == 'arrived';
      }
      if (_selectedCategory == 'Payments') {
        return n.type == 'payment';
      }
      if (_selectedCategory == 'Safety') {
        return n.type == 'safety';
      }
      if (_selectedCategory == 'Offers') {
        return n.type == 'promo';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Center',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Real-Time Ride Alerts & Pushes',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.accentCyan),
            tooltip: 'Notification Settings',
            onPressed: () => _showSettingsModal(context, provider),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.cardBg,
            onSelected: (val) {
              if (val == 'mark_read') {
                provider.markNotificationsRead();
              } else if (val == 'clear_all') {
                provider.clearAllNotifications();
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all, color: AppColors.accentCyan, size: 18),
                    SizedBox(width: 10),
                    Text('Mark All Read', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, color: AppColors.errorRed, size: 18),
                    SizedBox(width: 10),
                    Text('Clear All', style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // CATEGORY FILTER BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.bgSecondary,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Rides', 'Payments', 'Safety', 'Offers'].map((cat) {
                  final isSel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSel ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.primaryBlue,
                      backgroundColor: AppColors.cardBg,
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // NOTIFICATIONS LIST
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 56, color: AppColors.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'No Notifications',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updates for $_selectedCategory will appear here.',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredList.length,
                    itemBuilder: (ctx, idx) {
                      final item = filteredList[idx];
                      final iconData = _getNotificationIcon(item.type);
                      final iconColor = _getNotificationColor(item.type);

                      return Dismissible(
                        key: Key('notif_${item.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 24),
                        ),
                        onDismissed: (_) {
                          provider.deleteNotification(item.id);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: item.isRead ? AppColors.cardBg : AppColors.cardElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isRead ? AppColors.borderSubtle : AppColors.accentCyan.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(iconData, color: iconColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 14,
                                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!item.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(left: 6),
                                            decoration: const BoxDecoration(
                                              color: AppColors.accentCyan,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.message,
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          item.timestamp,
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                        ),
                                        InkWell(
                                          onTap: () => provider.deleteNotification(item.id),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            child: Icon(Icons.close, color: AppColors.textMuted, size: 14),
                                          ),
                                        ),
                                      ],
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
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'trip':
      case 'driver':
      case 'arrived':
        return Icons.navigation_rounded;
      case 'booking':
        return Icons.event_available_rounded;
      case 'payment':
        return Icons.account_balance_wallet_rounded;
      case 'safety':
        return Icons.shield_rounded;
      case 'promo':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'trip':
      case 'driver':
      case 'arrived':
        return AppColors.primaryBlue;
      case 'booking':
        return AppColors.accentCyan;
      case 'payment':
        return AppColors.successGreen;
      case 'safety':
        return AppColors.errorRed;
      case 'promo':
        return AppColors.warningAmber;
      default:
        return AppColors.accentCyan;
    }
  }
}
