import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/support/help_support_screen.dart';
import 'package:drivemate_flutter/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Help & Support Feature Tests', () {
    testWidgets('Renders Help & Support screen with FAQs, 24x7 Helpline, and Tabs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: const MaterialApp(
            home: HelpSupportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify App Bar and Header Subtitle
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('24x7 Assistance & Support Center'), findsOneWidget);

      // 2. Verify Tabs
      expect(find.text('FAQs & Guide'), findsOneWidget);
      expect(find.textContaining('My Requests'), findsOneWidget);

      // 3. Verify Direct Contact Channels
      expect(find.text('Direct Operational Channels'), findsOneWidget);
      expect(find.text('24x7 Helpline'), findsOneWidget);
      expect(find.text('SOS Helpline'), findsOneWidget);

      // 4. Verify Report a Problem button
      expect(find.text('Report a Problem'), findsOneWidget);
    });

    testWidgets('Category chips filter FAQ topics and search filters questions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: const MaterialApp(
            home: HelpSupportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify category chips exist
      expect(find.text('All Topics'), findsOneWidget);
      expect(find.text('Booking Support'), findsOneWidget);
      expect(find.text('Payment & Invoice'), findsOneWidget);
      expect(find.text('Trip & Live Route'), findsOneWidget);
      expect(find.text('Driver & Safety'), findsOneWidget);
      expect(find.text('App / General'), findsOneWidget);

      // Tap on Payment & Invoice chip
      await tester.tap(find.text('Payment & Invoice'));
      await tester.pumpAndSettle();

      // Verify search input
      await tester.enterText(find.byType(TextField).first, 'nonexistent query 123');
      await tester.pumpAndSettle();

      // Empty search state displayed
      expect(find.text('No matching articles found'), findsOneWidget);
    });

    testWidgets('Role-based navigation: Customer and Driver see Help & Support icon, not Blueprint', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = DriveMateProvider();

      // 1. Customer role logged in
      provider.login('rajesh.das@drivemate.in', UserRole.customer);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: const DriveMateApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Customer must see Help & Support icon
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      // Customer must NOT see Architecture Blueprint tree icon
      expect(find.byIcon(Icons.account_tree_outlined), findsNothing);

      // 2. Driver role
      provider.switchRole(UserRole.driver);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Driver must see Help & Support icon
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      // Driver must NOT see Architecture Blueprint tree icon
      expect(find.byIcon(Icons.account_tree_outlined), findsNothing);

      // 3. Admin role
      provider.switchRole(UserRole.admin);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Admin CAN see Blueprint & Architecture Inspector
      expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);
      // Admin does not see the customer/driver help button
      expect(find.byIcon(Icons.help_outline), findsNothing);

      // Let the switchRole toast timer expire cleanly
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
