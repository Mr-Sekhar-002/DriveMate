import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/components/live_trip_map_card.dart';
import 'package:drivemate_flutter/screens/driver/driver_dashboard_screen.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Driver Profile Map Section Redesign Tests', () {
    testWidgets('1. New driver experience / Idle mode: renders dark navy live map with radar waiting message', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LiveTripMapCard(
                trip: null,
                booking: null,
                isOnline: true,
                onSimulateStep: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header radar badge
      expect(find.text('DRIVER LIVE GPS RADAR'), findsOneWidget);

      // Status text for idle/new driver (strict prompt requirement: "Waiting for Booking")
      expect(find.text('Waiting for Booking'), findsOneWidget);

      // OpenStreetMap contributors attribution
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      // Small floating map controls: Zoom In (+), Zoom Out (-), GPS My Location
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);

      // Verify no fake customer or trip details
      expect(find.text('TRIP COMPLETED SUCCESSFULLY'), findsNothing);
      expect(find.text('ACTIVE TRIP NAVIGATION'), findsNothing);
      expect(find.text('Fake Customer'), findsNothing);
    });

    testWidgets('2. Active booking experience: renders active navigation with customer info, pickup & destination', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final activeTrip = Trip(
        id: 'TRP-101',
        bookingId: 'BK-999',
        driverId: 'drv_01',
        driverName: 'Subhasish Ghosh',
        driverPhone: '+919830111222',
        vehicleModel: 'Hyundai Creta',
        startLocation: 'Kolkata Airport Gate 1',
        endLocation: 'Park Street Metro Station',
        startLat: 22.5800,
        startLng: 88.4200,
        endLat: 22.5850,
        endLng: 88.4250,
        fare: 650.0,
        status: TripStatus.assigned,
        currentProgress: 0.2,
        customerName: 'Ayan Banerjee',
        customerPhone: '+919876543210',
        startTime: '10:30 AM',
        distanceKm: 18.5,
      );

      final activeBooking = Booking(
        id: 'BK-999',
        userId: 'cust_01',
        userName: 'Ayan Banerjee',
        pickupLocation: 'Kolkata Airport Gate 1',
        destination: 'Park Street Metro Station',
        bookingType: BookingType.hireDriver,
        startDate: '2026-10-31 10:30',
        endDate: '2026-10-31 12:30',
        totalAmount: 650.0,
        status: BookingStatus.confirmed,
        customerCarModel: 'Hyundai Creta',
        customerPhone: '+919876543210',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LiveTripMapCard(
                trip: activeTrip,
                booking: activeBooking,
                isOnline: true,
                onSimulateStep: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header indicates active trip
      expect(find.text('ACTIVE TRIP NAVIGATION'), findsOneWidget);

      // Customer name and vehicle information from backend
      expect(find.text('Ayan Banerjee'), findsOneWidget);
      expect(find.text('Hyundai Creta • ₹650'), findsOneWidget);

      // Pickup instruction
      expect(find.textContaining('Going to Pickup: Kolkata Airport Gate 1'), findsOneWidget);

      // Map attribution
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      // Pickup & Destination markers
      expect(find.text('PICKUP'), findsOneWidget);
      expect(find.text('DESTINATION'), findsOneWidget);
    });

    testWidgets('3. Completed trip experience: shows receipt summary and Ready for Next Booking button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool dismissed = false;

      final completedTrip = Trip(
        id: 'TRP-102',
        bookingId: 'BK-888',
        driverId: 'drv_01',
        driverName: 'Subhasish Ghosh',
        driverPhone: '+919830111222',
        vehicleModel: 'Maruti Suzuki Ertiga',
        startLocation: 'Howrah Railway Station',
        endLocation: 'Salt Lake Sector V',
        fare: 480.0,
        status: TripStatus.completed,
        customerName: 'Priyanka Sen',
        customerPhone: '+919830012345',
        startTime: '08:00 AM',
        distanceKm: 14.2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LiveTripMapCard(
                trip: completedTrip,
                booking: null,
                isOnline: true,
                onSimulateStep: () {},
                onDismissCompleted: () {
                  dismissed = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Completed trip card header
      expect(find.text('TRIP COMPLETED SUCCESSFULLY'), findsOneWidget);
      expect(find.text('Fare credited to your driver wallet balance'), findsOneWidget);

      // Receipt details
      expect(find.text('Priyanka Sen'), findsOneWidget);
      expect(find.text('Maruti Suzuki Ertiga'), findsOneWidget);
      expect(find.text('Howrah Railway Station'), findsOneWidget);
      expect(find.text('Salt Lake Sector V'), findsOneWidget);
      expect(find.text('₹480'), findsOneWidget);

      // Ready for Next Booking button
      final readyButton = find.text('Ready for Next Booking • Back to Radar');
      expect(readyButton, findsOneWidget);

      await tester.tap(readyButton);
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('4. Driver dashboard integration: new driver with no active booking renders radar map', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = DriveMateProvider();
      provider.register(
        name: 'New Driver',
        email: 'newdriver@test.com',
        phone: '+919876543299',
        role: UserRole.driver,
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

      // Must find the redesigned live map radar section
      expect(find.text('DRIVER LIVE GPS RADAR'), findsOneWidget);
      expect(find.text('Waiting for Booking'), findsOneWidget);
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);

      // Drain toast timer
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
