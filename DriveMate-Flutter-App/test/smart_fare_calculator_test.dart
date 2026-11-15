import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/components/smart_fare_breakdown_sheet.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
  });

  group('Feature 4: Smart Fare Calculator & Transparent Breakdown Tests', () {
    test('SmartFareBreakdown model parses full 10-component breakdown accurately', () {
      final json = {
        'fare_id': 'DM-FARE-TEST101',
        'service_type': 'hire_driver',
        'hiring_type': 'one_way',
        'fare_type': 'ESTIMATED',
        'is_authoritative': true,
        'calculated_at': '2026-11-12T18:00:00Z',
        'inputs': {
          'distance_km': 15.0,
          'duration_minutes': 35,
          'hours': 0.0,
          'days': 0,
          'waiting_minutes': 10,
          'is_night': true,
          'night_hours': '22:00 - 06:00',
          'promo_code': 'WELCOME50',
        },
        'breakdown': {
          'base_fare': 150.0,
          'distance_charges': 210.0,
          'rate_per_km': 14.0,
          'hourly_charges': 0.0,
          'hourly_rate': 150.0,
          'daily_charges': 0.0,
          'daily_rate': 1800.0,
          'waiting_charges': 30.0,
          'waiting_rate_per_min': 3.0,
          'night_charges': 72.0,
          'night_charge_percent': '20%',
          'toll_charges': 50.0,
          'parking_charges': 20.0,
          'platform_fee': 25.0,
          'subtotal': 557.0,
          'discount': 50.0,
          'discount_details': '₹50 New Customer Welcome Discount',
          'taxable_amount': 507.0,
          'cgst_2_5': 12.68,
          'sgst_2_5': 12.67,
          'total_tax': 25.35,
          'total_fare': 532.35,
          'driver_earnings': 442.27,
          'platform_commission': 64.73,
          'currency': 'INR',
          'currency_symbol': '₹',
        }
      };

      final fare = SmartFareBreakdown.fromJson(json);

      expect(fare.fareId, 'DM-FARE-TEST101');
      expect(fare.serviceType, 'hire_driver');
      expect(fare.hiringType, 'one_way');
      expect(fare.isEstimated, isTrue);
      expect(fare.isFinalFare, isFalse);
      expect(fare.isAuthoritative, isTrue);

      // Verify components
      expect(fare.baseFare, 150.0);
      expect(fare.distanceCharges, 210.0);
      expect(fare.waitingCharges, 30.0);
      expect(fare.nightCharges, 72.0);
      expect(fare.tollCharges, 50.0);
      expect(fare.parkingCharges, 20.0);
      expect(fare.platformFee, 25.0);
      expect(fare.discount, 50.0);
      expect(fare.taxableAmount, 507.0);
      expect(fare.totalTax, 25.35);
      expect(fare.totalFare, 532.35);

      // Verify boolean flags
      expect(fare.hasDiscount, isTrue);
      expect(fare.hasNightSurcharge, isTrue);
      expect(fare.hasWaitingCharges, isTrue);
      expect(fare.hasTollOrParking, isTrue);
    });

    test('Live PHP backend calculates authoritative daytime & night fares with promo', () async {
      // 1. Daytime standard 10 km calculation
      final dayRes = await http.post(
        ApiConfig.getUri('/pricing/calculate'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({
          'service_type': 'hire_driver',
          'hiring_type': 'one_way',
          'distance_km': 10.0,
          'duration_minutes': 25,
          'start_time': '2026-11-12 14:00:00',
        }),
      );

      expect(dayRes.statusCode, equals(200));
      final dayData = jsonDecode(dayRes.body)['data'];
      expect(dayData['is_authoritative'], isTrue);
      expect(dayData['breakdown']['base_fare'], equals(150.0));
      expect(dayData['breakdown']['distance_charges'], equals(140.0));
      expect(dayData['breakdown']['platform_fee'], equals(25.0));

      // 2. Night ride with WELCOME50 promo
      final nightRes = await http.post(
        ApiConfig.getUri('/pricing/calculate'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({
          'service_type': 'hire_driver',
          'hiring_type': 'one_way',
          'distance_km': 10.0,
          'duration_minutes': 25,
          'start_time': '2026-11-12 23:30:00',
          'promo_code': 'WELCOME50',
        }),
      );

      expect(nightRes.statusCode, equals(200));
      final nightData = jsonDecode(nightRes.body)['data'];
      expect(nightData['inputs']['is_night'], isTrue);
      expect(nightData['breakdown']['night_charges'], greaterThan(0.0));
      expect(nightData['breakdown']['discount'], equals(50.0));
    });

    testWidgets('SmartFareBreakdownSheet renders all 10 fare components and applies promo coupon', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = DriveMateProvider();
      final sampleFare = SmartFareBreakdown(
        fareId: 'DM-FARE-001',
        serviceType: 'hire_driver',
        hiringType: 'one_way',
        fareType: 'ESTIMATED',
        isAuthoritative: true,
        calculatedAt: '2026-11-12T18:00:00Z',
        distanceKm: 12.5,
        durationMinutes: 30,
        baseFare: 150.0,
        distanceCharges: 175.0,
        ratePerKm: 14.0,
        nightCharges: 65.0,
        nightChargePercent: '20%',
        platformFee: 25.0,
        subtotal: 415.0,
        discount: 0.0,
        taxableAmount: 415.0,
        cgst: 10.38,
        sgst: 10.37,
        totalTax: 20.75,
        totalFare: 435.75,
        driverEarnings: 348.0,
        platformCommission: 67.0,
      );

      bool confirmed = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<DriveMateProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    SmartFareBreakdownSheet.show(
                      context,
                      fare: sampleFare,
                      onConfirmBooking: () => confirmed = true,
                    );
                  },
                  child: const Text('Open Breakdown'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Breakdown'));
      await tester.pumpAndSettle();

      // Verifies title and badge
      expect(find.text('Transparent Fare Breakdown'), findsOneWidget);
      expect(find.text('ESTIMATED FARE'), findsOneWidget);

      // Verifies component lines
      expect(find.text('Base Pickup Fare'), findsOneWidget);
      expect(find.text('₹150.00'), findsOneWidget);
      expect(find.textContaining('Distance Charges (12.5 km'), findsOneWidget);
      expect(find.text('₹175.00'), findsOneWidget);
      expect(find.textContaining('Night Surcharge (20%'), findsOneWidget);
      expect(find.text('Platform Safety & Technology Fee'), findsOneWidget);
      expect(find.text('₹25.00'), findsOneWidget);

      // Verifies GST and Total
      expect(find.text('Total GST Levies (5%)'), findsOneWidget);
      expect(find.text('TOTAL PAYABLE'), findsOneWidget);
      expect(find.text('₹435.75'), findsOneWidget);

      // Verifies Guarantee note
      expect(find.textContaining('Zero Hidden Charges Guarantee'), findsOneWidget);

      // Verifies Promo coupon section
      expect(find.text('Apply Coupon / Promo Code'), findsOneWidget);
      expect(find.text('WELCOME50 (₹50 OFF)'), findsOneWidget);

      // Tap Confirm booking button
      final btnFinder = find.text('Accept Authoritative Fare & Book');
      await tester.ensureVisible(btnFinder);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });
  });
}
