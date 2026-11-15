import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/drivemate_provider.dart';
import '../theme/app_theme.dart';

class DriveMateBottomNav extends StatelessWidget {
  const DriveMateBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final currentScreen = provider.customerScreen;
    final unreadCount = provider.unreadNotificationsCount;
    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBg : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.line, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.4) : const Color(0x140B1C38),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Home
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentScreen == ActiveCustomerScreen.home,
                onTap: () => provider.navigateTo(ActiveCustomerScreen.home),
              ),

              // 2. Explore / Fleet
              _buildNavItem(
                icon: Icons.directions_car_rounded,
                label: 'Explore',
                isSelected: currentScreen == ActiveCustomerScreen.rentCarFlow,
                onTap: () => provider.navigateTo(ActiveCustomerScreen.rentCarFlow),
              ),

              // 3. Center Elevated '+' Button (Hire a Driver quick trigger)
              GestureDetector(
                onTap: () => provider.navigateTo(ActiveCustomerScreen.hireDriverFlow),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.blueGlowShadow,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              // 4. Bookings
              _buildNavItem(
                icon: Icons.calendar_month_rounded,
                label: 'Bookings',
                badgeCount: unreadCount,
                isSelected: currentScreen == ActiveCustomerScreen.myBookings,
                onTap: () {
                  provider.setBookingFilter('All');
                  provider.navigateTo(ActiveCustomerScreen.myBookings);
                },
              ),

              // 5. Profile
              _buildNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                isSelected: currentScreen == ActiveCustomerScreen.profile,
                onTap: () => provider.navigateTo(ActiveCustomerScreen.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final color = isSelected ? AppColors.primaryBlue : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
