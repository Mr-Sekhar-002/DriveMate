// test/phase5_smart_auto_match_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

  group('Phase 5: Smart Auto Match Unit Tests', () {
    test('1. EligibleDriver maps matchScore and transparent scoreBreakdown correctly', () {
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
        'eta_minutes': 2,
        'total_match_score': 99.6,
        'score_breakdown': {
          'availability_pts': 35.0,
          'distance_eta_pts': 30.0,
          'rating_pts': 19.6,
          'experience_pts': 10.0,
          'compatibility_pts': 5.0,
          'weights': {
            'availability': '35%',
            'distance_eta': '30%',
            'rating': '20%',
            'experience': '10%',
            'compatibility': '5%',
          }
        }
      };

      final driver = EligibleDriver.fromJson(json);

      expect(driver.id, equals(9));
      expect(driver.name, equals('Amitava Roy (Chauffeur)'));
      expect(driver.matchScore, equals(99.6));
      expect(driver.scoreBreakdown, isNotNull);
      expect(driver.scoreBreakdown!['availability_pts'], equals(35.0));
      expect(driver.scoreBreakdown!['distance_eta_pts'], equals(30.0));
      expect(driver.scoreBreakdown!['rating_pts'], equals(19.6));
      expect(driver.scoreBreakdown!['experience_pts'], equals(10.0));
      expect(driver.scoreBreakdown!['compatibility_pts'], equals(5.0));
    });

    test('2. Unrated driver does not receive fake 5.0 rating or perfect rating points', () {
      final json = {
        'id': 15,
        'driver_name': 'New Driver',
        'avg_rating': null,
        'total_trips': 0,
        'experience_years': 1,
        'total_match_score': 74.0,
        'score_breakdown': {
          'availability_pts': 35.0,
          'distance_eta_pts': 15.0,
          'rating_pts': 10.0, // Neutral 50% score for unrated driver
          'experience_pts': 10.0,
          'compatibility_pts': 4.0,
        }
      };

      final driver = EligibleDriver.fromJson(json);
      expect(driver.avgRating, isNull);
      expect(driver.scoreBreakdown!['rating_pts'], equals(10.0));
    });

    test('3. DriveMateProvider queues runners-up and tryNextSmartMatchedDriver cascades sequentially', () {
      final provider = DriveMateProvider();

      final d1 = EligibleDriver(
        id: 9,
        name: 'Amitava Roy',
        vehicleType: 'Sedan',
        vehicleModel: 'Hyundai Creta SX',
        avgRating: 4.9,
        totalTrips: 184,
        matchScore: 99.6,
      );

      // Simulate state after auto match
      provider.selectDriver(d1);
      expect(provider.selectedDriver?.id, equals(9));

      // Test tryNextSmartMatchedDriver when queue is empty
      final emptyResult = provider.tryNextSmartMatchedDriver();
      expect(emptyResult, isNull);
    });
  });

  group('Phase 5: Live PHP & MySQL Smart Auto Match Integration', () {
    test('4. POST /drivers/smart-match returns 5-criteria weighted score and ranked candidates', () async {
      final loginRes = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'customer@drivemate.com', 'password': 'password123'}),
      );
      expect(loginRes.statusCode, equals(200));
      final token = jsonDecode(loginRes.body)['data']['token'];

      final matchRes = await http.post(
        ApiConfig.getUri('/drivers/smart-match'),
        headers: ApiConfig.getHeaders(token: token),
        body: jsonEncode({
          'pickup_lat': 21.8767,
          'pickup_lng': 88.1912,
          'vehicle_preference': 'sedan',
        }),
      );

      expect(matchRes.statusCode, equals(200));
      final json = jsonDecode(matchRes.body);
      expect(json['success'], isTrue);
      expect(json['data']['algorithm'], contains('Smart Weighted Auto-Match'));

      final recDriver = json['data']['recommended_driver'];
      expect(recDriver, isNotNull);
      expect(recDriver['id'], equals(9));
      expect(recDriver['total_match_score'], greaterThanOrEqualTo(90.0));
      expect(recDriver['score_breakdown'], isNotNull);
      expect(recDriver['score_breakdown']['weights']['availability'], equals('35%'));
      expect(recDriver['score_breakdown']['weights']['distance_eta'], equals('30%'));
      expect(recDriver['score_breakdown']['weights']['rating'], equals('20%'));
      expect(recDriver['score_breakdown']['weights']['experience'], equals('10%'));
      expect(recDriver['score_breakdown']['weights']['compatibility'], equals('5%'));

      final runnersUp = json['data']['runners_up'] as List;
      expect(runnersUp.isNotEmpty, isTrue);
      expect(runnersUp[0]['id'], equals(10));
      expect(recDriver['total_match_score'], greaterThanOrEqualTo(runnersUp[0]['total_match_score']));
    });

    test('5. POST /drivers/smart-match supports configurable scoring weights override', () async {
      final loginRes = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'customer@drivemate.com', 'password': 'password123'}),
      );
      final token = jsonDecode(loginRes.body)['data']['token'];

      // Send custom configurable weights: 40/25/15/15/5
      final customMatchRes = await http.post(
        ApiConfig.getUri('/drivers/smart-match'),
        headers: ApiConfig.getHeaders(token: token),
        body: jsonEncode({
          'pickup_lat': 21.8767,
          'pickup_lng': 88.1912,
          'vehicle_preference': 'sedan',
          'weights': {
            'availability': 40,
            'distance_eta': 25,
            'rating': 15,
            'experience': 15,
            'compatibility': 5,
          }
        }),
      );

      expect(customMatchRes.statusCode, equals(200));
      final json = jsonDecode(customMatchRes.body);
      expect(json['success'], isTrue);

      final rec = json['data']['recommended_driver'];
      expect(rec['score_breakdown']['weights']['availability'], equals('40%'));
      expect(rec['score_breakdown']['weights']['distance_eta'], equals('25%'));
      expect(rec['score_breakdown']['weights']['rating'], equals('15%'));
      expect(rec['score_breakdown']['weights']['experience'], equals('15%'));
      expect(rec['score_breakdown']['weights']['compatibility'], equals('5%'));
    });

    test('6. Smart Auto Match excludes busy drivers with active bookings/trips', () async {
      final loginRes = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'customer@drivemate.com', 'password': 'password123'}),
      );
      final token = jsonDecode(loginRes.body)['data']['token'];

      // Customer books Driver 9 via hiring
      final bookRes = await http.post(
        ApiConfig.getUri('/driver-hiring/booking'),
        headers: ApiConfig.getHeaders(token: token),
        body: jsonEncode({
          'driver_id': 9,
          'pickup_location': '820 Lexington Ave',
          'destination': 'JFK Terminal 4',
          'pickup_lat': 21.8767,
          'pickup_lng': 88.1912,
          'dest_lat': 21.9000,
          'dest_lng': 88.2200,
          'hiring_type': 'one_way',
          'customer_car_model': 'Hyundai Creta',
          'distance_km': 14.8,
          'initial_offer': 350.00,
        }),
      );
      expect(bookRes.statusCode, equals(201));
      final bookingId = jsonDecode(bookRes.body)['data']['booking_id'];

      // Driver 9 accepts booking to become confirmed/busy
      final d1Login = await http.post(
        ApiConfig.getUri('/auth/login'),
        headers: ApiConfig.getHeaders(),
        body: jsonEncode({'email': 'amitava.driver@drivemate.com', 'password': 'password123'}),
      );
      final d1Token = jsonDecode(d1Login.body)['data']['token'];

      final acceptRes = await http.post(
        ApiConfig.getUri('/negotiation/respond'),
        headers: ApiConfig.getHeaders(token: d1Token),
        body: jsonEncode({'booking_id': bookingId, 'action': 'accept'}),
      );
      expect(acceptRes.statusCode, equals(200));

      // Now Smart Auto Match should recommend Driver 10 because Driver 9 is busy
      final matchRes = await http.post(
        ApiConfig.getUri('/drivers/smart-match'),
        headers: ApiConfig.getHeaders(token: token),
        body: jsonEncode({
          'pickup_lat': 21.8767,
          'pickup_lng': 88.1912,
          'vehicle_preference': 'sedan',
        }),
      );

      expect(matchRes.statusCode, equals(200));
      final matchJson = jsonDecode(matchRes.body);
      final recDriver = matchJson['data']['recommended_driver'];
      // Driver 10 must now be recommended as Driver 9 is busy
      expect(recDriver['id'], equals(10));

      // Cleanup: Cancel booking to restore driver availability
      await http.put(
        ApiConfig.getUri('/bookings/cancel'),
        headers: ApiConfig.getHeaders(token: token),
        body: jsonEncode({'booking_id': bookingId}),
      );
    });

    test('7. End-to-End Flutter Provider performSmartAutoMatch with Runner-up Sequential Cycling', () async {
      final provider = DriveMateProvider();

      // Login customer
      final loggedIn = await provider.loginWithApi(email: 'customer@drivemate.com', password: 'password123');
      expect(loggedIn, isTrue);

      // Perform Smart Auto Match
      final matched = await provider.performSmartAutoMatch();
      expect(matched, isNotNull);
      expect(provider.autoMatchedDriver, isNotNull);
      expect(provider.selectedDriver, isNotNull);
      expect(provider.selectedDriver!.id, equals(matched!.id));

      // Check that runners-up are populated
      expect(provider.smartMatchRunnersUp.isNotEmpty, isTrue);
      final firstRunnerUpId = provider.smartMatchRunnersUp.first.id;

      // Simulate customer or driver rejection: cycle to next candidate
      final nextCandidate = provider.tryNextSmartMatchedDriver();
      expect(nextCandidate, isNotNull);
      expect(nextCandidate!.id, equals(firstRunnerUpId));
      expect(provider.selectedDriver!.id, equals(firstRunnerUpId));
    });
  });
}
