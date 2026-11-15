import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/driver/driver_profile_screen.dart';
import 'package:drivemate_flutter/components/driver_profile_sheet.dart';

void main() {
  group('Feature 3: Professional Driver Profile & Document Verification Tests', () {
    test('DriverProfile JSON deserialization & KYC state flags', () {
      final json = {
        'id': '101',
        'user_id': '3',
        'name': 'Rajesh Kumar',
        'phone': '+91 98112 23344',
        'license_number': 'WB-962019003412',
        'experience_years': 6,
        'vehicle_type': 'Sedan',
        'vehicle_model': 'Maruti Suzuki Dzire',
        'vehicle_number': 'WB 02 B 1234',
        'languages': 'English, Hindi, Bengali',
        'bio': 'Experienced chauffeur with defensive driving certified.',
        'license_doc_path': 'uploads/documents/driver_3_license_123.jpg',
        'id_doc_path': 'uploads/documents/driver_3_identity_123.png',
        'rejection_reason': null,
        'hourly_rate': 160.0,
        'avg_rating': 4.92,
        'total_trips': 340,
        'today_net': 1500.0,
        'lifetime_net': 42000.0,
        'is_online': 1,
        'status': 'verified',
        'created_at': '2026-10-15',
      };

      final profile = DriverProfile.fromJson(json);
      expect(profile.driverName, 'Rajesh Kumar');
      expect(profile.licenseNumber, 'WB-962019003412');
      expect(profile.languages, 'English, Hindi, Bengali');
      expect(profile.experienceYears, 6);
      expect(profile.hourlyRate, 160.0);
      expect(profile.isVerified, isTrue);
      expect(profile.isPending, isFalse);
      expect(profile.isRejected, isFalse);
      expect(profile.licenseDocPath, contains('driver_3_license'));
      expect(profile.idDocPath, contains('driver_3_identity'));
    });

    test('EligibleDriver customer view parses languages, bio & verified status', () {
      final json = {
        'id': 3,
        'driver_name': 'Rajesh Kumar',
        'vehicle_type': 'Sedan',
        'vehicle_model': 'Honda City',
        'vehicle_number': 'WB 06 K 9988',
        'avg_rating': 4.88,
        'total_trips': 210,
        'experience_years': 7,
        'languages': 'English, Hindi',
        'bio': 'Specialist in airport transfers and outstation trips.',
        'hourly_rate': 150.0,
        'verification_status': 'verified',
        'is_online': 1,
      };

      final driver = EligibleDriver.fromJson(json);
      expect(driver.name, 'Rajesh Kumar');
      expect(driver.languages, 'English, Hindi');
      expect(driver.bio, contains('Specialist'));
      expect(driver.isVerified, isTrue);
      expect(driver.experienceYears, 7);
    });

    test('DriveMateProvider updates driver profile, KYC uploads & admin verification', () async {
      final provider = DriveMateProvider();

      // Initial state is verified
      expect(provider.driverProfile.isVerified, isTrue);

      // Upload DL Document -> Flips to pending
      final dlUploaded = await provider.uploadDriverKycDocument(
        docType: 'license',
        base64Data: 'ZmFrZV9kbF9kYXRh',
        fileName: 'test_dl.jpg',
      );
      expect(dlUploaded, isTrue);
      expect(provider.driverProfile.isPending, isTrue);
      expect(provider.driverProfile.licenseDocPath, isNotNull);

      // Update Profile Details
      final updated = await provider.updateDriverProfileDetails(
        languages: 'English, Bengali, Hindi',
        experienceYears: 9,
        hourlyRate: 180.0,
        bio: 'Senior VIP Chauffeur',
      );
      expect(updated, isTrue);
      expect(provider.driverProfile.languages, 'English, Bengali, Hindi');
      expect(provider.driverProfile.experienceYears, 9);
      expect(provider.driverProfile.hourlyRate, 180.0);
      expect(provider.driverProfile.bio, 'Senior VIP Chauffeur');

      // Admin rejection
      await provider.verifyDriverKycAdmin(
        driverId: 3,
        status: 'rejected',
        reason: 'Image blur',
      );
      expect(provider.driverProfile.isRejected, isTrue);
      expect(provider.driverProfile.rejectionReason, 'Image blur');

      // Admin verification
      await provider.verifyDriverKycAdmin(
        driverId: 3,
        status: 'verified',
      );
      expect(provider.driverProfile.isVerified, isTrue);
    });

    testWidgets('DriverProfileScreen renders header, KYC documents and toggles duty', (WidgetTester tester) async {
      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriveMateProvider>.value(
            value: provider,
            child: const DriverProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies driver name & rating
      expect(find.text(provider.driverProfile.driverName), findsOneWidget);
      expect(find.textContaining('KYC VERIFIED CHAUFFEUR'), findsWidgets);

      // Verifies KYC Document tiles exist
      expect(find.text('Driving License (DL)'), findsOneWidget);
      expect(find.text('Government Identity Proof (Aadhaar / Passport)'), findsOneWidget);

      // Verifies action buttons
      expect(find.text('Upload Document'), findsWidgets);
      expect(find.text('Switch to Customer Mode'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Verifies Duty online switch works
      expect(find.byType(Switch), findsOneWidget);
      final initialOnline = provider.driverProfile.isOnline;
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(provider.driverProfile.isOnline, !initialOnline);
    });

    testWidgets('DriverProfileSheet displays customer view with languages and verified badge', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final driver = EligibleDriver(
        id: 10,
        name: 'Amitava Roy',
        vehicleType: 'Sedan',
        vehicleModel: 'Maruti Suzuki Ciaz',
        vehicleNumber: 'WB 06 K 1234',
        avgRating: 4.95,
        totalTrips: 450,
        experienceYears: 8,
        languages: 'English, Bengali, Hindi',
        bio: 'Professional corporate chauffeur with defensive driving training.',
        verificationStatus: 'verified',
        isOnline: true,
      );

      bool selected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  DriverProfileSheet.show(
                    context,
                    driver: driver,
                    onSelect: () => selected = true,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verifies driver name and verified badge
      expect(find.text('Amitava Roy'), findsOneWidget);
      expect(find.text('GOVERNMENT VERIFIED CHAUFFEUR'), findsOneWidget);
      expect(find.text('Languages & Chauffeur Specialty'), findsOneWidget);
      expect(find.text('English, Bengali, Hindi'), findsOneWidget);
      expect(find.textContaining('Professional corporate chauffeur'), findsOneWidget);

      // Verifies vehicle information
      expect(find.text('Maruti Suzuki Ciaz'), findsOneWidget);
      expect(find.text('Privacy Protected Communication'), findsOneWidget);

      // Tap select
      final btnFinder = find.text('Select Amitava Roy & Continue');
      await tester.ensureVisible(btnFinder);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
    });
  });
}
