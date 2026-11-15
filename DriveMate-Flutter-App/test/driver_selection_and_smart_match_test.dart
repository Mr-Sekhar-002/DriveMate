import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/customer/driver_selection_screen.dart';
import 'package:drivemate_flutter/components/driver_profile_sheet.dart';
import 'package:drivemate_flutter/components/driver_reviews_sheet.dart';
import 'package:drivemate_flutter/components/smart_match_result_dialog.dart';
import 'package:drivemate_flutter/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Driver Selection & Smart Auto Match Suite', () {
    testWidgets('1. DriverSelectionScreen renders UI elements, filter chips and smart match banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const DriverSelectionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and titles
      expect(find.text('Select Chauffeur'), findsOneWidget);
      expect(find.text('Verified Professional Drivers'), findsOneWidget);
      expect(find.text('Smart Auto Match'), findsOneWidget);
      expect(find.text('Match Now'), findsOneWidget);

      // Check filter options
      expect(find.text('🚗 All Drivers'), findsOneWidget);
      expect(find.text('⭐ Top Rated'), findsOneWidget);
      expect(find.text('📍 Nearest'), findsOneWidget);
      expect(find.text('🟢 Available Now'), findsOneWidget);

      // Search input field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('2. DriverProfileSheet displays complete telemetry, rating, and shields private phone', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final driver = EligibleDriver(
        id: 9,
        name: 'Amitava Roy (Chauffeur)',
        licenseNumber: 'DL-WB96-2019-003412',
        vehicleType: 'Sedan/SUV',
        vehicleModel: 'Hyundai Creta SX',
        avgRating: 4.9,
        totalTrips: 184,
        experienceYears: 6,
        distanceKm: 0.69,
        etaMinutes: 2,
        isOnline: true,
        isAvailable: true,
      );

      bool selected = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  DriverProfileSheet.show(
                    ctx,
                    driver: driver,
                    onSelect: () => selected = true,
                  );
                },
                child: const Text('Open Profile'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Profile'));
      await tester.pumpAndSettle();

      // Profile details
      expect(find.text('Amitava Roy (Chauffeur)'), findsOneWidget);
      expect(find.text('GOVERNMENT VERIFIED CHAUFFEUR'), findsOneWidget);
      expect(find.text('Hyundai Creta SX'), findsWidgets);

      final privacyNotice = find.text('Privacy Protected Communication');
      await tester.ensureVisible(privacyNotice);
      expect(privacyNotice, findsOneWidget);

      // Tap select
      final selectBtn = find.text('Select Amitava Roy (Chauffeur) & Continue');
      await tester.ensureVisible(selectBtn);
      await tester.tap(selectBtn);
      await tester.pumpAndSettle();
      expect(selected, true);
    });

    testWidgets('3. SmartMatchResultDialog renders 5-point weighted algorithm breakdown and accepts match', (tester) async {
      final matchedDriver = EligibleDriver(
        id: 3,
        name: 'Rajesh Kumar (Driver)',
        licenseNumber: 'DL-0420110055441',
        vehicleType: 'Sedan',
        vehicleModel: 'Maruti Suzuki Dzire VXI',
        avgRating: 5.0,
        totalTrips: 146,
        experienceYears: 5,
        distanceKm: 0.2,
        etaMinutes: 2,
        matchScore: 98.5,
        scoreBreakdown: {
          'availability_pts': 35.0,
          'distance_eta_pts': 29.5,
          'rating_pts': 20.0,
          'experience_pts': 9.0,
          'vehicle_fit_pts': 5.0,
        },
      );

      bool accepted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  SmartMatchResultDialog.show(
                    ctx,
                    driver: matchedDriver,
                    onAccept: () => accepted = true,
                    onTryAnother: () {},
                  );
                },
                child: const Text('Open Smart Match'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Smart Match'));
      await tester.pumpAndSettle();

      expect(find.text('SMART AUTO MATCHED'), findsOneWidget);
      expect(find.text('Rajesh Kumar (Driver)'), findsOneWidget);
      expect(find.text('FIT SCORE'), findsOneWidget);
      expect(find.text('98%'), findsOneWidget);
      expect(find.text('Availability (35% weight)'), findsOneWidget);
      expect(find.text('Distance & Arrival ETA (30% weight)'), findsOneWidget);
      expect(find.text('Genuine Customer Rating (20% weight)'), findsOneWidget);
      expect(find.text('Experience & Trips (10% weight)'), findsOneWidget);

      await tester.tap(find.text('Book Matched Chauffeur'));
      await tester.pumpAndSettle();
      expect(accepted, true);
    });

    testWidgets('4. DriverReviewsSheet renders genuine reviews from MySQL', (tester) async {
      final driver = EligibleDriver(
        id: 3,
        name: 'Rajesh Kumar',
        avgRating: 5.0,
        totalTrips: 146,
      );

      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => DriverReviewsSheet.show(ctx, driver),
                  child: const Text('Open Reviews'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Reviews'));
      await tester.pumpAndSettle();

      expect(find.text('Rajesh Kumar Reviews'), findsOneWidget);
      expect(find.text('5.0 Rating'), findsOneWidget);
    });

    test('5. DriveMateProvider driver selection and sorting state test', () {
      final provider = DriveMateProvider();

      expect(provider.eligibleDrivers, isEmpty);
      expect(provider.selectedDriver, isNull);
      expect(provider.driverSortFilter, 'top_rated');

      final sampleDriver = EligibleDriver(
        id: 3,
        name: 'Rajesh Kumar',
        avgRating: 5.0,
        totalTrips: 146,
      );

      provider.selectDriver(sampleDriver);
      expect(provider.selectedDriver?.id, 3);
      expect(provider.selectedDriver?.name, 'Rajesh Kumar');

      provider.setDriverSortFilter('nearest');
      expect(provider.driverSortFilter, 'nearest');

      provider.clearSelectedDriver();
      expect(provider.selectedDriver, isNull);
    });
  });
}
