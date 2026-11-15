import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_language.dart';
import 'l10n/app_localizations.dart';
import 'models/drivemate_models.dart';
import 'providers/drivemate_provider.dart';
import 'config/api_config.dart';
import 'theme/app_theme.dart';
import 'components/drivemate_header.dart';
import 'components/drivemate_bottom_nav.dart';
import 'components/rating_review_dialog.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/hire_driver_flow_screen.dart';
import 'screens/customer/driver_selection_screen.dart';
import 'screens/customer/rent_car_flow_screen.dart';
import 'screens/customer/rent_car_and_driver_flow_screen.dart';
import 'screens/customer/active_trip_tracking_screen.dart';
import 'screens/customer/customer_bookings_screen.dart';
import 'screens/customer/customer_reports_screen.dart';
import 'screens/customer/customer_profile_screen.dart';
import 'screens/customer/smart_booking_flow_screen.dart';
import 'screens/driver/driver_main_shell.dart';
import 'screens/owner/car_owner_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/blueprint_inspector_screen.dart';
import 'screens/notifications/notification_center_screen.dart';
import 'screens/support/help_support_screen.dart';
import 'screens/safety/safety_center_screen.dart';
import 'screens/customer/wallet_screen.dart';
import 'screens/customer/offers_rewards_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('[Main] NotificationService init notice: $e');
  }

  final provider = DriveMateProvider();
  await ApiConfig.loadSavedBaseUrl();
  await provider.initLanguage();
  await provider.initThemeMode();

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
    AppColors.isDarkModeGlobal = provider.isDarkMode;

    return MaterialApp(
      title: 'DriveMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: provider.themeMode,
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
        child: const _LaunchGate(),
      ),
    );
  }
}

class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _showSplash
          ? SplashScreen(
              key: const ValueKey('splash'),
              onFinished: () {
                if (mounted) setState(() => _showSplash = false);
              },
            )
          : const MainNavigationShell(key: ValueKey('app')),
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

    final Widget screen = switch (currentRole) {
      UserRole.customer => switch (customerScreen) {
          ActiveCustomerScreen.home => const CustomerHomeScreen(),
          ActiveCustomerScreen.smartBooking => const SmartBookingFlowScreen(),
          ActiveCustomerScreen.driverSelection => const DriverSelectionScreen(),
          ActiveCustomerScreen.hireDriverFlow => const HireDriverFlowScreen(),
          ActiveCustomerScreen.rentCarFlow => const RentCarFlowScreen(),
          ActiveCustomerScreen.rentCarAndDriverFlow => const RentCarAndDriverFlowScreen(),
          ActiveCustomerScreen.activeTripTracking => const ActiveTripTrackingScreen(),
          ActiveCustomerScreen.myBookings => const CustomerBookingsScreen(),
          ActiveCustomerScreen.notifications => const NotificationCenterScreen(),
          ActiveCustomerScreen.helpSupport => const HelpSupportScreen(),
          ActiveCustomerScreen.architectureInspector => const BlueprintInspectorScreen(),
          ActiveCustomerScreen.safetyCenter => const SafetyCenterScreen(),
          ActiveCustomerScreen.wallet => const WalletScreen(),
          ActiveCustomerScreen.offersRewards => const OffersRewardsScreen(),
          ActiveCustomerScreen.reports => const CustomerReportsScreen(),
          ActiveCustomerScreen.profile => const CustomerProfileScreen(),
        },
      UserRole.driver => switch (customerScreen) {
          ActiveCustomerScreen.notifications => const NotificationCenterScreen(),
          ActiveCustomerScreen.helpSupport => const HelpSupportScreen(),
          _ => const DriverMainShell(),
        },
      UserRole.owner => switch (customerScreen) {
          ActiveCustomerScreen.notifications => const NotificationCenterScreen(),
          ActiveCustomerScreen.helpSupport => const HelpSupportScreen(),
          _ => const CarOwnerDashboardScreen(),
        },
      UserRole.admin => switch (customerScreen) {
          ActiveCustomerScreen.architectureInspector => const BlueprintInspectorScreen(),
          ActiveCustomerScreen.notifications => const NotificationCenterScreen(),
          ActiveCustomerScreen.helpSupport => const HelpSupportScreen(),
          _ => const AdminDashboardScreen(),
        },
    };

    final bool showBottomNav = currentRole == UserRole.customer &&
        (customerScreen == ActiveCustomerScreen.home ||
            customerScreen == ActiveCustomerScreen.myBookings ||
            customerScreen == ActiveCustomerScreen.rentCarFlow ||
            customerScreen == ActiveCustomerScreen.notifications ||
            customerScreen == ActiveCustomerScreen.reports ||
            customerScreen == ActiveCustomerScreen.profile);

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
            appBar: (currentRole == UserRole.customer || currentRole == UserRole.driver) ? null : const DriveMateHeader(),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey('${currentRole.name}-${customerScreen.name}'),
                child: screen,
              ),
            ),
            bottomNavigationBar: showBottomNav ? const DriveMateBottomNav() : null,
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
                  : (provider.driverProfile.driverName.isNotEmpty ? provider.driverProfile.driverName : 'Assigned Driver'),
              onDismiss: () => provider.dismissRatingDialog(),
              onSubmit: (rating, comment) => provider.submitReview(rating, comment),
            ),
        ],
      ),
    );
  }
}
