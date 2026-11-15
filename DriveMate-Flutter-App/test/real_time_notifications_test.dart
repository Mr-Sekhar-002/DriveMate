import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/notifications/notification_center_screen.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    ApiConfig.activeEnvironment = ApiEnvironment.local;
  });

  group('Feature 7: Real-Time Notifications Tests', () {
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
          home: NotificationCenterScreen(),
        ),
      );
    }

    testWidgets('1. NotificationCenterScreen renders categories, items, and action controls', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Notification Center'), findsOneWidget);
      expect(find.text('Real-Time Ride Alerts & Pushes'), findsOneWidget);

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Rides'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Safety'), findsOneWidget);
      expect(find.text('Offers'), findsOneWidget);

      // Verify at least one default notification exists
      expect(find.textContaining('Chauffeur Amitava'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('2. Notification settings bottom sheet toggles sound and vibration', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final settingsBtn = find.byIcon(Icons.tune_rounded);
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Notification Settings'), findsOneWidget);
      expect(find.text('Sound Alerts'), findsOneWidget);
      expect(find.text('Haptic Vibration'), findsOneWidget);
      expect(find.text('SAVE PREFERENCES'), findsOneWidget);

      // Toggle sound switch
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));
      await tester.tap(switches.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Close modal
      await tester.tap(find.text('SAVE PREFERENCES'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Notification Settings'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('3. Category filter chips filter notifications dynamically', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Payments filter
      await tester.tap(find.text('Payments'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show Payment notification
      expect(find.textContaining('Payment Confirmed'), findsOneWidget);

      // Tap All filter to restore
      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Chauffeur Amitava'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    test('4. Adding push notification broadcasts new event to notification ledger', () {
      final initialCount = provider.notifications.length;
      provider.addPushNotification(
        type: 'trip',
        title: 'Chauffeur Arrived at Kakdwip Gate 2',
        message: 'Your chauffeur is waiting at the designated pickup zone.',
      );

      expect(provider.notifications.length, initialCount + 1);
      expect(provider.notifications.first.title, contains('Kakdwip Gate 2'));
      expect(provider.notifications.first.isRead, isFalse);

      // Mark all read
      provider.markNotificationsRead();
      expect(provider.notifications.every((n) => n.isRead), isTrue);

      // Delete the first notification
      final firstId = provider.notifications.first.id;
      provider.deleteNotification(firstId);
      expect(provider.notifications.any((n) => n.id == firstId), isFalse);
    });
  });
}
