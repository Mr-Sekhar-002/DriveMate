import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/customer/smart_booking_flow_screen.dart';
import 'package:drivemate_flutter/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1: Smart Booking System Tests', () {
    testWidgets('1. SmartBookingFlowScreen renders 4 core services and duration packages', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SmartBookingFlowScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Header title and status
      expect(find.text('Smart Booking System'), findsOneWidget);
      expect(find.text('Instant Lock'), findsOneWidget);

      // 4 Core Services
      expect(find.text('Hire Driver'), findsOneWidget);
      expect(find.text('Self-Drive'), findsOneWidget);
      expect(find.text('Car + Driver'), findsOneWidget);
      expect(find.text('Outstation'), findsOneWidget);

      // Booking Duration Chips
      expect(find.text('Hourly'), findsOneWidget);
      expect(find.text('Half-Day (4h)'), findsOneWidget);
      expect(find.text('Full-Day (8h)'), findsOneWidget);
      expect(find.text('Daily Rental'), findsOneWidget);
      expect(find.text('Outstation Trip'), findsOneWidget);

      // Confirm Button
      expect(find.text('Confirm Booking & Generate ID'), findsOneWidget);
    });

    testWidgets('2. Switching service updates fare breakdown and vehicle selection', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SmartBookingFlowScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially on Hire Driver: car model textfield is shown
      expect(find.text('Your Car Model'), findsOneWidget);

      // Switch to Outstation service
      await tester.tap(find.text('Outstation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Outstation specific fare line item appears
      expect(find.text('Inter-State Permit & Surcharge'), findsOneWidget);

      // Switch to Self-Drive (Rent a Car)
      await tester.tap(find.text('Self-Drive'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Vehicle fleet selection appears
      expect(find.text('Select Fleet Vehicle'), findsOneWidget);
    });

    testWidgets('3. Confirming booking generates booking and triggers success modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = DriveMateProvider();
      addTearDown(() => provider.dispose());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SmartBookingFlowScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Confirm Booking
      final confirmBtn = find.text('Confirm Booking & Generate ID');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal bottom sheet should appear with Confirmation and OTP
      expect(find.text('Booking Confirmed!'), findsOneWidget);
      expect(find.textContaining('Booking ID:'), findsOneWidget);
      expect(find.text('Ride Start OTP'), findsOneWidget);
      expect(find.text('Track Live'), findsOneWidget);
      expect(find.text('My Bookings'), findsOneWidget);

      provider.stopDriverLiveTracking();
    });

    testWidgets('4. Outstation booking type model serialization and deserialization', (tester) async {
      final json = {
        'id': 99,
        'booking_reference': 'DM-BK-20261112-0099',
        'type': 'outstation',
        'hiring_type': 'outstation',
        'start_date': '2026-11-20 08:00:00',
        'end_date': '2026-11-20 20:00:00',
        'pickup_location': 'Kolkata Airport',
        'destination': 'Digha Beach',
        'total_amount': '3200.00',
        'status': 'confirmed',
        'start_otp': '7821',
      };

      final booking = Booking.fromJson(json);

      expect(booking.id, 'BK-99');
      expect(booking.bookingReference, 'DM-BK-20261112-0099');
      expect(booking.bookingType, BookingType.outstation);
      expect(booking.totalAmount, 3200.0);
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.startOtp, '7821');
    });
  });
}
