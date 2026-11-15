import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/customer/active_trip_tracking_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PlatformDispatcher.instance.onError = (error, stack) {
      if (error.toString().contains('tile.openstreetmap.org') ||
          error.toString().contains('ClientException')) {
        return true;
      }
      return false;
    };
  });

  group('Feature 2: Advanced Live Tracking Tests', () {
    late DriveMateProvider provider;

    setUp(() {
      provider = DriveMateProvider();
      // Setup a realistic active trip for live tracking
      provider.setActiveTrip(
        Trip(
          id: 'TRIP-101',
          bookingId: '101',
          driverId: '9',
          driverName: 'Rajesh Sharma',
          driverPhone: '+91 98765 43210',
          vehicleModel: 'Toyota Innova Crysta (WB 02 AM 4421)',
          startLocation: 'Salt Lake Sector V, Kolkata',
          startLat: 22.5850,
          startLng: 88.4230,
          endLocation: 'Kolkata Airport (CCU), Terminal 2',
          endLat: 22.6520,
          endLng: 88.4463,
          currentLat: 22.6010,
          currentLng: 88.4310,
          bearing: 42.0,
          startTime: '2026-11-12 17:00:00',
          distanceKm: 14.5,
          fare: 450.0,
          status: TripStatus.onTrip,
          currentProgress: 0.5,
          otp: '4821',
        ),
      );
    });

    tearDown(() {
      provider.stopDriverLiveTracking();
    });

    testWidgets('1. ActiveTripTrackingScreen renders top navigation bar, destination, emergency hotline, and quick actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriveMateProvider>.value(
            value: provider,
            child: const ActiveTripTrackingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top navigation bar elements
      expect(find.text('Salt Lake Sector V, Kolkata'), findsOneWidget);
      expect(find.text('Kolkata Airport (CCU), Terminal 2'), findsOneWidget);
      expect(find.textContaining('Emergency:'), findsOneWidget);
      expect(find.textContaining('14.5 km'), findsWidgets);

      // Overhang quick action buttons (Chat with unread badge & Call)
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Unread badge
      expect(find.byIcon(Icons.phone_in_talk), findsOneWidget);

      // Chauffeur profile card
      expect(find.text('Rajesh Sharma'), findsOneWidget);
      expect(find.text('Toyota Innova Crysta (WB 02 AM 4421)'), findsOneWidget);
      expect(find.text('4821'), findsOneWidget); // OTP

      // Floating map action buttons
      expect(find.byIcon(Icons.crop_free), findsOneWidget);
      expect(find.byIcon(Icons.navigation), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsWidgets);
    });

    testWidgets('2. Fullscreen map toggle hides controls and shows exit button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriveMateProvider>.value(
            value: provider,
            child: const ActiveTripTrackingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap fullscreen map toggle
      final fullscreenBtn = find.byTooltip('Full Screen Map');
      expect(fullscreenBtn, findsOneWidget);
      await tester.tap(fullscreenBtn);
      await tester.pumpAndSettle();

      // In fullscreen mode, the top header is hidden and Show Controls button appears
      expect(find.text('Show Controls'), findsOneWidget);

      // Tapping Show Controls restores the docked navigation UI
      await tester.tap(find.text('Show Controls'));
      await tester.pumpAndSettle();

      expect(find.text('Show Controls'), findsNothing);
      expect(find.text('Kolkata Airport (CCU), Terminal 2'), findsOneWidget);
    });

    testWidgets('3. In-Trip Chat modal opens with preset chips and allows sending messages', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriveMateProvider>.value(
            value: provider,
            child: const ActiveTripTrackingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Chat button
      final chatBtn = find.byIcon(Icons.chat_bubble_outline_rounded);
      await tester.tap(chatBtn);
      await tester.pumpAndSettle();

      // Modal appears
      expect(find.text('Chat with Rajesh Sharma'), findsOneWidget);
      expect(find.text("I'm at the pickup point"), findsOneWidget);

      // Tap preset chip
      await tester.tap(find.text("I'm at the pickup point"));
      await tester.pumpAndSettle();

      expect(find.text("I'm at the pickup point"), findsWidgets);

      // Type and send custom message
      await tester.enterText(find.byType(TextField), 'Please turn on the AC');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Please turn on the AC', skipOffstage: false), findsOneWidget);
    });

    testWidgets('4. Share Live Trip with Family opens bottom sheet with WhatsApp and SMS actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriveMateProvider>.value(
            value: provider,
            child: const ActiveTripTrackingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Share Trip button
      final shareBtn = find.text('Share Trip');
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      // Share modal appears
      expect(find.text('Share Live Trip with Family'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS Text'), findsOneWidget);
      expect(find.text('Copy Tracking Link'), findsOneWidget);
    });

    testWidgets('5. Safety SOS button triggers emergency security alert dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriveMateProvider>.value(
            value: provider,
            child: const ActiveTripTrackingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap SOS button in bottom controls
      final sosBtn = find.text('SOS');
      expect(sosBtn, findsOneWidget);
      await tester.tap(sosBtn);
      await tester.pumpAndSettle();

      // SOS dialog appears
      expect(find.text('Emergency SOS'), findsOneWidget);
      expect(find.text('Call 112 & Alert SOS'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Emergency SOS'), findsNothing);
    });
  });
}
