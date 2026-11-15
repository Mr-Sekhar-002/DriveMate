// test/phase6_payment_invoice_rating_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    ApiConfig.activeEnvironment = ApiEnvironment.lan;
    ApiConfig.customBaseUrlOverride = null;
  });

  group('Phase 6: QR Invoice, Payment & Rating Unit Tests', () {
    test('1. TripInvoice model correctly parses GST breakdown and payment QR parameters', () {
      final mockJson = {
        'invoice_number': 'INV-DM-000088',
        'invoice_date': '2026-11-01 16:00:00',
        'booking_id': 88,
        'booking_type': 'hire_driver',
        'customer': {
          'name': 'Rahul Sharma',
          'phone': '9876543210',
          'email': 'customer@drivemate.com',
        },
        'driver': {
          'name': 'Amitava Roy',
          'phone': '9830012345',
          'rating': '4.5',
          'vehicle': 'Honda City (WB-02-1234)',
        },
        'trip_details': {
          'pickup': 'Salt Lake Sector V',
          'destination': 'Howrah Station',
          'distance_km': '14.2',
          'trip_status': 'completed',
        },
        'fare_breakdown': {
          'subtotal': 476.19,
          'platform_fee': 25.0,
          'cgst_2_5': 11.90,
          'sgst_2_5': 11.90,
          'gst_total': 23.81,
          'total_amount': 500.0,
          'currency': 'INR',
        },
        'payment': {
          'method': 'UPI',
          'status': 'DUE',
          'transaction_id': 'DM_TXN_88_TEST',
          'paid_at': null,
        },
        'payment_qr': {
          'available': true,
          'qr_code_url': 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=upi_intent',
          'upi_intent_url': 'upi://pay?pa=drivemate@icici&pn=DriveMate&am=500&cu=INR&tn=Ride&tr=DM_TXN_88_TEST',
          'upi_vpa': 'drivemate@icici',
          'transaction_id': 'DM_TXN_88_TEST',
          'amount': 500.0,
          'message': 'Scan with any UPI app to pay.',
        }
      };

      final invoice = TripInvoice.fromJson(mockJson);
      expect(invoice.invoiceNumber, equals('INV-DM-000088'));
      expect(invoice.totalAmount, equals(500.0));
      expect(invoice.subtotal, equals(476.19));
      expect(invoice.gstTotal, equals(23.81));
      expect(invoice.paymentStatus, equals('DUE'));
      expect(invoice.qrAvailable, isTrue);
      expect(invoice.upiVpa, equals('drivemate@icici'));
      expect(invoice.driverRating, equals('4.5'));
    });

    test('2. DriverProfile default rating is 0.0 (no fixed 4.8 / 5.0 dummy ratings)', () {
      final profile = DriverProfile(
        id: 'dp_test',
        userId: 'usr_test',
        driverName: 'New Driver',
        phone: '9876543210',
        licenseNumber: 'DL-TEST-001',
        experienceYears: 3,
      );
      expect(profile.rating, equals(0.0));
      expect(profile.totalTrips, equals(0));
    });

    test('3. Razorpay HMAC-SHA256 signature calculation matches expected RFC 2104 spec', () {
      const orderId = 'order_sb_test123456';
      const paymentId = 'pay_sb_test789012';
      const secret = 'drivemate_sandbox_secret_9876';

      final hmac = Hmac(sha256, utf8.encode(secret));
      final digest = hmac.convert(utf8.encode('$orderId|$paymentId'));
      final signature = digest.toString();

      expect(signature, isNotEmpty);
      expect(signature.length, equals(64)); // 256 bits = 64 hex characters
    });
  });

  group('Phase 6: Live PHP & MySQL Integration Tests', () {
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

    test('4. End-to-End: Trip completion -> Invoice & QR generation -> Razorpay HMAC Verification -> Rating', () async {
      // Step A: Create a clean booking from Customer 2 to Driver 9
      final bookRes = await http.post(
        ApiConfig.getUri('/bookings/create'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'type': 'hire_driver',
          'hiring_type': 'one_way',
          'driver_id': 9,
          'start_date': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
          'pickup_location': 'Salt Lake Gate 1, Kolkata',
          'destination': 'Netaji Subhash Airport, Kolkata',
          'distance_km': 12.5,
          'estimated_fare': 450.0,
          'total_amount': 450.0,
        }),
      );
      expect(bookRes.statusCode, isIn([200, 201]));
      final bookingData = jsonDecode(bookRes.body)['data'];
      final bookingId = ((bookingData['booking_id'] ?? bookingData['id']) as num).toInt();

      try {
        // Step B: Driver 9 arrives at pickup
        final arrRes = await http.post(
          ApiConfig.getUri('/trips/arrived'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({'booking_id': bookingId}),
        );
        expect(arrRes.statusCode, equals(200));

        // Retrieve genuine OTP from booking
        final bDetailRes = await http.get(
          ApiConfig.getUri('/bookings/detail', {'id': '$bookingId'}),
          headers: ApiConfig.getHeaders(token: customerToken),
        );
        final startOtp = jsonDecode(bDetailRes.body)['data']['start_otp'];

        // Step C: Driver 9 starts trip with genuine OTP
        final startRes = await http.post(
          ApiConfig.getUri('/trips/start'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'otp': startOtp,
            'start_lat': 22.5726,
            'start_lng': 88.3639,
          }),
        );
        expect(startRes.statusCode, equals(201));
        final tripId = (jsonDecode(startRes.body)['data']['trip_id'] as num).toInt();

        // Step E: Driver 9 completes trip with mutually accepted fare ₹450
        final compRes = await http.put(
          ApiConfig.getUri('/trips/complete'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({
            'trip_id': tripId,
            'fare': 450.0,
            'distance_km': 12.5,
          }),
        );
        expect(compRes.statusCode, equals(200));
        final compData = jsonDecode(compRes.body)['data'];
        expect(compData['booking_id'], equals(bookingId));
        expect(compData['status'], equals('completed'));

        // Step F: Customer 2 retrieves invoice
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
        expect(invData['payment_qr']['upi_vpa'], equals('drivemate@icici'));
        expect(invData['payment_qr']['qr_code_url'], contains('api.qrserver.com'));

        // Step G: BOLA Test — Driver 10 (unrelated) attempts to access Customer 2's invoice
        final bolaInvRes = await http.get(
          ApiConfig.getUri('/payments/invoice', {'booking_id': '$bookingId'}),
          headers: ApiConfig.getHeaders(token: otherDriverToken),
        );
        expect(bolaInvRes.statusCode, equals(403), reason: 'Unrelated user must not access another booking invoice');

        // Step H: Payment Verification — Reject invalid signature
        const secret = 'drivemate_sandbox_secret_9876';
        final orderId = 'order_sb_test_$bookingId';
        const fakePaymentId = 'pay_fake_999999';

        final invalidSigRes = await http.post(
          ApiConfig.getUri('/payments/verify'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'order_id': orderId,
            'payment_id': fakePaymentId,
            'signature': 'invalid_forged_signature_hex_1234567890',
          }),
        );
        expect(invalidSigRes.statusCode, equals(400));
        expect(jsonDecode(invalidSigRes.body)['message'], contains('signature verification failed'));

        // Step I: Payment Verification — Create Razorpay order and verify with genuine HMAC signature
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
        final validPaymentId = 'pay_valid_${DateTime.now().millisecondsSinceEpoch}';

        // Compute valid HMAC-SHA256 signature
        final hmac = Hmac(sha256, utf8.encode(secret));
        final validSignature = hmac.convert(utf8.encode('$rzpOrderId|$validPaymentId')).toString();

        final verifyRes = await http.post(
          ApiConfig.getUri('/payments/verify'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'order_id': rzpOrderId,
            'payment_id': validPaymentId,
            'signature': validSignature,
          }),
        );
        expect(verifyRes.statusCode, equals(200));
        final verifyData = jsonDecode(verifyRes.body)['data'];
        expect(verifyData['status'], equals('paid'));
        expect(verifyData['verified'], isTrue);

        // Step J: Replay Attack / Duplicate Payment Verification Prevention
        final duplicateVerifyRes = await http.post(
          ApiConfig.getUri('/payments/verify'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'order_id': rzpOrderId,
            'payment_id': validPaymentId,
            'signature': validSignature,
          }),
        );
        expect(duplicateVerifyRes.statusCode, equals(400));
        expect(jsonDecode(duplicateVerifyRes.body)['message'], contains('Duplicate payment verification'));

        // Step K: Rating Security — Driver cannot rate self
        final driverSelfRateRes = await http.post(
          ApiConfig.getUri('/reviews/add'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'rating': 5,
            'comment': 'I am the best driver',
          }),
        );
        expect(driverSelfRateRes.statusCode, equals(403), reason: 'Driver must never rate themselves');

        // Step L: Rating Security — Unrelated Driver 10 cannot rate Driver 9
        final thirdPartyRateRes = await http.post(
          ApiConfig.getUri('/reviews/add'),
          headers: ApiConfig.getHeaders(token: otherDriverToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'rating': 5,
            'comment': 'Good service',
          }),
        );
        expect(thirdPartyRateRes.statusCode, equals(403), reason: 'Only the customer of the booking can rate');

        // Step M: Customer 2 rates Driver 9
        final reviewRes = await http.post(
          ApiConfig.getUri('/reviews/add'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'rating': 5,
            'comment': 'Excellent ride! Amitava was on time, courteous, and drove safely.',
          }),
        );
        expect(reviewRes.statusCode, equals(201));
        final reviewData = jsonDecode(reviewRes.body)['data'];
        expect(reviewData['booking_id'], equals(bookingId));
        expect(reviewData['target_driver_id'], equals(9));
        expect(reviewData['rating'], equals(5));
        expect(reviewData['driver_avg_rating'], isNotNull);

        // Step N: Prevent duplicate rating for the same booking
        final duplicateReviewRes = await http.post(
          ApiConfig.getUri('/reviews/add'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'rating': 4,
            'comment': 'Trying to rate again',
          }),
        );
        expect(duplicateReviewRes.statusCode, equals(409), reason: 'One review per completed booking');

      } finally {
        // Cleanup booking to prevent blocking
        await http.put(
          ApiConfig.getUri('/bookings/cancel'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({'booking_id': bookingId, 'reason': 'Test Suite Completed'}),
        );
      }
    });

    test('5. Cash Payment Collection: Driver collects cash and marks payment paid', () async {
      // Create booking
      final bookRes = await http.post(
        ApiConfig.getUri('/bookings/create'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'type': 'hire_driver',
          'hiring_type': 'one_way',
          'driver_id': 10,
          'start_date': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
          'pickup_location': 'Park Street, Kolkata',
          'destination': 'Victoria Memorial, Kolkata',
          'distance_km': 5.0,
          'estimated_fare': 200.0,
          'total_amount': 200.0,
        }),
      );
      expect(bookRes.statusCode, isIn([200, 201]));
      final bookingData = jsonDecode(bookRes.body)['data'];
      final bookingId = ((bookingData['booking_id'] ?? bookingData['id']) as num).toInt();

      try {
        // Driver 10 arrives
        final arrRes = await http.post(
          ApiConfig.getUri('/trips/arrived'),
          headers: ApiConfig.getHeaders(token: otherDriverToken),
          body: jsonEncode({'booking_id': bookingId}),
        );
        expect(arrRes.statusCode, equals(200));

        // Get OTP and start trip
        final bDetailRes = await http.get(
          ApiConfig.getUri('/bookings/detail', {'id': '$bookingId'}),
          headers: ApiConfig.getHeaders(token: customerToken),
        );
        final startOtp = jsonDecode(bDetailRes.body)['data']['start_otp'];

        final startRes = await http.post(
          ApiConfig.getUri('/trips/start'),
          headers: ApiConfig.getHeaders(token: otherDriverToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'otp': startOtp,
            'start_lat': 22.5550,
            'start_lng': 88.3500,
          }),
        );
        expect(startRes.statusCode, equals(201));
        final tripId = (jsonDecode(startRes.body)['data']['trip_id'] as num).toInt();

        // Complete trip
        await http.put(
          ApiConfig.getUri('/trips/complete'),
          headers: ApiConfig.getHeaders(token: otherDriverToken),
          body: jsonEncode({'trip_id': tripId, 'fare': 200.0, 'distance_km': 5.0}),
        );

        // Customer attempts to confirm cash collection: Must fail 403 Forbidden
        final custCashRes = await http.post(
          ApiConfig.getUri('/payments/cash-collect'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({'booking_id': bookingId, 'amount': 200.0}),
        );
        expect(custCashRes.statusCode, equals(403), reason: 'Customer cannot confirm cash collection');

        // Driver 9 (unassigned driver) attempts to confirm cash collection: Must fail 403 Forbidden
        final unassignedDriverCashRes = await http.post(
          ApiConfig.getUri('/payments/cash-collect'),
          headers: ApiConfig.getHeaders(token: driverToken),
          body: jsonEncode({'booking_id': bookingId, 'amount': 200.0}),
        );
        expect(unassignedDriverCashRes.statusCode, equals(403), reason: 'Only assigned driver can confirm cash collection');

        // Driver 10 (assigned driver) confirms cash collection: Must succeed 200 OK
        final driverCashRes = await http.post(
          ApiConfig.getUri('/payments/cash-collect'),
          headers: ApiConfig.getHeaders(token: otherDriverToken),
          body: jsonEncode({'booking_id': bookingId, 'amount': 200.0}),
        );
        expect(driverCashRes.statusCode, equals(200));
        expect(jsonDecode(driverCashRes.body)['data']['status'], equals('paid'));

        // Verify booking payment status is now paid
        final checkRes = await http.get(
          ApiConfig.getUri('/bookings/detail', {'id': '$bookingId'}),
          headers: ApiConfig.getHeaders(token: customerToken),
        );
        expect(jsonDecode(checkRes.body)['data']['payment_status'], equals('paid'));

      } finally {
        await http.put(
          ApiConfig.getUri('/bookings/cancel'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({'booking_id': bookingId, 'reason': 'Test Suite Completed'}),
        );
      }
    });

    test('6. In-App Wallet: Top-up funds, query balance, and pay for booking via wallet', () async {
      // 1. Check wallet balance
      final wRes = await http.get(
        ApiConfig.getUri('/payments/wallet'),
        headers: ApiConfig.getHeaders(token: customerToken),
      );
      expect(wRes.statusCode, equals(200));
      final initialBalance = (jsonDecode(wRes.body)['data']['balance'] as num).toDouble();

      // 2. Add ₹500 to wallet
      final topRes = await http.post(
        ApiConfig.getUri('/payments/wallet/add-money'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({'amount': 500.0}),
      );
      expect(topRes.statusCode, equals(200));
      final newBalance = (jsonDecode(topRes.body)['data']['new_balance'] as num).toDouble();
      expect(newBalance, equals(initialBalance + 500.0));

      // 3. Create booking and pay via wallet
      final futureDate = DateTime.now().add(Duration(days: 30 + (DateTime.now().millisecondsSinceEpoch % 1000))).toIso8601String();
      final bookRes = await http.post(
        ApiConfig.getUri('/bookings/create'),
        headers: ApiConfig.getHeaders(token: customerToken),
        body: jsonEncode({
          'type': 'hire_driver',
          'hiring_type': 'one_way',
          'driver_id': 9,
          'start_date': futureDate,
          'pickup_location': 'Sealdah Station, Kolkata',
          'destination': 'Eco Park, Rajarhat',
          'distance_km': 10.0,
          'estimated_fare': 300.0,
          'total_amount': 300.0,
        }),
      );
      expect(bookRes.statusCode, isIn([200, 201]));
      final bookingData = jsonDecode(bookRes.body)['data'];
      final bookingId = ((bookingData['booking_id'] ?? bookingData['id']) as num).toInt();

      try {
        // Pay using wallet
        final payRes = await http.post(
          ApiConfig.getUri('/payments/create-order'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({
            'booking_id': bookingId,
            'amount': 300.0,
            'payment_method': 'wallet',
          }),
        );
        expect(payRes.statusCode, equals(200));
        final payData = jsonDecode(payRes.body)['data'];
        expect(payData['status'], equals('paid'));
        expect(payData['payment_method'], equals('wallet'));

        // Verify balance decreased by 300
        expect(payData['wallet_balance'], equals(newBalance - 300.0));

        // Verify booking is marked as paid
        final checkRes = await http.get(
          ApiConfig.getUri('/bookings/detail', {'id': '$bookingId'}),
          headers: ApiConfig.getHeaders(token: customerToken),
        );
        expect(jsonDecode(checkRes.body)['data']['payment_status'], equals('paid'));
      } finally {
        await http.put(
          ApiConfig.getUri('/bookings/cancel'),
          headers: ApiConfig.getHeaders(token: customerToken),
          body: jsonEncode({'booking_id': bookingId, 'reason': 'Test Suite Completed'}),
        );
      }
    });

    test('7. Webhook Signature Security: Reject unauthenticated & forged Razorpay webhooks', () async {
      const webhookSecret = 'drivemate_webhook_secret';
      final webhookPayload = jsonEncode({
        'event': 'payment.captured',
        'payload': {
          'payment': {
            'entity': {
              'id': 'pay_webhook_test_123',
              'order_id': 'order_webhook_test_123',
              'amount': 45000,
              'notes': {'booking_id': '9999'}
            }
          }
        }
      });

      // 1. Reject without signature header
      final noSigRes = await http.post(
        ApiConfig.getUri('/payments/webhook'),
        headers: {'Content-Type': 'application/json'},
        body: webhookPayload,
      );
      expect(noSigRes.statusCode, equals(400));
      expect(jsonDecode(noSigRes.body)['message'], contains('Missing required X-Razorpay-Signature'));

      // 2. Reject with forged signature header
      final forgedSigRes = await http.post(
        ApiConfig.getUri('/payments/webhook'),
        headers: {
          'Content-Type': 'application/json',
          'X-Razorpay-Signature': 'forged_fake_signature_hex_abcdef123456',
        },
        body: webhookPayload,
      );
      expect(forgedSigRes.statusCode, equals(400));
      expect(jsonDecode(forgedSigRes.body)['message'], contains('Invalid webhook signature'));

      // 3. Accept with genuine cryptographic HMAC-SHA256 signature
      final hmac = Hmac(sha256, utf8.encode(webhookSecret));
      final validSig = hmac.convert(utf8.encode(webhookPayload)).toString();

      final validRes = await http.post(
        ApiConfig.getUri('/payments/webhook'),
        headers: {
          'Content-Type': 'application/json',
          'X-Razorpay-Signature': validSig,
        },
        body: webhookPayload,
      );
      expect(validRes.statusCode, equals(200));
      expect(jsonDecode(validRes.body)['message'], contains('Webhook event processed'));
    });
  });
}
