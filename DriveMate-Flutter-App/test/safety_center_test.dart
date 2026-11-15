import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/safety/safety_center_screen.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    ApiConfig.activeEnvironment = ApiEnvironment.local;
  });

  group('Feature 5: Safety Center & SOS Emergency System Tests', () {
    late DriveMateProvider provider;

    setUp(() {
      provider = DriveMateProvider();
    });

    Widget createTestApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: SafetyCenterScreen(),
        ),
      );
    }

    testWidgets('1. SafetyCenterScreen renders SOS button, rapid helplines, and contacts section', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Safety Center title
      expect(find.text('Safety Center'), findsOneWidget);
      expect(find.text('24/7 Monitored'), findsOneWidget);

      // Verify One-Touch SOS Alert Button
      expect(find.text('SOS ALERT'), findsOneWidget);
      expect(find.text('One-Touch Emergency SOS'), findsOneWidget);

      // Verify Rapid Helplines Grid
      expect(find.text('Rapid Helplines'), findsOneWidget);
      expect(find.text('Police Emergency'), findsOneWidget);
      expect(find.text('112'), findsOneWidget);
      expect(find.text('Medical / Ambulance'), findsOneWidget);
      expect(find.text('108'), findsOneWidget);
      expect(find.text('Women Helpline'), findsOneWidget);
      expect(find.text('1091'), findsOneWidget);
      expect(find.text('DriveMate 24/7 Desk'), findsOneWidget);

      // Verify Trusted Contacts section
      expect(find.text('Trusted Contacts'), findsOneWidget);

      // Verify Report Safety Issue card
      expect(find.text('Report a Ride Safety Issue'), findsOneWidget);
      expect(find.text('Report Now'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('2. Tapping SOS Alert button presents Confirmation Dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final sosBtn = find.text('SOS ALERT');
      expect(sosBtn, findsOneWidget);
      await tester.tap(sosBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Emergency SOS Dialog
      expect(find.text('Activate SOS Emergency?'), findsOneWidget);
      expect(find.text('CONFIRM EMERGENCY SOS'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Activate SOS Emergency?'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('3. Adding and deleting emergency contact updates list dynamically', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Add contact via runAsync so real socket doesn't block fake async clock
      await tester.runAsync(() async {
        await provider.addEmergencyContact('Rajesh Sharma', '9876543210', 'Parent');
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);

      // Find delete button
      final deleteBtn = find.byIcon(Icons.delete_outline);
      expect(deleteBtn, findsWidgets);

      await tester.runAsync(() async {
        await provider.deleteEmergencyContact(provider.emergencyContacts.first.id);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Contact was removed
      expect(provider.emergencyContacts.any((c) => c.name == 'Rajesh Sharma'), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('4. Report a Ride Safety Issue opens bottom sheet and displays incident categories', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final reportBtn = find.text('Report Now');
      await tester.ensureVisible(reportBtn);
      await tester.tap(reportBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Report Safety Issue'), findsOneWidget);
      expect(find.text('Incident Category'), findsOneWidget);
      expect(find.text('Route Deviation'), findsOneWidget);
      expect(find.text('Driver Misbehavior'), findsOneWidget);
      expect(find.text('SUBMIT INCIDENT REPORT'), findsOneWidget);

      // Close modal sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    test('5. Backend Authoritative SOS Dispatch returns police 112 hotline and registered contacts', () async {
      final dispatch = await provider.triggerSosEmergency(
        notes: 'Integration Test Emergency Alert',
      );

      expect(dispatch, isNotNull);
      expect(dispatch!.status, anyOf('DISPATCHED', 'SUCCESS'));
      expect(dispatch.policeHelpline, '112');
      expect(dispatch.ambulanceHelpline, '108');
      expect(dispatch.womenSafetyHelpline, '1091');
      expect(dispatch.controlRoom, contains('99999'));
      expect(dispatch.instructions.isNotEmpty, isTrue);
    });

    test('6. Reporting safety issue communicates successfully with backend', () async {
      final success = await provider.reportSafetyIssue(
        category: 'Route Deviation',
        description: 'Test ride driver deviated from primary route corridor',
      );
      expect(success, isTrue);
    });
  });
}
