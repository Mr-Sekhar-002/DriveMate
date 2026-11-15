import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_language.dart';
import 'l10n/app_localizations.dart';
import 'models/drivemate_models.dart';
import 'providers/drivemate_provider.dart';
import 'theme/app_theme.dart';
import 'components/drivemate_header.dart';
import 'components/rating_review_dialog.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/hire_driver_flow_screen.dart';
import 'screens/customer/driver_selection_screen.dart';
import 'screens/customer/rent_car_flow_screen.dart';
import 'screens/customer/rent_car_and_driver_flow_screen.dart';
import 'screens/customer/active_trip_tracking_screen.dart';
import 'screens/customer/customer_bookings_screen.dart';
import 'screens/driver/driver_dashboard_screen.dart';
import 'screens/owner/car_owner_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/blueprint_inspector_screen.dart';
import 'screens/notifications/notification_center_screen.dart';
import 'screens/support/help_support_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('[Main] NotificationService init notice: $e');
  }

  final provider = DriveMateProvider();
  await provider.initLanguage();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
      ],
      child: const DriveMateApp(),
    ),
  );
}

class DriveMateApp extends StatelessWidget {
  const DriveMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();

    return MaterialApp(
      title: 'DriveMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: provider.currentLocale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection: provider.textDirection,
        child: const MainNavigationShell(),
      ),
    );
  }
}

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final isLoggedIn = provider.isLoggedIn;
    final currentRole = provider.currentRole;
    final customerScreen = provider.customerScreen;
    final toastMessage = provider.toastMessage;
    final showRating = provider.showRatingDialog;
    final activeTrip = provider.activeTrip;

    // If not authenticated, present AuthScreen
    if (!isLoggedIn) {
      return AuthScreen(
        onLogin: (email, role) => provider.login(email, role),
        onRegister: (name, email, phone, role, license) => provider.register(
          name: name,
          email: email,
          phone: phone,
          role: role,
          licenseNumber: license,
        ),
      );
    }

    // Determine bottom nav index for customer mode
    int bottomNavIndex = 0;
    switch (customerScreen) {
      case ActiveCustomerScreen.home:
      case ActiveCustomerScreen.hireDriverFlow:
      case ActiveCustomerScreen.driverSelection:
      case ActiveCustomerScreen.rentCarFlow:
      case ActiveCustomerScreen.rentCarAndDriverFlow:
        bottomNavIndex = 0;
        break;
      case ActiveCustomerScreen.myBookings:
        bottomNavIndex = provider.bookingFilter == 'Completed' ? 3 : 1;
        break;
      case ActiveCustomerScreen.activeTripTracking:
        bottomNavIndex = 2;
        break;
      case ActiveCustomerScreen.helpSupport:
      case ActiveCustomerScreen.architectureInspector:
      case ActiveCustomerScreen.notifications:
        bottomNavIndex = 0;
        break;
    }

    return PopScope(
      canPop: customerScreen == ActiveCustomerScreen.home && currentRole == UserRole.customer,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (customerScreen != ActiveCustomerScreen.home) {
          provider.navigateTo(ActiveCustomerScreen.home);
        } else if (currentRole != UserRole.customer) {
          provider.switchRole(UserRole.customer);
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: const DriveMateHeader(),
            body: switch (currentRole) {
              UserRole.customer => switch (customerScreen) {
                  ActiveCustomerScreen.home => const CustomerHomeScreen(),
                  ActiveCustomerScreen.driverSelection => const DriverSelectionScreen(),
                  ActiveCustomerScreen.hireDriverFlow => const HireDriverFlowScreen(),
                  ActiveCustomerScreen.rentCarFlow => const RentCarFlowScreen(),
                  ActiveCustomerScreen.rentCarAndDriverFlow => const RentCarAndDriverFlowScreen(),
                  ActiveCustomerScreen.activeTripTracking => const ActiveTripTrackingScreen(),
                  ActiveCustomerScreen.myBookings => const CustomerBookingsScreen(),
                  ActiveCustomerScreen.notifications => const NotificationCenterScreen(),
                  ActiveCustomerScreen.helpSupport => const HelpSupportScreen(),
                  ActiveCustomerScreen.architectureInspector => const BlueprintInspectorScreen(),
                },
              UserRole.driver => customerScreen == ActiveCustomerScreen.helpSupport
                  ? const HelpSupportScreen()
                  : const DriverDashboardScreen(),
              UserRole.owner => customerScreen == ActiveCustomerScreen.helpSupport
                  ? const HelpSupportScreen()
                  : const CarOwnerDashboardScreen(),
              UserRole.admin => customerScreen == ActiveCustomerScreen.architectureInspector
                  ? const BlueprintInspectorScreen()
                  : (customerScreen == ActiveCustomerScreen.helpSupport
                      ? const HelpSupportScreen()
                      : const AdminDashboardScreen()),
            },
            bottomNavigationBar: currentRole == UserRole.customer &&
                    customerScreen != ActiveCustomerScreen.hireDriverFlow &&
                    customerScreen != ActiveCustomerScreen.driverSelection &&
                    customerScreen != ActiveCustomerScreen.rentCarFlow &&
                    customerScreen != ActiveCustomerScreen.rentCarAndDriverFlow &&
                    customerScreen != ActiveCustomerScreen.notifications &&
                    customerScreen != ActiveCustomerScreen.helpSupport &&
                    customerScreen != ActiveCustomerScreen.architectureInspector
                ? NavigationBar(
                    backgroundColor: AppColors.navy900,
                    indicatorColor: AppColors.cyanAccent,
                    selectedIndex: bottomNavIndex,
                    onDestinationSelected: (idx) {
                      switch (idx) {
                        case 0:
                          provider.navigateTo(ActiveCustomerScreen.home);
                          break;
                        case 1:
                          provider.setBookingFilter('All');
                          provider.navigateTo(ActiveCustomerScreen.myBookings);
                          break;
                        case 2:
                          provider.navigateTo(ActiveCustomerScreen.activeTripTracking);
                          break;
                        case 3:
                          provider.setBookingFilter('Completed');
                          provider.navigateTo(ActiveCustomerScreen.myBookings);
                          break;
                      }
                    },
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.home_outlined, color: AppColors.textSecondaryLight),
                        selectedIcon: const Icon(Icons.home, color: AppColors.navy900),
                        label: context.l10n.navHome,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.calendar_month_outlined, color: AppColors.textSecondaryLight),
                        selectedIcon: const Icon(Icons.calendar_month, color: AppColors.navy900),
                        label: context.l10n.navBookings,
                      ),
                      NavigationDestination(
                        icon: Badge(
                          isLabelVisible: activeTrip != null,
                          backgroundColor: AppColors.successGreen,
                          smallSize: 8,
                          child: const Icon(Icons.navigation_outlined, color: AppColors.textSecondaryLight),
                        ),
                        selectedIcon: const Icon(Icons.navigation, color: AppColors.navy900),
                        label: context.l10n.navLiveRide,
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.receipt_long_outlined, color: AppColors.textSecondaryLight),
                        selectedIcon: const Icon(Icons.receipt_long, color: AppColors.navy900),
                        label: context.l10n.navInvoices,
                      ),
                    ],
                  )
                : null,
          ),

          // Floating Feedback Toast Message
          if (toastMessage != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: SafeArea(
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.navy900,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.cyanAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.cyanAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            toastMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Rating & Review Modal Dialog when a trip completes
          if (showRating)
            RatingReviewDialog(
              driverName: (activeTrip != null && activeTrip.driverName.isNotEmpty)
                  ? activeTrip.driverName
                  : (provider.driverProfile.driverName.isNotEmpty ? provider.driverProfile.driverName : 'Assigned Chauffeur'),
              onDismiss: () => provider.dismissRatingDialog(),
              onSubmit: (rating, comment) => provider.submitReview(rating, comment),
            ),
        ],
      ),
    );
  }
}
