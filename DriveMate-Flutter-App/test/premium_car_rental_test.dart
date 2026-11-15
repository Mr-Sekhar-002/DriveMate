import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/components/car_details_sheet.dart';
import 'package:drivemate_flutter/components/vehicle_inspection_sheet.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/customer/rent_car_flow_screen.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    ApiConfig.activeEnvironment = ApiEnvironment.local;
  });

  group('Feature 8: Premium Car Rental & Inspection Tests', () {
    late DriveMateProvider provider;

    setUp(() {
      provider = DriveMateProvider();
    });

    Widget createRentCarApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: RentCarFlowScreen(),
        ),
      );
    }

    testWidgets('1. RentCarFlowScreen renders categories, search, and listings', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createRentCarApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rental Fleet'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Sedan'), findsOneWidget);
      expect(find.text('SUV'), findsOneWidget);
      expect(find.text('Luxury'), findsOneWidget);
      expect(find.text('Electric'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('2. CarDetailsSheet renders vehicle specs, security deposit, and inspect shortcut', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final listing = provider.carListings.first;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CarDetailsSheet(listing: listing),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(listing.vehicle.model), findsWidgets);
      expect(find.text('Refundable Security Deposit:'), findsOneWidget);
      expect(find.text('Pre-Rental Handover Inspection'), findsOneWidget);
      expect(find.text('Inspect'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('3. VehicleInspectionSheet renders odometer, fuel gauge, 5-point checklist and confirms handover', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final vehicle = provider.carListings.first.vehicle;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VehicleInspectionSheet(vehicle: vehicle),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Digital Vehicle Inspection'), findsOneWidget);
      expect(find.text('1. Telemetry & Fuel Level'), findsOneWidget);
      expect(find.text('2. 5-Point Physical Inspection'), findsOneWidget);
      expect(find.text('Exterior Body & Paintwork'), findsOneWidget);
      expect(find.text('Tyres, Spare & Tool Kit'), findsOneWidget);
      expect(find.text('Lighting & Indicators'), findsOneWidget);
      expect(find.text('Air Conditioning & Infotainment'), findsOneWidget);
      expect(find.text('In-Car Documents Present'), findsOneWidget);

      expect(find.text('Report Pre-Existing Scratch / Dent'), findsOneWidget);

      // Confirm inspection
      final confirmBtn = find.text('CONFIRM DIGITAL INSPECTION');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });
  });
}
