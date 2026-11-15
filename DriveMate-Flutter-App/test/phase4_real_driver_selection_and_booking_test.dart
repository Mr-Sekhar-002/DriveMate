// test/phase4_real_driver_selection_and_booking_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    ApiConfig.activeEnvironment = ApiEnvironment.lan;
    ApiConfig.customBaseUrlOverride = null;
  });

  group('Phase 4: Real Driver Selection & Booking Workflow Unit Tests', () {
    test('1. EligibleDriver.fromJson maps authentic MySQL driver fields without fake ratings', () {
      final json = {
        'id': 9,
        'driver_name': 'Amitava Roy (Chauffeur)',
        'avatar': 'https://drivemate.io/avatars/amitava.jpg',
        'license_number': 'DL-WB96-2019-003412',
        'vehicle_type': 'Sedan/SUV',
        'vehicle_model': 'Hyundai Creta SX',
        'vehicle_number': 'WB-06-B-8910',
        'avg_rating': 4.90,
        'total_trips': 184,
        'experience_years': 6,
        'hourly_rate': 160.00,
        'estimated_fare': 290.00,
        'is_online': true,
        'is_busy': false,
        'is_available': true,
        'verification_status': 'verified',
        'current_lat': 21.8735,
        'current_lng': 88.1855,
        'distance_km': 0.69,
        'eta_minutes': 3,
      };

      final driver = EligibleDriver.fromJson(json);

      expect(driver.id, equals(9));
      expect(driver.name, equals('Amitava Roy (Chauffeur)'));
      expect(driver.avgRating, equals(4.90));
      expect(driver.totalTrips, equals(184));
      expect(driver.experienceYears, equals(6));
      expect(driver.isOnline, isTrue);
      expect(driver.isAvailable, isTrue);
      expect(driver.isBusy, isFalse);
      expect(driver.distanceKm, equals(0.69));
      expect(driver.estimatedFare, equals(290.00));
      expect(driver.verificationStatus, equals('verified'));
    });

    test('2. EligibleDriver preserves null avgRating for unrated drivers without faking 5.0', () {
      final json = {
        'id': 15,
        'driver_name': 'New Chauffeur',
        'avg_rating': null,
        'total_trips': 0,
        'experience_years': 2,
        'is_online': true,
        'is_busy': false,
        'is_available': true,
        'verification_status': 'verified',
      };

      final driver = EligibleDriver.fromJson(json);
      expect(driver.avgRating, isNull);
      expect(driver.totalTrips, equals(0));
    });

    test('3. DriveMateProvider driver selection and sorting filter state transitions', () {
      final provider = DriveMateProvider();

      expect(provider.driverSortFilter, equals('top_rated'));

      provider.setDriverSortFilter('nearest');
      expect(provider.driverSortFilter, equals('nearest'));

      provider.setDriverSortFilter('available_now');
      expect(provider.driverSortFilter, equals('available_now'));

      provider.setDriverSortFilter('experience');
      expect(provider.driverSortFilter, equals('experience'));

      final testDriver = EligibleDriver(
        id: 10,
        name: 'Animesh Barman',
        avgRating: 4.70,
        totalTrips: 96,
        experienceYears: 3,
        hourlyRate: 140.0,
        estimatedFare: 290.0,
      );

      provider.selectDriver(testDriver);
      expect(provider.selectedDriver, isNotNull);
      expect(provider.selectedDriver!.id, equals(10));
      expect(provider.selectedDriver!.name, equals('Animesh Barman'));

      provider.clearSelectedDriver();
      expect(provider.selectedDriver, isNull);
    });

    test('4. bookDriverHiring assigns selected driver ID and never defaults to Driver 3', () async {
      final provider = DriveMateProvider();

      final selectedChauffeur = EligibleDriver(
        id: 9,
        name: 'Amitava Roy (Chauffeur)',
        avgRating: 4.90,
        totalTrips: 184,
        experienceYears: 6,
      );
      provider.selectDriver(selectedChauffeur);

      final booking = await provider.bookDriverHiring(
        hiringType: DriverHiringType.oneWay,
        pickup: 'Kakdwip Station',
        pickupCoords: const LatLng(21.8767, 88.1912),
        destination: 'Lot 8 Ghat',
        destCoords: const LatLng(21.8712, 88.1824),
        distanceKm: 14.8,
        durationMinutes: 28,
        customerCarModel: 'Honda City',
        estimatedFare: 467.0,
      );

      expect(booking.driverId, equals('9'));
      expect(booking.driverName, equals('Amitava Roy (Chauffeur)'));
      expect(booking.driverId, isNot(equals('3')));
      expect(booking.bookingType, equals(BookingType.hireDriver));
      expect(booking.status, equals(BookingStatus.confirmed));
    });

    test('5. createBooking for rentCar has null driverId and confirmed status', () {
      final provider = DriveMateProvider();

      final booking = provider.createBooking(
        bookingType: BookingType.rentCar,
        startDate: '2026-11-01',
        endDate: '2026-11-03',
        pickupLocation: 'Kakdwip Bus Stand',
        destination: 'Self-Drive Coastal Tour',
        totalAmount: 3625.0,
      );

      expect(booking.bookingType, equals(BookingType.rentCar));
      expect(booking.driverId, isNull);
      expect(booking.driverName, isNull);
      expect(booking.status, equals(BookingStatus.confirmed));
    });

    test('6. createBooking for rentCarAndDriver assigns assigned driver correctly', () {
      final provider = DriveMateProvider();

      final driverProf = DriverProfile(
        id: '10',
        userId: 'usr_10',
        driverName: 'Animesh Barman',
        phone: '9811223344',
        licenseNumber: 'DL-WB96-2022-004481',
        experienceYears: 3,
        rating: 4.70,
        totalTrips: 96,
        isOnline: true,
        status: 'verified',
      );

      final booking = provider.createBooking(
        bookingType: BookingType.rentCarAndDriver,
        startDate: '2026-11-01',
        endDate: '2026-11-02',
        pickupLocation: 'Kakdwip Station',
        destination: 'Kolkata City',
        totalAmount: 4500.0,
        driver: driverProf,
      );

      expect(booking.bookingType, equals(BookingType.rentCarAndDriver));
      expect(booking.driverId, equals('10'));
      expect(booking.driverName, equals('Animesh Barman'));
      expect(booking.status, equals(BookingStatus.confirmed));
    });

    test('7. Two-Way Fare Negotiation updates provider state and negotiation status', () {
      final provider = DriveMateProvider();

      final booking = provider.createBooking(
        bookingType: BookingType.hireDriver,
        startDate: 'Immediate',
        endDate: 'One-Way',
        pickupLocation: 'Kakdwip Station',
        destination: 'Lot 8 Ghat',
        totalAmount: 467.0,
      );

      // Customer sends offer
      provider.submitFareOffer(booking.id, 420.0, notes: 'Initial offer');
      final negs1 = provider.getNegotiationsForBooking(booking.id);
      expect(negs1.isNotEmpty, isTrue);
      expect(negs1.last.offeredFare, equals(420.0));
      expect(negs1.last.status, equals(NegotiationStatus.pending));

      // Driver responds with counter-offer
      provider.respondToFareOffer(booking.id, 'counter', counterFare: 450.0);
      final negs2 = provider.getNegotiationsForBooking(booking.id);
      expect(negs2.length, greaterThanOrEqualTo(2));

      // Customer accepts counter-offer
      provider.respondToFareOffer(booking.id, 'accept');
      final updatedBooking = provider.bookings.firstWhere((b) => b.id == booking.id);
      expect(updatedBooking.negotiationStatus, equals('AGREED'));
      expect(updatedBooking.status, equals(BookingStatus.confirmed));
    });
  });

  group('Phase 4: Live PHP & MySQL Integration Verification', () {
    test('8. Live Customer & Two Driver Accounts Authentication', () async {
      final uri = ApiConfig.getUri('/auth/login');

      // Customer login
      final cRes = await http.post(uri,
          headers: ApiConfig.getHeaders(),
          body: jsonEncode({'email': 'customer@drivemate.com', 'password': 'password123'}));
      expect(cRes.statusCode, equals(200));
      final cJson = jsonDecode(cRes.body);
      expect(cJson['data']['user_id'], equals(2));
      expect(cJson['data']['role'], equals('customer'));

      // Driver 1 (Amitava Roy) login
      final d1Res = await http.post(uri,
          headers: ApiConfig.getHeaders(),
          body: jsonEncode({'email': 'amitava.driver@drivemate.com', 'password': 'password123'}));
      expect(d1Res.statusCode, equals(200));
      final d1Json = jsonDecode(d1Res.body);
      expect(d1Json['data']['user_id'], equals(9));
      expect(d1Json['data']['role'], equals('driver'));

      // Driver 2 (Animesh Barman) login
      final d2Res = await http.post(uri,
          headers: ApiConfig.getHeaders(),
          body: jsonEncode({'email': 'animesh.driver@drivemate.com', 'password': 'password123'}));
      expect(d2Res.statusCode, equals(200));
      final d2Json = jsonDecode(d2Res.body);
      expect(d2Json['data']['user_id'], equals(10));
      expect(d2Json['data']['role'], equals('driver'));
    });

    test('9. GET /drivers/eligible returns real MySQL drivers with sorting', () async {
      final loginRes = await http.post(ApiConfig.getUri('/auth/login'),
          headers: ApiConfig.getHeaders(),
          body: jsonEncode({'email': 'customer@drivemate.com', 'password': 'password123'}));
      final token = jsonDecode(loginRes.body)['data']['token'];

      final res = await http.get(
        ApiConfig.getUri('/drivers/eligible', {'lat': '21.8767', 'lng': '88.1912', 'sort': 'top_rated'}),
        headers: ApiConfig.getHeaders(token: token),
      );

      expect(res.statusCode, equals(200));
      final body = jsonDecode(res.body);
      expect(body['success'], isTrue);
      final driversList = body['data'] as List;
      expect(driversList.isNotEmpty, isTrue);

      final driverIds = driversList.map((d) => d['id']).toList();
      expect(driverIds, contains(9));
      expect(driverIds, contains(10));
    });

    test('10. Double Booking Prevention strictly rejects overlapping booking', () async {
      final loginRes = await http.post(ApiConfig.getUri('/auth/login'),
          headers: ApiConfig.getHeaders(),
          body: jsonEncode({'email': 'customer@drivemate.com', 'password': 'password123'}));
      final token = jsonDecode(loginRes.body)['data']['token'];

      // Ensure Driver 9 has an active confirmed booking
      final d1Login = await http.post(ApiConfig.getUri('/auth/login'),
          headers: ApiConfig.getHeaders(),
          body: jsonEncode({'email': 'amitava.driver@drivemate.com', 'password': 'password123'}));
      final d1Token = jsonDecode(d1Login.body)['data']['token'];

      final initialBook = await http.post(
        ApiConfig.getUri('/driver-hiring/booking'),
        headers: ApiConfig.getHeaders(token: token),
        body: jsonEncode({
          'driver_id': 9,
          'pickup_location': 'Kakdwip Station',
          'destination': 'Lot 8 Ghat',
          'hiring_type': 'one_way',
          'customer_car_model': 'Swift',
          'distance_km': 14.8,
        }),
      );
      int? initialBookingId;
      if (initialBook.statusCode == 200 || initialBook.statusCode == 201) {
        initialBookingId = jsonDecode(initialBook.body)['data']['booking_id'];
        await http.post(
          ApiConfig.getUri('/negotiation/respond'),
          headers: ApiConfig.getHeaders(token: d1Token),
          body: jsonEncode({'booking_id': initialBookingId, 'action': 'accept'}),
        );
      }

      // Now attempt to double-book Driver 9 while engaged in confirmed booking
      final doubleRes = await http.post(
        ApiConfig.getUri('/driver-hiring/booking'),
        headers: ApiConfig.getHeaders(token: token),
        body: jsonEncode({
          'driver_id': 9,
          'pickup_location': 'Kakdwip Station',
          'destination': 'Lot 8 Ghat',
          'hiring_type': 'one_way',
          'customer_car_model': 'Swift',
          'distance_km': 14.8,
        }),
      );

      expect(doubleRes.statusCode, equals(409));
      final body = jsonDecode(doubleRes.body);
      expect(body['success'], isFalse);
      expect(body['message'], contains('active trip or booking'));

      // Clean up if initial booking was created
      if (initialBookingId != null) {
        await http.put(
          ApiConfig.getUri('/bookings/cancel'),
          headers: ApiConfig.getHeaders(token: token),
          body: jsonEncode({'booking_id': initialBookingId}),
        );
      }
    });

    test('11. BOLA / IDOR Protection rejects unauthorized driver access to booking', () async {
      // Driver 9 logs in
      final d1Login = await http.post(ApiConfig.getUri('/auth/login'),
          headers: ApiConfig.getHeaders(),
          body: jsonEncode({'email': 'amitava.driver@drivemate.com', 'password': 'password123'}));
      final d1Token = jsonDecode(d1Login.body)['data']['token'];

      // Driver 9 attempts to access booking 58 (assigned to Driver 10)
      final accessRes = await http.get(
        ApiConfig.getUri('/bookings/detail', {'id': '58'}),
        headers: ApiConfig.getHeaders(token: d1Token),
      );

      expect(accessRes.statusCode, equals(403));
      final body = jsonDecode(accessRes.body);
      expect(body['success'], isFalse);
      expect(body['message'], contains('Forbidden'));
    });
  });
}
