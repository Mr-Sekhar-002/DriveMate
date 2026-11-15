import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/main.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';

void main() {
  testWidgets('DriveMate Auth, Login, and Service flows smoke test', (WidgetTester tester) async {
    // Set a realistic mobile screen size for testing
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DriveMateProvider()),
        ],
        child: const DriveMateApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AuthScreen is shown initially with updated India branding & redesigned logo
    expect(find.text('Your Car. Your Driver. Pan-India Mobility.'), findsOneWidget);
    expect(find.text('Password Login'), findsOneWidget);
    expect(find.text('SMS OTP Login'), findsOneWidget);

    // Verify toggling SMS OTP login mode and Password login mode
    await tester.tap(find.text('SMS OTP Login'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Send SMS OTP'), findsOneWidget);

    await tester.tap(find.text('Password Login'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In as Customer'), findsOneWidget);

    // Tap Sign In to enter Customer Home
    await tester.tap(find.text('Sign In as Customer'));
    await tester.pumpAndSettle();

    // Verify Customer Home Screen is rendered
    expect(find.text('What do you need?'), findsOneWidget);
    expect(find.text('Hire a Driver'), findsWidgets);
    expect(find.text('Rent a Car'), findsWidgets);
    expect(find.text('Rent Car + Driver'), findsWidgets);

    // Tap Hire a Driver card
    final hireDriverCard = find.text('Hire a Driver').last;
    await tester.ensureVisible(hireDriverCard);
    await tester.tap(hireDriverCard);
    await tester.pumpAndSettle();

    // In Driver Selection Screen, proceed to hiring flow
    if (find.text('Continue Anyway').evaluate().isNotEmpty) {
      await tester.tap(find.text('Continue Anyway'));
      await tester.pumpAndSettle();
    } else if (find.text('Select Driver').evaluate().isNotEmpty) {
      await tester.tap(find.text('Select Driver').first);
      await tester.pumpAndSettle();
    }

    expect(find.text('PHASE 19: DRIVER HIRING ENGINE'), findsOneWidget);
    expect(find.text('Negotiate Fare'), findsOneWidget);
    expect(find.textContaining('Book ₹'), findsOneWidget);

    // Tap Negotiate Fare to open bottom sheet
    await tester.tap(find.text('Negotiate Fare'));
    await tester.pumpAndSettle();
    expect(find.text('Two-Way Fare Negotiation'), findsOneWidget);
    expect(find.textContaining('Submit Offer of ₹'), findsOneWidget);
  });

  test('DriveMateProvider state management unit test', () {
    final provider = DriveMateProvider();

    expect(provider.isLoggedIn, false);
    expect(provider.currentRole, UserRole.customer);

    provider.login('rajesh.das@drivemate.in', UserRole.customer);
    expect(provider.isLoggedIn, true);
    expect(provider.currentUser.name, 'Rajesh Das');

    // Test role switching
    provider.switchRole(UserRole.driver);
    expect(provider.currentRole, UserRole.driver);
    expect(provider.driverProfile.driverName, 'Amitava Roy');

    // Test booking creation
    provider.switchRole(UserRole.customer);
    final booking = provider.createBooking(
      bookingType: BookingType.hireDriver,
      startDate: 'Today',
      endDate: '4 Hours',
      pickupLocation: 'Kakdwip Railway Station, WB 743347',
      destination: 'Kakdwip Ferry Ghat (Lot 8)',
      totalAmount: 600.0,
      customerCarModel: 'Honda City',
    );

    expect(provider.bookings.first.id, booking.id);
    expect(provider.activeTrip != null, true);

    // Test trip progress simulation (Driver only)
    provider.switchRole(UserRole.driver);
    final initialProgress = provider.activeTrip!.currentProgress;
    provider.simulateTripStep();
    expect(provider.activeTrip!.currentProgress >= initialProgress, true);
  });

  test('Two-Way Fare Negotiation unit test', () {
    final provider = DriveMateProvider();
    provider.login('rajesh.das@drivemate.in', UserRole.customer);

    // Customer submits offer of ₹450
    provider.submitFareOffer('BK-TEST-1', 450.0, notes: 'Kakdwip Station pickup offer');
    expect(provider.getNegotiationsForBooking('BK-TEST-1').length, 1);
    expect(provider.getNegotiationsForBooking('BK-TEST-1').first.offeredFare, 450.0);
    expect(provider.getNegotiationsForBooking('BK-TEST-1').first.status, NegotiationStatus.pending);

    // Driver counters with ₹500
    provider.switchRole(UserRole.driver);
    provider.respondToFareOffer('BK-TEST-1', 'counter', counterFare: 500.0, notes: 'Heavy traffic');
    expect(provider.getNegotiationsForBooking('BK-TEST-1').length, 2);
    expect(provider.getNegotiationsForBooking('BK-TEST-1').last.offeredFare, 500.0);

    // Customer accepts the ₹500 counteroffer
    provider.switchRole(UserRole.customer);
    provider.respondToFareOffer('BK-TEST-1', 'accept');
    expect(provider.getNegotiationsForBooking('BK-TEST-1').last.status, NegotiationStatus.accepted);
  });

  test('Driver Dashboard complete operational lifecycle unit test', () async {
    final provider = DriveMateProvider();
    provider.login('amitava.driver@drivemate.in', UserRole.driver);

    expect(provider.currentRole, UserRole.driver);
    expect(provider.driverProfile.driverName, 'Amitava Roy');

    // 1. Booking Request: Incoming request creation
    final testBooking = Booking(
      id: 'BK-TEST-DRV',
      userId: 'usr_cust_001',
      userName: 'Rajesh Das',
      driverId: 'drv_01',
      bookingType: BookingType.hireDriver,
      startDate: 'Today',
      endDate: '4 Hours',
      pickupLocation: 'Kakdwip Railway Station, WB 743347',
      destination: 'Kakdwip Ferry Ghat (Lot 8)',
      totalAmount: 600.0,
      status: BookingStatus.pending,
      startOtp: '6194',
    );

    // Accept booking
    provider.acceptDriverRequest(testBooking);
    expect(provider.activeTrip != null, true);
    expect(provider.activeTrip!.status, TripStatus.assigned);
    expect(provider.isOtpVerified, false);

    // 2. Pickup Management: Mark driver arrived
    await provider.markDriverArrived();
    expect(provider.activeTrip!.status, TripStatus.driverArrived);
    expect(provider.isOtpVerified, false);

    // 3. Trip Management: Attempt start before OTP -> fails
    final startBeforeOtp = provider.startTrip();
    expect(startBeforeOtp, false);
    expect(provider.activeTrip!.status, TripStatus.driverArrived);

    // Invalid OTP verification -> fails
    final invalidOtp = provider.verifyRideOtpSync('0000');
    expect(invalidOtp, false);
    expect(provider.isOtpVerified, false);

    // Master OTP 4821 bypass rejection -> fails
    final masterOtpBypass = provider.verifyRideOtpSync('4821');
    expect(masterOtpBypass, false);
    expect(provider.isOtpVerified, false);

    // Valid booking-specific OTP verification -> succeeds
    final validOtp = provider.verifyRideOtpSync('6194');
    expect(validOtp, true);
    expect(provider.isOtpVerified, true);

    // Start trip now succeeds
    final startSuccess = provider.startTrip();
    expect(startSuccess, true);
    expect(provider.activeTrip!.status, TripStatus.onTrip);

    // Complete trip
    final initialEarnings = provider.driverProfile.earningsToday;
    provider.completeTrip();
    expect(provider.activeTrip!.status, TripStatus.completed);
    expect(provider.driverProfile.earningsToday, initialEarnings + 600.0);
  });

  test('Phase 19: Location-based fare estimation and driver-only hiring negotiation unit test', () async {
    final provider = DriveMateProvider();
    provider.login('rajesh.das@drivemate.in', UserRole.customer);

    // 1. One-way fare estimation
    final oneWayEstimate = await provider.calculateDriverHiringEstimate(
      pickup: 'Kakdwip Railway Station, WB 743347',
      destination: 'Kakdwip Ferry Ghat (Lot 8)',
      hiringType: DriverHiringType.oneWay,
      distanceKm: 14.8,
      durationMinutes: 28,
    );

    expect(oneWayEstimate.hiringType, 'one_way');
    expect(oneWayEstimate.distanceKm, 14.8);
    expect(oneWayEstimate.durationMinutes, 28);
    expect(oneWayEstimate.baseCharge, 150.0);
    expect(oneWayEstimate.estimatedFare > 400.0, true);
    expect(oneWayEstimate.minSuggestedOffer < oneWayEstimate.estimatedFare, true);
    expect(oneWayEstimate.maxSuggestedOffer > oneWayEstimate.estimatedFare, true);

    // 2. Round-trip estimation
    final roundTripEstimate = await provider.calculateDriverHiringEstimate(
      pickup: 'Kakdwip Railway Station, WB 743347',
      destination: 'Kakdwip Ferry Ghat (Lot 8)',
      hiringType: DriverHiringType.roundTrip,
      distanceKm: 14.8,
      durationMinutes: 28,
    );
    expect(roundTripEstimate.hiringType, 'round_trip');
    expect(roundTripEstimate.estimatedFare > oneWayEstimate.estimatedFare, true);

    // 3. Hourly & Full-Day estimation
    final hourlyEstimate = await provider.calculateDriverHiringEstimate(
      pickup: 'Kakdwip Railway Station, WB 743347',
      destination: 'Kakdwip Market',
      hiringType: DriverHiringType.hourly,
      hours: 4,
      distanceKm: 5.0,
      durationMinutes: 15,
    );
    expect(hourlyEstimate.hiringType, 'hourly');
    expect(hourlyEstimate.estimatedFare >= 700.0, true);

    final fullDayEstimate = await provider.calculateDriverHiringEstimate(
      pickup: 'Kakdwip Railway Station, WB 743347',
      destination: 'Kolkata Airport (CCU)',
      hiringType: DriverHiringType.fullDay,
      distanceKm: 95.0,
      durationMinutes: 180,
    );
    expect(fullDayEstimate.hiringType, 'full_day');
    expect(fullDayEstimate.estimatedFare >= 1350.0, true);

    // 4. Customer books driver hiring with negotiation offer
    final booked = await provider.bookDriverHiring(
      hiringType: DriverHiringType.oneWay,
      pickup: 'Kakdwip Railway Station, WB 743347',
      pickupCoords: const LatLng(21.8767, 88.1912),
      destination: 'Kakdwip Ferry Ghat (Lot 8)',
      destCoords: const LatLng(21.8712, 88.1824),
      distanceKm: 14.8,
      durationMinutes: 28,
      customerCarModel: 'Honda City (Automatic)',
      estimatedFare: oneWayEstimate.estimatedFare,
      initialOffer: 420.0,
      notes: 'Platform 1 pickup',
    );

    expect(booked.bookingType, BookingType.hireDriver);
    expect(booked.hiringType, DriverHiringType.oneWay);
    expect(booked.negotiationStatus, 'PENDING');
    expect(booked.status, BookingStatus.pending);
    expect(booked.negotiatedFare, 420.0);

    // 5. Driver counters the offer
    provider.switchRole(UserRole.driver);
    provider.respondToFareOffer(booked.id, 'counter', counterFare: 460.0, notes: 'Includes luggage help');
    final negs = provider.getNegotiationsForBooking(booked.id);
    expect(negs.length, 2);
    expect(negs.last.offeredFare, 460.0);

    // 6. Customer accepts the counter offer
    provider.switchRole(UserRole.customer);
    provider.respondToFareOffer(booked.id, 'accept');

    final finalBooking = provider.bookings.firstWhere((b) => b.id == booked.id);
    expect(finalBooking.negotiationStatus, 'AGREED');
    expect(finalBooking.status, BookingStatus.confirmed);
    expect(finalBooking.totalAmount, 460.0);
    expect(finalBooking.negotiatedFare, 460.0);

    // 7. Verify existing Car Rental booking flow remains unaffected
    final carRentalBooking = provider.createBooking(
      bookingType: BookingType.rentCar,
      startDate: 'Tomorrow',
      endDate: '2 Days',
      pickupLocation: 'Downtown Central Hub',
      destination: 'Self-Drive Coastal Tour',
      totalAmount: 3200.0,
      carListing: provider.carListings.first,
    );
    expect(carRentalBooking.bookingType, BookingType.rentCar);
    expect(carRentalBooking.hiringType, isNull);
    expect(carRentalBooking.status, BookingStatus.confirmed);
  });
}
