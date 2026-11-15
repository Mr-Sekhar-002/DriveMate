// test/phase7_final_integration_and_admin_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivemate_flutter/config/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    ApiConfig.activeEnvironment = ApiEnvironment.lan;
    ApiConfig.customBaseUrlOverride = null;
  });

  group('Phase 7: Full End-to-End System & Admin Integration Tests', () {
    late String customerToken;
    late String driverToken;
    late String otherDriverToken;
    late String adminToken;

    setUpAll(() async {
      HttpOverrides.global = null;

      // Clean up any uncompleted dangling test bookings in MySQL for test customer
      final cancelClean = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'customer@drivemate.com', 'password': 'password123'}),
      );
      if (cancelClean.statusCode == 200) {
        final tempTok = jsonDecode(cancelClean.body)['data']['token'];
        final myBookingsRes = await http.get(
          ApiConfig.getUri('/bookings/my'),
          headers: ApiConfig.getHeaders(token: tempTok),
        );
        if (myBookingsRes.statusCode == 200) {
          final list = jsonDecode(myBookingsRes.body)['data'] as List;
          for (final b in list) {
            if (['pending', 'confirmed', 'arrived'].contains(b['status'])) {
              await http.put(
                ApiConfig.getUri('/bookings/cancel'),
                headers: ApiConfig.getHeaders(token: tempTok),
                body: jsonEncode({'booking_id': b['id'], 'reason': 'Pre-test cleanup'}),
              );
            }
          }
        }
      }

      // 1. Authenticate Customer (ID 2)
      final cRes = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'customer@drivemate.com', 'password': 'password123'}),
      );
      expect(cRes.statusCode, equals(200));
      customerToken = jsonDecode(cRes.body)['data']['token'];

      // 2. Authenticate Driver 9 (Amitava Roy)
      final d1Res = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'amitava.driver@drivemate.com', 'password': 'password123'}),
      );
      expect(d1Res.statusCode, equals(200));
      driverToken = jsonDecode(d1Res.body)['data']['token'];

      // 3. Authenticate Driver 10 (Animesh Barman)
      final d2Res = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'animesh.driver@drivemate.com', 'password': 'password123'}),
      );
      expect(d2Res.statusCode, equals(200));
      otherDriverToken = jsonDecode(d2Res.body)['data']['token'];
      expect(otherDriverToken.isNotEmpty, isTrue);

      // 4. Authenticate Administrator (Admin DriveMate, ID 1)
      final aRes = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'admin@drivemate.com', 'password': 'password123'}),
      );
      expect(aRes.statusCode, equals(200));
      adminToken = jsonDecode(aRes.body)['data']['token'];
    });

    test('1. Authentication Gate: Customer, Driver, and Admin identity tokens & roles verified', () async {
      // Customer profile check
      final cProfile = await http.get(
        ApiConfig.getUri('/users/profile'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      expect(cProfile.statusCode, equals(200));
      expect(jsonDecode(cProfile.body)['data']['role'], equals('customer'));

      // Driver profile check
      final dProfile = await http.get(
        ApiConfig.getUri('/users/profile'),
        headers: ApiConfig.getHeaders(token: driverToken),
      );
      expect(dProfile.statusCode, equals(200));
      expect(jsonDecode(dProfile.body)['data']['role'], equals('driver'));

      // Admin profile check
      final aProfile = await http.get(
        ApiConfig.getUri('/users/profile'),
        headers: ApiConfig.getHeaders(token: adminToken),
      );
      expect(aProfile.statusCode, equals(200));
      expect(jsonDecode(aProfile.body)['data']['role'], equals('admin'));
    });

    test('2. Real Driver Fleet Query: Authenticated listing with genuine database records & sorting', () async {
      final res = await http.get(
        ApiConfig.getUri('/drivers/eligible', {
          'sort': 'rating',
          'pickup_lat': '22.5726',
          'pickup_lng': '88.3639',
        }),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      expect(res.statusCode, equals(200));
      final list = jsonDecode(res.body)['data'] as List;
      expect(list.isNotEmpty, isTrue);

      final driver = list.first;
      expect(driver['driver_name'], isNotNull);
      expect(driver['id'], isNotNull);
      expect(driver['is_online'], equals(true));
      expect(driver['id'], isNot(equals(3))); // Never hardcoded fallback
    });

    test('3. Full Lifecycle: Booking -> Negotiation -> Arrival -> OTP Start -> Completion -> Invoice -> Payment -> Review', () async {
      // Step A: Booking Creation with Proposed Offer
      final bookRes = await http.post(
        ApiConfig.getUri('/bookings/create'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'type': 'hire_driver',
          'hiring_type': 'one_way',
          'driver_id': 9,
          'start_date': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
          'pickup_location': 'Howrah Station Platform 1, Kolkata',
          'destination': 'Eco Space Business Park, Rajarhat',
          'distance_km': 18.2,
          'estimated_fare': 550.0,
          'total_amount': 550.0,
          'customer_offer': 400.0,
          'negotiated_fare': 400.0,
          'negotiation_status': 'PENDING',
          'notes': 'Looking for immediate pickup from station exit',
        }),
      );
      expect(bookRes.statusCode, isIn([200, 201]));
      final bookingData = jsonDecode(bookRes.body)['data'];
      final bookingId = ((bookingData['booking_id'] ?? bookingData['id']) as num).toInt();

      try {
        // Step B: Two-Way Fare Negotiation
        // Driver 9 counter-offers ₹450
        final counterRes = await http.post(
          ApiConfig.getUri('/negotiation/respond'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'action': 'counter',
            'counter_fare': 450.0,
            'notes': 'Highway toll included in this offer',
          }),
        );
        expect(counterRes.statusCode, equals(200));

        // Customer 2 accepts Driver counter-offer of ₹450
        final acceptOfferRes = await http.post(
          ApiConfig.getUri('/negotiation/respond'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'action': 'accept',
          }),
        );
        expect(acceptOfferRes.statusCode, equals(200));
        expect(jsonDecode(acceptOfferRes.body)['data']['agreed_fare'], equals(450.0));

        // Step C: Driver 9 arrives at pickup
        final arrRes = await http.post(
          ApiConfig.getUri('/trips/arrived'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({'booking_id': bookingId}),
        );
        expect(arrRes.statusCode, equals(200));

        // Retrieve genuine OTP from customer booking details
        final bDetailRes = await http.get(
          ApiConfig.getUri('/bookings/detail', {'id': '$bookingId'}),
          headers: ApiConfig.getHeaders(token: customerToken),
        );
        final bDetail = jsonDecode(bDetailRes.body)['data'];
        final startOtp = bDetail['start_otp'];
        expect(startOtp, isNotNull);
        expect(startOtp.length, equals(4));

        // Invalid OTP attempt must be rejected (Security requirement)
        final badOtpRes = await http.post(
          ApiConfig.getUri('/trips/start'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'otp': '0000',
            'start_lat': 22.5850,
            'start_lng': 88.3420,
          }),
        );
        expect(badOtpRes.statusCode, equals(400));
        expect(jsonDecode(badOtpRes.body)['message'], contains('Invalid'));

        // Step D: Start Trip with Genuine OTP
        final startRes = await http.post(
          ApiConfig.getUri('/trips/start'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'otp': startOtp,
            'start_lat': 22.5850,
            'start_lng': 88.3420,
          }),
        );
        expect(startRes.statusCode, equals(201));
        final tripId = (jsonDecode(startRes.body)['data']['trip_id'] as num).toInt();

        // Step E: Complete Trip with Final Mutually Accepted Fare
        final compRes = await http.put(
          ApiConfig.getUri('/trips/complete'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({
            'trip_id': tripId,
            'fare': 450.0,
            'distance_km': 18.2,
          }),
        );
        expect(compRes.statusCode, equals(200));

        // Step F: Retrieve and Verify Tax Invoice
        final invRes = await http.get(
          ApiConfig.getUri('/payments/invoice', {'booking_id': '$bookingId'}),
          headers: ApiConfig.getHeaders(token: customerToken),
        );
        expect(invRes.statusCode, equals(200));
        final invData = jsonDecode(invRes.body)['data'];
        expect(invData['booking_id'], equals(bookingId));
        expect(invData['fare_breakdown']['total_amount'], equals(450.0));
        expect(invData['payment']['status'], equals('DUE'));
        expect(invData['payment_qr']['available'], isTrue);

        // Step G: Razorpay Cryptographic HMAC Payment Verification
        const secret = 'drivemate_sandbox_secret_9876';
        final rzpOrderRes = await http.post(
          ApiConfig.getUri('/payments/create-order'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'amount': 450.0,
            'payment_method': 'razorpay',
          }),
        );
        expect(rzpOrderRes.statusCode, equals(200));
        final rzpOrderId = jsonDecode(rzpOrderRes.body)['data']['order_id'];
        final paymentId = 'pay_final_${DateTime.now().millisecondsSinceEpoch}';

        final hmac = Hmac(sha256, utf8.encode(secret));
        final validSig = hmac.convert(utf8.encode('$rzpOrderId|$paymentId')).toString();

        final verifyRes = await http.post(
          ApiConfig.getUri('/payments/verify'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'order_id': rzpOrderId,
            'payment_id': paymentId,
            'signature': validSig,
          }),
        );
        expect(verifyRes.statusCode, equals(200));
        expect(jsonDecode(verifyRes.body)['data']['status'], equals('paid'));

        // Step H: Customer Authentic Review Submission
        final reviewRes = await http.post(
          ApiConfig.getUri('/reviews/add'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'rating': 5,
            'comment': 'Outstanding experience! Chauffeur Amitava was professional and punctual.',
          }),
        );
        expect(reviewRes.statusCode, equals(201));
        final reviewData = jsonDecode(reviewRes.body)['data'];
        expect(reviewData['target_driver_id'], equals(9));
        expect(reviewData['driver_avg_rating'], isNotNull);

      } finally {
        await http.put(
          ApiConfig.getUri('/bookings/cancel'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({'booking_id': bookingId, 'reason': 'Integration Test Teardown'}),
        );
      }
    });

    test('4. Support Desk Lifecycle: Customer creates ticket, Admin views and replies, User notified', () async {
      // 1. Customer creates support ticket
      final ticketRes = await http.post(
        ApiConfig.getUri('/support/create-ticket'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'subject': 'Luggage assistance query',
          'category': 'service',
          'message': 'Will the chauffeur assist with two 25kg luggage bags for the airport transfer?',
        }),
      );
      expect(ticketRes.statusCode, isIn([200, 201]));
      final ticketData = jsonDecode(ticketRes.body)['data'];
      final ticketId = (ticketData['ticket_id'] as num).toInt();

      // 2. Admin retrieves support tickets
      final adminTicketsRes = await http.get(
        ApiConfig.getUri('/admin/support/tickets'),
        headers: ApiConfig.getHeaders(token: adminToken),
      );
      expect(adminTicketsRes.statusCode, equals(200));
      final allTickets = jsonDecode(adminTicketsRes.body)['data'] as List;
      expect(allTickets.any((t) => t['id'] == ticketId), isTrue);

      // 3. Admin replies to ticket
      final replyRes = await http.put(
        ApiConfig.getUri('/admin/support/reply'),
        headers: ApiConfig.getHeaders(token: adminToken),
        body: jsonEncode({
          'ticket_id': ticketId,
          'admin_reply': 'Yes, our premium chauffeurs always assist passengers with loading and unloading luggage.',
          'status': 'resolved',
        }),
      );
      expect(replyRes.statusCode, equals(200));

      // 4. Customer retrieves user tickets to verify response
      final userTicketsRes = await http.get(
        ApiConfig.getUri('/support/my-tickets'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      expect(userTicketsRes.statusCode, equals(200));
      final userTickets = jsonDecode(userTicketsRes.body)['data'] as List;
      final updatedTicket = userTickets.firstWhere((t) => t['id'] == ticketId);
      expect(updatedTicket['status'], equals('resolved'));
      expect(updatedTicket['admin_reply'], contains('assist passengers with loading'));
    });

    test('5. Admin Authorization & Security: Unauthorized non-admin rejected from sensitive admin actions', () async {
      // Customer attempts admin analytics
      final custAnalytics = await http.get(
        ApiConfig.getUri('/admin/reports/analytics'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      expect(custAnalytics.statusCode, equals(403), reason: 'Customer must never access admin reports');

      // Driver attempts admin analytics
      final driverAnalytics = await http.get(
        ApiConfig.getUri('/admin/reports/analytics'),
        headers: ApiConfig.getHeaders(token: driverToken),
      );
      expect(driverAnalytics.statusCode, equals(403), reason: 'Driver must never access admin reports');

      // Admin access succeeds
      final adminAnalytics = await http.get(
        ApiConfig.getUri('/admin/reports/analytics'),
        headers: ApiConfig.getHeaders(token: adminToken),
      );
      expect(adminAnalytics.statusCode, equals(200));
      expect(jsonDecode(adminAnalytics.body)['success'], isTrue);

      // Customer attempts admin settings update
      final custSettings = await http.put(
        ApiConfig.getUri('/admin/settings'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({'base_fare': '160.0'}),
      );
      expect(custSettings.statusCode, equals(403), reason: 'Customer must never update admin settings');

      // Admin updates settings successfully
      final adminSettings = await http.put(
        ApiConfig.getUri('/admin/settings'),
        headers: ApiConfig.getHeaders(token: adminToken),
        body: jsonEncode({'base_fare': '150.0'}),
      );
      expect(adminSettings.statusCode, equals(200));
      expect(jsonDecode(adminSettings.body)['success'], isTrue);
    });
  });
}
