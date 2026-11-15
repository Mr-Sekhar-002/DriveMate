import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/customer/active_trip_tracking_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Redesigned Live Ride Tracking Screen Tests', () {
    testWidgets('Renders Active Live Navigation with dominant map, route, chauffeur & OTP', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = DriveMateProvider();
      final initialTrip = Trip(
        id: 'TRP-883',
        bookingId: 'BK-1082',
        driverId: 'drv_01',
        driverName: 'Amitava Roy',
        driverPhone: '+91 98745 61230',
        vehicleModel: 'Honda City 2023 (Automatic)',
        startLocation: 'Kakdwip Railway Station, WB 743347',
        endLocation: 'Kakdwip Ferry Ghat (Lot 8)',
        startLat: 21.8767,
        startLng: 88.1912,
        endLat: 21.8712,
        endLng: 88.1824,
        fare: 600.0,
        status: TripStatus.onTrip,
        currentProgress: 0.45,
        customerName: 'Rajesh Das',
        customerPhone: '+91 98301 23456',
        startTime: '10:30 AM',
        distanceKm: 8.5,
        otp: '4892',
      );
      provider.setActiveTrip(initialTrip);

      // Ensure active trip is present and onTrip
      expect(provider.activeTrip != null, true);
      expect(provider.activeTrip!.status, TripStatus.onTrip);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: const MaterialApp(
            home: ActiveTripTrackingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Top Floating Navigation Capsule & Status
      expect(find.text('ON TRIP TO DESTINATION'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.emergency_share), findsOneWidget);

      // 2. Verify Floating Map Action Buttons
      expect(find.byIcon(Icons.crop_free), findsOneWidget);
      expect(find.byIcon(Icons.navigation), findsWidgets); // Vehicle and center button
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);

      // 3. Verify Docked Trip Information Section
      expect(find.textContaining('Kakdwip Railway Station'), findsOneWidget);
      expect(find.textContaining('Kakdwip Ferry Ghat'), findsOneWidget);
      expect(find.text('Amitava Roy'), findsOneWidget);
      expect(find.textContaining('Honda City'), findsOneWidget);
      expect(find.text('START OTP'), findsOneWidget);
      expect(find.text(provider.activeTrip!.otp), findsOneWidget);
      expect(find.text('Call Chauffeur'), findsOneWidget);
      expect(find.text('SOS Safety'), findsOneWidget);

      // 4. Verify no simulated speed strings exist
      expect(find.textContaining('Simulated Speed'), findsNothing);
      expect(find.textContaining('42 km/h'), findsNothing);
      expect(find.textContaining('Speed: 44 km/h'), findsNothing);

      provider.stopDriverLiveTracking();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Renders Completed Trip Summary when trip.status == TripStatus.completed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = DriveMateProvider();
      final initialTrip = Trip(
        id: 'TRP-883',
        bookingId: 'BK-1082',
        driverId: 'drv_01',
        driverName: 'Amitava Roy',
        driverPhone: '+91 98745 61230',
        vehicleModel: 'Honda City 2023 (Automatic)',
        startLocation: 'Kakdwip Railway Station, WB 743347',
        endLocation: 'Kakdwip Ferry Ghat (Lot 8)',
        startLat: 21.8767,
        startLng: 88.1912,
        endLat: 21.8712,
        endLng: 88.1824,
        fare: 600.0,
        status: TripStatus.onTrip,
        currentProgress: 0.45,
        customerName: 'Rajesh Das',
        customerPhone: '+91 98301 23456',
        startTime: '10:30 AM',
        distanceKm: 8.5,
        otp: '4892',
      );
      provider.setActiveTrip(initialTrip);

      // Switch role to driver to complete trip legitimately per strict RBAC rules
      provider.switchRole(UserRole.driver);
      provider.verifyRideOtpSync(provider.activeTrip!.otp);
      provider.completeTrip();

      // Switch back to customer to view tracking screen
      provider.switchRole(UserRole.customer);
      expect(provider.activeTrip!.status, TripStatus.completed);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: const MaterialApp(
            home: ActiveTripTrackingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Completed Trip Header & Receipt
      expect(find.text('Trip Successfully Completed'), findsOneWidget);
      expect(find.text('Thank you for riding with DriveMate!'), findsOneWidget);
      expect(find.text('JOURNEY RECEIPT'), findsOneWidget);
      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('Back to Home Dashboard'), findsOneWidget);

      // 2. Verify no active live navigation controls are rendered for completed trips
      expect(find.text('ON TRIP TO DESTINATION'), findsNothing);
      expect(find.text('Call Chauffeur'), findsNothing);

      provider.stopDriverLiveTracking();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
