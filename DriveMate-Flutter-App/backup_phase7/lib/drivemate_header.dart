import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drivemate_models.dart';
import '../providers/drivemate_provider.dart';
import '../theme/app_theme.dart';
import 'drivemate_logo.dart';
import 'language_selection_dialog.dart';
import 'ai_chatbot_dialog.dart';

class DriveMateHeader extends StatelessWidget implements PreferredSizeWidget {
  const DriveMateHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final currentRole = provider.currentRole;
    final unreadCount = provider.unreadNotificationsCount;

    Color roleBgColor;
    Color roleTextColor;
    switch (currentRole) {
      case UserRole.customer:
        roleBgColor = AppColors.cyanLight;
        roleTextColor = AppColors.navy900;
        break;
      case UserRole.driver:
        roleBgColor = const Color(0xFFD1FAE5);
        roleTextColor = const Color(0xFF065F46);
        break;
      case UserRole.owner:
        roleBgColor = const Color(0xFFFEF3C7);
        roleTextColor = const Color(0xFF92400E);
        break;
      case UserRole.admin:
        roleBgColor = const Color(0xFFEDE9FE);
        roleTextColor = const Color(0xFF5B21B6);
        break;
    }

    return Container(
      color: AppColors.navy900,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 12,
        right: 12,
        bottom: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Logo & Name
          Expanded(
            child: InkWell(
              onTap: () => provider.navigateTo(ActiveCustomerScreen.home),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Redesigned Professional DriveMate Brand Logo
                  const DriveMateLogo(size: 36, showGlow: true),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Drive',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              TextSpan(
                                text: 'Mate',
                                style: TextStyle(
                                  color: AppColors.cyanAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Your Car. Your Driver.',
                          style: TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Icons & Strict RBAC Role Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI Chatbot Assistant Button
              IconButton(
                icon: const Icon(Icons.smart_toy_outlined, color: AppColors.cyanAccent, size: 20),
                tooltip: 'AI Assistant',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: () => AiChatbotDialog.show(context),
              ),

              const SizedBox(width: 2),

              // Language Selector Badge Button
              InkWell(
                onTap: () => LanguageSelectionDialog.show(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navy800,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cyanAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language, color: AppColors.cyanAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        provider.currentLanguage.code.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Help & Support Button (Customer and Driver)
              if (currentRole == UserRole.customer || currentRole == UserRole.driver)
                IconButton(
                  icon: const Icon(Icons.help_outline, color: AppColors.cyanAccent, size: 20),
                  tooltip: 'Help & Support',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    provider.navigateTo(ActiveCustomerScreen.helpSupport);
                  },
                ),

              // Architecture & Blueprint ERD Button (Admin Only)
              if (currentRole == UserRole.admin)
                IconButton(
                  icon: const Icon(Icons.account_tree_outlined, color: AppColors.cyanAccent, size: 20),
                  tooltip: 'Blueprint & Architecture Inspector',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    provider.navigateTo(ActiveCustomerScreen.architectureInspector);
                  },
                ),

              // Notifications Button with Badge
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                    tooltip: 'Notifications',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      provider.navigateTo(ActiveCustomerScreen.notifications);
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.errorRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 4),

              // Strict RBAC Role Badge / Administrative Controls
              if (currentRole == UserRole.admin)
                PopupMenuButton<dynamic>(
                  tooltip: 'Admin Role Switcher',
                  color: AppColors.navy800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (value) {
                    if (value is UserRole) {
                      provider.switchRole(value);
                    } else if (value == 'logout') {
                      provider.logout();
                    }
                  },
                  itemBuilder: (context) => [
                    ...UserRole.values.map(
                      (role) => PopupMenuItem<dynamic>(
                        value: role,
                        child: Row(
                          children: [
                            Icon(
                              switch (role) {
                                UserRole.customer => Icons.person,
                                UserRole.driver => Icons.airline_seat_recline_extra,
                                UserRole.owner => Icons.directions_car,
                                UserRole.admin => Icons.admin_panel_settings,
                              },
                              color: role == currentRole ? AppColors.cyanAccent : Colors.white70,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${role.label} View',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: role == currentRole ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12.5,
                              ),
                            ),
                            if (role == currentRole) ...[
                              const Spacer(),
                              const Icon(Icons.check, color: AppColors.cyanAccent, size: 16),
                            ]
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<dynamic>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: AppColors.errorRed, size: 18),
                          SizedBox(width: 10),
                          Text('Sign Out', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: roleBgColor, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(currentRole.label, style: TextStyle(color: roleTextColor, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_drop_down, color: roleTextColor, size: 16),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: roleBgColor, borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        currentRole.label.toUpperCase(),
                        style: TextStyle(color: roleTextColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                      tooltip: 'Sign Out',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => provider.logout(),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
