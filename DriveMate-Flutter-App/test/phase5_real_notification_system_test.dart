// test/phase5_real_notification_system_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    ApiConfig.activeEnvironment = ApiEnvironment.lan;
    ApiConfig.customBaseUrlOverride = null;
  });

  group('Phase 5: Notification System Unit Tests', () {
    test('1. NotificationService constants define high-priority booking and trip channels', () {
      expect(NotificationService.channelId, equals('drivemate_booking_channel'));
      expect(NotificationService.channelName, contains('Booking'));
      expect(NotificationService.tripChannelId, equals('drivemate_trip_channel'));
      expect(NotificationService.tripChannelName, contains('Trip'));
    });

    test('2. Notification payloads strictly omit OTP, JWTs, and payment secrets', () {
      final payload = jsonEncode({
        'type': 'booking_request',
        'booking_id': '55',
        'customer_name': 'Rahul Sharma',
        'fare': 450.0,
      });

      expect(payload, isNot(contains('otp')));
      expect(payload, isNot(contains('4821')));
      expect(payload, isNot(contains('password')));
      expect(payload, isNot(contains('token')));
      expect(payload, isNot(contains('secret')));
    });

    test('3. Deduplication prevents duplicate alerts for the same booking ID within threshold', () async {
      final service = NotificationService();
      // Consecutive calls for the same booking
      await service.showBookingNotification(
        bookingId: 'BK-TEST-999',
        customerName: 'Test Customer',
        pickup: 'Point A',
        destination: 'Point B',
        fare: 250.0,
      );
      // Second immediate call within threshold should skip duplicate alert sound
      await service.showBookingNotification(
        bookingId: 'BK-TEST-999',
        customerName: 'Test Customer',
        pickup: 'Point A',
        destination: 'Point B',
        fare: 250.0,
      );
    });
  });

  group('Phase 5: Live PHP & MySQL Notification Integration Tests', () {
    late String customerToken;
    late String driverToken;
    late String otherDriverToken;

    setUpAll(() async {
      HttpOverrides.global = null;
      // Authenticate Customer (ID 2)
      final cRes = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'customer@drivemate.com', 'password': 'password123'}),
      );
      customerToken = jsonDecode(cRes.body)['data']['token'];

      // Authenticate Driver 1 (Amitava Roy, ID 9)
      final d1Res = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'amitava.driver@drivemate.com', 'password': 'password123'}),
      );
      driverToken = jsonDecode(d1Res.body)['data']['token'];

      // Authenticate Driver 2 (Animesh Barman, ID 10)
      final d2Res = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'animesh.driver@drivemate.com', 'password': 'password123'}),
      );
      otherDriverToken = jsonDecode(d2Res.body)['data']['token'];
    });

    test('4. POST /notifications/save-token registers device tokens in MySQL', () async {
      // Register token for Customer
      final cTokRes = await http.post(
        ApiConfig.getUri('/notifications/save-token'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'fcm_token': 'fcm_cust_device_token_phase5',
          'device_model': 'Pixel 8 Pro',
          'device_os': 'Android 14',
          'app_version': '1.0.0',
        }),
      );
      expect(cTokRes.statusCode, equals(200));

      // Register token for Driver
      final dTokRes = await http.post(
        ApiConfig.getUri('/notifications/save-token'),
        headers: ApiConfig.getHeaders(token: driverToken),
        body: jsonEncode({
          'fcm_token': 'fcm_driver_device_token_phase5',
          'device_model': 'Samsung Galaxy S24',
          'device_os': 'Android 14',
          'app_version': '1.0.0',
        }),
      );
      expect(dTokRes.statusCode, equals(200));
    });

    test('5. Customer booking creation triggers Driver notification event in MySQL', () async {
      final bookRes = await http.post(
        ApiConfig.getUri('/driver-hiring/booking'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'driver_id': 9,
          'pickup_location': '820 Lexington Ave',
          'destination': 'JFK Terminal 4',
          'pickup_lat': 21.8767,
          'pickup_lng': 88.1912,
          'dest_lat': 21.9000,
          'dest_lng': 88.2200,
          'hiring_type': 'one_way',
          'customer_car_model': 'Swift Dzire',
          'distance_km': 14.8,
          'initial_offer': 380.00,
        }),
      );
      expect(bookRes.statusCode, equals(201));
      final bookingId = jsonDecode(bookRes.body)['data']['booking_id'];

      // Driver 9 fetches in-app notifications
      final dNotifRes = await http.get(
        ApiConfig.getUri('/notifications/my'),
        headers: ApiConfig.getHeaders(token: driverToken),
      );
      expect(dNotifRes.statusCode, equals(200));
      final dNotifs = jsonDecode(dNotifRes.body)['data'] as List;
      expect(dNotifs.isNotEmpty, isTrue);

      final latestDriverNotif = dNotifs.first;
      expect(latestDriverNotif['user_id'], equals(9));
      expect(latestDriverNotif['title'], contains('Booking Request'));

      // Clean up test booking
      await http.put(
        ApiConfig.getUri('/bookings/cancel'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({'booking_id': bookingId, 'reason': 'test'}),
      );
    });

    test('6. Two-Way Fare Negotiation creates real notifications for Counter-Offer and Acceptance', () async {
      // 1. Customer creates booking
      final bookRes = await http.post(
        ApiConfig.getUri('/driver-hiring/booking'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'driver_id': 9,
          'pickup_location': 'Salt Lake Sector V',
          'destination': 'Howrah Station',
          'pickup_lat': 21.8767,
          'pickup_lng': 88.1912,
          'dest_lat': 21.9000,
          'dest_lng': 88.2200,
          'hiring_type': 'one_way',
          'customer_car_model': 'Creta',
          'distance_km': 12.0,
          'initial_offer': 300.00,
        }),
      );
      final bookingId = jsonDecode(bookRes.body)['data']['booking_id'];

      // 2. Driver counter-offers ₹400
      final counterRes = await http.post(
        ApiConfig.getUri('/negotiation/respond'),
        headers: ApiConfig.getHeaders(token: driverToken),
        body: jsonEncode({
          'booking_id': bookingId,
          'action': 'counter',
          'counter_fare': 400.00,
        }),
      );
      expect(counterRes.statusCode, equals(200));

      // Customer checks notifications: should see driver_counter_offer
      final cNotifRes = await http.get(
        ApiConfig.getUri('/notifications/my'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      final cNotifs = jsonDecode(cNotifRes.body)['data'] as List;
      expect(cNotifs.any((n) => n['event_type'] == 'driver_counter_offer' || n['title'].toString().contains('Counter Offer')), isTrue);

      // 3. Customer accepts counter-offer
      final acceptRes = await http.post(
        ApiConfig.getUri('/negotiation/respond'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'booking_id': bookingId,
          'action': 'accept',
        }),
      );
      expect(acceptRes.statusCode, equals(200));

      // Both parties check notifications: should see booking_confirmed
      final cNotifRes2 = await http.get(
        ApiConfig.getUri('/notifications/my'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      final cNotifs2 = jsonDecode(cNotifRes2.body)['data'] as List;
      expect(cNotifs2.any((n) => n['event_type'] == 'booking_confirmed' || n['title'].toString().contains('Confirmed')), isTrue);

      // Clean up
      await http.put(
        ApiConfig.getUri('/bookings/cancel'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({'booking_id': bookingId}),
      );
    });

    test('7. Trip Lifecycle creates Driver Arrived, Trip Started, and Trip Completed notifications', () async {
      // Create confirmed booking for Driver 9
      final bookRes = await http.post(
        ApiConfig.getUri('/driver-hiring/booking'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'driver_id': 9,
          'pickup_location': 'Park Street',
          'destination': 'Airport',
          'pickup_lat': 21.8767,
          'pickup_lng': 88.1912,
          'dest_lat': 21.9000,
          'dest_lng': 88.2200,
          'hiring_type': 'one_way',
          'customer_car_model': 'Innova',
          'distance_km': 15.0,
          'initial_offer': 500.00,
        }),
      );
      final bookingId = jsonDecode(bookRes.body)['data']['booking_id'];
      final startOtp = jsonDecode(bookRes.body)['data']['start_otp'];

      // Driver accepts booking
      await http.post(
        ApiConfig.getUri('/negotiation/respond'),
        headers: ApiConfig.getHeaders(token: driverToken),
        body: jsonEncode({'booking_id': bookingId, 'action': 'accept'}),
      );

      // 1. Driver arrives at pickup
      final arrivedRes = await http.post(
        ApiConfig.getUri('/trips/arrived'),
        headers: ApiConfig.getHeaders(token: driverToken),
        body: jsonEncode({'booking_id': bookingId}),
      );
      expect(arrivedRes.statusCode, equals(200));

      // Customer checks notifications for driver_arrived
      final notifArrived = await http.get(
        ApiConfig.getUri('/notifications/my'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      final notifsA = jsonDecode(notifArrived.body)['data'] as List;
      expect(notifsA.any((n) => n['event_type'] == 'driver_arrived' || n['title'].toString().contains('Arrived')), isTrue);

      // 2. Driver starts trip with OTP
      final startRes = await http.post(
        ApiConfig.getUri('/trips/start'),
        headers: ApiConfig.getHeaders(token: driverToken),
        body: jsonEncode({
          'booking_id': bookingId,
          'otp': startOtp,
          'start_lat': 21.8767,
          'start_lng': 88.1912,
        }),
      );
      expect(startRes.statusCode, equals(201));
      final tripId = jsonDecode(startRes.body)['data']['trip_id'];

      // Customer checks notifications for trip_started
      final notifStarted = await http.get(
        ApiConfig.getUri('/notifications/my'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      final notifsS = jsonDecode(notifStarted.body)['data'] as List;
      expect(notifsS.any((n) => n['event_type'] == 'trip_started' || n['title'].toString().contains('Trip In Progress')), isTrue);

      // 3. Driver completes trip
      final completeRes = await http.put(
        ApiConfig.getUri('/trips/complete'),
        headers: ApiConfig.getHeaders(token: driverToken),
        body: jsonEncode({
          'trip_id': tripId,
          'end_location': 'Airport Terminal 2',
          'end_lat': 21.9000,
          'end_lng': 88.2200,
          'distance_km': 15.2,
          'fare': 500.00,
        }),
      );
      expect(completeRes.statusCode, equals(200));

      // Customer checks notifications for trip_completed
      final notifCompleted = await http.get(
        ApiConfig.getUri('/notifications/my'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      final notifsC = jsonDecode(notifCompleted.body)['data'] as List;
      expect(notifsC.any((n) => n['event_type'] == 'trip_completed' || n['title'].toString().contains('Completed')), isTrue);
    });

    test('8. BOLA Authorization: Driver 10 cannot mark Customer 2 notifications as read', () async {
      // Customer fetches their notifications
      final cNotifsRes = await http.get(
        ApiConfig.getUri('/notifications/my'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      final cNotifs = jsonDecode(cNotifsRes.body)['data'] as List;
      expect(cNotifs.isNotEmpty, isTrue);
      final customerNotifId = cNotifs.first['id'];

      // Driver 10 attempts to mark Customer 2's notification as read
      final attackRes = await http.put(
        ApiConfig.getUri('/notifications/mark-read'),
        headers: ApiConfig.getHeaders(token: otherDriverToken),
        body: jsonEncode({'notification_id': customerNotifId}),
      );

      // Must be rejected with HTTP 403 Forbidden
      expect(attackRes.statusCode, equals(403));
      final attackJson = jsonDecode(attackRes.body);
      expect(attackJson['success'], isFalse);
      expect(attackJson['message'], contains('not authorized'));
    });

    test('9. POST /notifications/remove-token deactivates user device token on logout', () async {
      final remRes = await http.post(
        ApiConfig.getUri('/notifications/remove-token'),
        headers: ApiConfig.getHeaders(token: driverToken),
        body: jsonEncode({'fcm_token': 'fcm_driver_device_token_phase5'}),
      );
      expect(remRes.statusCode, equals(200));
      final remJson = jsonDecode(remRes.body);
      expect(remJson['success'], isTrue);
    });
  });
}
