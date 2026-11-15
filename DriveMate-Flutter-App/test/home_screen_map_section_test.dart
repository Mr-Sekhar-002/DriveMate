import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/components/interactive_route_map_preview.dart';
import 'package:drivemate_flutter/screens/customer/full_screen_map_screen.dart';
import 'package:drivemate_flutter/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PlatformDispatcher.instance.onError = (error, stack) {
      if (error.toString().contains('tile.openstreetmap.org') ||
          error.toString().contains('ClientException')) {
        return true; // Mark as handled so headless test runner doesn't fail on network tiles
      }
      return false;
    };
  });

  group('Home Screen Interactive Route Map Section Tests', () {
    testWidgets('1. InteractiveRouteMapPreview renders map, controls, and route info card', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = DriveMateProvider();
      await provider.refreshRouteAndFare();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: InteractiveRouteMapPreview(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check floating map controls
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);

      // Check Map Style indicator
      expect(find.text('Standard'), findsOneWidget);

      // Check Route Information Card fields
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Est. Duration'), findsOneWidget);
      expect(find.text('Est. Fare'), findsOneWidget);
      expect(find.textContaining('km'), findsWidgets);
      expect(find.textContaining('mins'), findsWidgets);

      // Check pickup & destination markers / labels
      expect(find.text('PICKUP'), findsOneWidget);
      expect(find.text('DESTINATION'), findsOneWidget);
    });

    testWidgets('2. Tapping map style button cycles style', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: InteractiveRouteMapPreview(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Standard'), findsOneWidget);

      // Tap to cycle style
      await tester.tap(find.text('Standard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('3. Alternative route selection switches active route option', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = DriveMateProvider();
      await provider.refreshRouteAndFare();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: InteractiveRouteMapPreview(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check Route Options header
      expect(find.text('Route Options:'), findsOneWidget);
      expect(find.text('Via NH 117 / Diamond Harbour Rd'), findsOneWidget);
      expect(find.text('Via Kulpi - Kakdwip Bypass'), findsOneWidget);

      // Initial route index should be 0
      expect(provider.selectedRouteIndex, 0);

      // Tap alternative route
      await tester.tap(find.text('Via Kulpi - Kakdwip Bypass'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(provider.selectedRouteIndex, 1);
    });

    testWidgets('4. FullScreenMapScreen renders full-screen map with controls and route sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final provider = DriveMateProvider();
      await provider.refreshRouteAndFare();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const FullScreenMapScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('PICKUP'), findsOneWidget);
      expect(find.text('DESTINATION'), findsOneWidget);
      expect(find.text('Proceed with this Route'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      tester.takeException();
    });
  });
}
