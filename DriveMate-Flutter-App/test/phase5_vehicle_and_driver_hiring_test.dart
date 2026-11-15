import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/customer/rent_car_flow_screen.dart';
import 'package:drivemate_flutter/components/car_details_sheet.dart';
import 'package:drivemate_flutter/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5: Vehicle Listing & Car Details Sheet Suite', () {
    testWidgets('1. RentCarFlowScreen renders categories, search bar and car cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
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
            home: const RentCarFlowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and categories
      expect(find.text('Rental Fleet'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Hatchback'), findsOneWidget);
      expect(find.text('Sedan'), findsOneWidget);
      expect(find.text('SUV'), findsOneWidget);
      expect(find.text('Luxury'), findsOneWidget);

      // Check search bar
      expect(find.byType(TextField), findsOneWidget);

      // Check prominent vehicles present
      expect(find.text('Honda City'), findsOneWidget);
      expect(find.text('BMW 3 Series'), findsWidgets);
      expect(find.text('Maruti Suzuki Swift 2024'), findsOneWidget);
    });

    testWidgets('2. Searching in RentCarFlowScreen filters fleet dynamically', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
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
            home: const RentCarFlowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Type "Swift" in search bar
      await tester.enterText(find.byType(TextField), 'Swift');
      await tester.pumpAndSettle();

      expect(find.text('Maruti Suzuki Swift 2024'), findsOneWidget);
      expect(find.text('Honda City'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Honda City'), findsOneWidget);
    });

    testWidgets('3. CarDetailsSheet displays 3-point telemetry, specs and calculates duration fare', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final provider = DriveMateProvider();
      final sampleListing = provider.carListings.first;

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
                  onPressed: () => CarDetailsSheet.show(ctx, sampleListing),
                  child: const Text('Open Car Details'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap open button
      await tester.tap(find.text('Open Car Details'));
      await tester.pumpAndSettle();

      // Verify Car Details header
      expect(find.text('Car Details'), findsOneWidget);
      expect(find.text('Power'), findsOneWidget);
      expect(find.text('Max Speed'), findsOneWidget);
      expect(find.text('Acceleration'), findsOneWidget);
      expect(find.text("Rental's Description"), findsOneWidget);
      expect(find.text('Units Available'), findsOneWidget);
      expect(find.text('Vehicle Specifications'), findsOneWidget);
      expect(find.text('Rent This Vehicle'), findsOneWidget);

      // Tap 5 days duration
      await tester.tap(find.text('5 d'));
      await tester.pumpAndSettle();

      // Verify calculated total
      final expectedTotal = (5 * sampleListing.dailyRate.toInt()) + 500;
      expect(find.text('₹$expectedTotal'), findsOneWidget);
    });
  });
}
