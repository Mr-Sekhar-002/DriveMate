import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/helpers/phone_dialer_helper.dart';
import 'package:drivemate_flutter/screens/driver/driver_dashboard_screen.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';

class MockUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;
  LaunchOptions? lastOptions;
  bool shouldSucceed = true;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (!shouldSucceed) return false;
    launchedUrl = url;
    lastOptions = options;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUrlLauncherPlatform mockLauncher;

  setUp(() {
    mockLauncher = MockUrlLauncherPlatform();
    UrlLauncherPlatform.instance = mockLauncher;
  });

  group('PhoneDialerHelper Unit & Widget Tests', () {
    testWidgets('Shows error message when phone number is missing (null or empty)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PhoneDialerHelper.makePhoneCall(context, null),
                child: const Text('Call Missing'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Call Missing'));
      await tester.pumpAndSettle();

      expect(find.text('Customer phone number not available for this booking.'), findsOneWidget);
      expect(mockLauncher.launchedUrl, isNull);
    });

    testWidgets('Shows error message when customer phone is invalid (fewer than 7 digits)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PhoneDialerHelper.makePhoneCall(context, '1234'),
                child: const Text('Call Short'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Call Short'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid customer phone number: "1234"'), findsOneWidget);
      expect(mockLauncher.launchedUrl, isNull);
    });

    testWidgets('Opens dialer with tel: URI and LaunchMode.externalApplication for valid phone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PhoneDialerHelper.makePhoneCall(context, '+91 98765 43210'),
                child: const Text('Call Valid'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Call Valid'));
      await tester.pumpAndSettle();

      expect(mockLauncher.launchedUrl, 'tel:+919876543210');
      expect(mockLauncher.lastOptions?.mode, PreferredLaunchMode.externalApplication);
    });
  });

  group('DriverDashboardScreen Call Customer Integration Tests', () {
    testWidgets('Pickup management card contains Call button and invokes external dialer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = DriveMateProvider();
      // Set active trip to assigned status to render Pickup Management Card
      provider.acceptDriverRequest(
        Booking(
          id: 'BK-1082',
          userId: 'usr_cust_001',
          userName: 'Rahul Sharma',
          customerPhone: '+91 9876543210',
          bookingType: BookingType.hireDriver,
          startDate: 'Immediate',
          endDate: '4 Hours',
          pickupLocation: 'Kakdwip Station',
          destination: 'Namkhana Ferry Ghat',
          totalAmount: 480.0,
          status: BookingStatus.confirmed,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DriverDashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find Call button in Pickup Management Card by its Call icon
      final callButton = find.byIcon(Icons.call);
      await tester.scrollUntilVisible(
        callButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(callButton, findsOneWidget);

      // Tap Call button
      await tester.tap(callButton);
      await tester.pump(const Duration(seconds: 4));

      // Verify that dialer was invoked with the real customer phone
      expect(mockLauncher.launchedUrl, 'tel:+919876543210');
      expect(mockLauncher.lastOptions?.mode, PreferredLaunchMode.externalApplication);
    });

    testWidgets('OTP Verification card contains Call Customer icon button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = DriveMateProvider();
      provider.acceptDriverRequest(
        Booking(
          id: 'BK-1082',
          userId: 'usr_cust_001',
          userName: 'Samiran Kundu',
          customerPhone: '+91 8348708261',
          bookingType: BookingType.hireDriver,
          startDate: 'Immediate',
          endDate: '4 Hours',
          pickupLocation: 'Kakdwip Station',
          destination: 'Namkhana Ferry Ghat',
          totalAmount: 500.0,
          status: BookingStatus.confirmed,
        ),
      );
      // Mark driver arrived to show OTP verification card
      provider.markDriverArrived();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DriverDashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final callIconButton = find.byTooltip('Call Customer');
      await tester.scrollUntilVisible(
        callIconButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(callIconButton, findsOneWidget);

      await tester.tap(callIconButton);
      await tester.pump(const Duration(seconds: 4));

      expect(mockLauncher.launchedUrl, 'tel:+918348708261');
      expect(mockLauncher.lastOptions?.mode, PreferredLaunchMode.externalApplication);
    });
  });
}
