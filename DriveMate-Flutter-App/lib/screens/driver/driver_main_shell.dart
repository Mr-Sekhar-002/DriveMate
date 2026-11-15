import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';
import '../../components/driver_bottom_nav.dart';
import 'driver_dashboard_screen.dart';
import 'driver_requests_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_profile_screen.dart';

class DriverMainShell extends StatefulWidget {
  final int initialTab;
  const DriverMainShell({super.key, this.initialTab = 0});

  @override
  State<DriverMainShell> createState() => _DriverMainShellState();
}

class _DriverMainShellState extends State<DriverMainShell> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final hasIncoming = provider.incomingDriverRequest != null;

    const List<Widget> tabs = [
      DriverDashboardScreen(),
      DriverRequestsScreen(),
      DriverEarningsScreen(),
      DriverProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: IndexedStack(
        index: _selectedTab,
        children: tabs,
      ),
      bottomNavigationBar: DriverBottomNav(
        currentIndex: _selectedTab,
        badgeCount: hasIncoming ? 1 : 0,
        onTabSelected: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
      ),
    );
  }
}
