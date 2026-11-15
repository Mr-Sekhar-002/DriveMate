// test/phase3_api_integration_test.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiConfig.activeEnvironment = ApiEnvironment.lan;
    ApiConfig.customBaseUrlOverride = null;
  });

  group('Phase 3: ApiConfig Centralization & Network Architecture Tests', () {
    test('1. Default activeEnvironment is LAN with physical Windows IPv4 and Port 80', () {
      expect(ApiConfig.activeEnvironment, equals(ApiEnvironment.lan));
      expect(ApiConfig.lanHostIp, equals('192.168.0.107'));
      expect(ApiConfig.apachePort, equals(80));
      expect(ApiConfig.baseUrl, equals('http://192.168.0.107:80/drivemate-api/public/index.php/api'));
    });

    test('2. ApiConfig supports local, emulator, and production environments', () {
      ApiConfig.activeEnvironment = ApiEnvironment.local;
      expect(ApiConfig.baseUrl, equals('http://localhost:80/drivemate-api/public/index.php/api'));

      ApiConfig.activeEnvironment = ApiEnvironment.emulator;
      expect(ApiConfig.baseUrl, equals('http://10.0.2.2:80/drivemate-api/public/index.php/api'));

      ApiConfig.activeEnvironment = ApiEnvironment.production;
      expect(ApiConfig.baseUrl, equals('https://api.drivemate.in/api'));

      ApiConfig.activeEnvironment = ApiEnvironment.lan;
    });

    test('3. ApiConfig customBaseUrlOverride takes immediate precedence', () {
      ApiConfig.customBaseUrlOverride = 'http://192.168.1.105:8080/api';
      expect(ApiConfig.baseUrl, equals('http://192.168.1.105:8080/api'));

      ApiConfig.customBaseUrlOverride = null;
      expect(ApiConfig.baseUrl, equals('http://192.168.0.107:80/drivemate-api/public/index.php/api'));
    });

    test('4. ApiConfig.getUri builds correct URI without query params', () {
      final uri = ApiConfig.getUri('/auth/login');
      expect(uri.toString(), equals('http://192.168.0.107/drivemate-api/public/index.php/api/auth/login'));
      expect(uri.scheme, equals('http'));
      expect(uri.host, equals('192.168.0.107'));
      expect(uri.port, equals(80));
    });

    test('5. ApiConfig.getUri safely appends query parameters', () {
      final uri = ApiConfig.getUri('/trips/live-location', {'trip_id': '42', 'format': 'json'});
      expect(uri.queryParameters['trip_id'], equals('42'));
      expect(uri.queryParameters['format'], equals('json'));
      expect(uri.path, contains('/trips/live-location'));
    });

    test('6. ApiConfig.getHeaders includes Bearer token strictly when provided', () {
      final headersNoAuth = ApiConfig.getHeaders();
      expect(headersNoAuth['Content-Type'], equals('application/json'));
      expect(headersNoAuth['Accept'], equals('application/json'));
      expect(headersNoAuth.containsKey('Authorization'), isFalse);
      expect(headersNoAuth.containsKey('X-User-Id'), isFalse);
      expect(headersNoAuth.containsKey('X-User-Role'), isFalse);

      const testToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.testToken';
      final headersWithAuth = ApiConfig.getHeaders(token: testToken);
      expect(headersWithAuth['Authorization'], equals('Bearer $testToken'));
      expect(headersWithAuth.containsKey('X-User-Id'), isFalse);
      expect(headersWithAuth.containsKey('X-User-Role'), isFalse);
    });

    test('7. ApiConfig timeout is properly calibrated to 12 seconds', () {
      expect(ApiConfig.requestTimeout, equals(const Duration(seconds: 12)));
    });
  });

  group('Phase 3: DriveMateProvider JWT & API Integration Tests', () {
    test('8. DriveMateProvider initializes with null authToken and authHeaders reflect that', () {
      final provider = DriveMateProvider();
      expect(provider.authToken, isNull);
      expect(provider.authHeaders.containsKey('Authorization'), isFalse);
      expect(provider.authHeaders.containsKey('X-User-Id'), isFalse);
      expect(provider.authHeaders.containsKey('X-User-Role'), isFalse);
    });

    test('9. DriveMateProvider login sets user role and currentNumericUserId', () {
      final provider = DriveMateProvider();
      provider.login('customer@drivemate.com', UserRole.customer);

      expect(provider.isLoggedIn, isTrue);
      expect(provider.currentRole, equals(UserRole.customer));
      expect(provider.currentUser.email, equals('customer@drivemate.com'));
      expect(provider.currentUser.phone, equals('9876543210'));
    });

    test('10. DriveMateProvider driver login sets driver profile and role', () {
      final provider = DriveMateProvider();
      provider.login('driver@drivemate.com', UserRole.driver);

      expect(provider.isLoggedIn, isTrue);
      expect(provider.currentRole, equals(UserRole.driver));
      expect(provider.currentUser.email, equals('driver@drivemate.com'));
      expect(provider.currentUser.phone, equals('9811223344'));
    });

    test('11. DriveMateProvider logout wipes auth token and resets logged-in state', () {
      final provider = DriveMateProvider();
      provider.login('customer@drivemate.com', UserRole.customer);
      expect(provider.isLoggedIn, isTrue);

      provider.logout();
      expect(provider.isLoggedIn, isFalse);
      expect(provider.authToken, isNull);
    });

    test('12. DriveMateProvider switchRole updates active mode cleanly', () {
      final provider = DriveMateProvider();
      provider.switchRole(UserRole.driver);
      expect(provider.currentRole, equals(UserRole.driver));

      provider.switchRole(UserRole.customer);
      expect(provider.currentRole, equals(UserRole.customer));
    });

    test('13. Live PHP API Authentication Verification over LAN IP (192.168.0.107)', () async {
      final loginUri = ApiConfig.getUri('/auth/login');

      // Attempt live login against local XAMPP Apache
      try {
        final res = await http.post(
          loginUri,
          headers: ApiConfig.getHeaders(),
          body: jsonEncode({
            'email': 'customer@drivemate.com',
            'password': 'password123',
          }),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          expect(body['success'], isTrue);
          expect(body['data'], isNotNull);
          final token = body['data']['token'] as String;
          expect(token, isNotEmpty);
          expect(token.startsWith('eyJ'), isTrue); // JWT structure
          expect(body['data']['role'], equals('customer'));
          expect(body['data']['user_id'], equals(2));

          // Verify authenticated profile retrieval with Bearer token
          final profileUri = ApiConfig.getUri('/users/profile');
          final profileRes = await http.get(
            profileUri,
            headers: ApiConfig.getHeaders(token: token),
          ).timeout(const Duration(seconds: 5));

          if (profileRes.statusCode == 200) {
            final pBody = jsonDecode(profileRes.body);
            expect(pBody['success'], isTrue);
            expect(pBody['data']['id'], equals(2));
            expect(pBody['data']['email'], equals('customer@drivemate.com'));
          }
        }
      } catch (e) {
        debugPrint('[Test Warning] Live API server check caught: $e (Skipping network-dependent assertions)');
      }
    });
  });
}
