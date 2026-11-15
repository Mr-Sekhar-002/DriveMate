import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/support/help_support_screen.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    ApiConfig.activeEnvironment = ApiEnvironment.local;
  });

  group('Feature 10: Customer Support & Live Dispute Resolution Tests', () {
    test('1. SupportContact, SupportFaq, and SupportTicket models parse backend JSON accurately', () {
      final contactJson = {
        'helpline': '+91 98000 11223',
        'toll_free': '1800-DRIVEMATE',
        'emergency': '112',
        'email': 'support@drivemate.com',
        'office': 'Station Road, Kakdwip Central, WB 743347',
        'hours': '24x7 Customer Support & Emergency Dispatch',
      };
      final contact = SupportContact.fromJson(contactJson);
      expect(contact.helpline, '+91 98000 11223');
      expect(contact.tollFree, '1800-DRIVEMATE');
      expect(contact.emergency, '112');
      expect(contact.email, 'support@drivemate.com');

      final faqJson = {
        'id': 1,
        'category': 'booking',
        'question': 'How do I hire a verified chauffeur?',
        'answer': 'Select "Hire a Driver" from your home dashboard.',
      };
      final faq = SupportFaq.fromJson(faqJson);
      expect(faq.id, 1);
      expect(faq.category, 'booking');
      expect(faq.question, contains('chauffeur'));

      final ticketJson = {
        'id': 101,
        'user_id': 2,
        'booking_id': 45,
        'subject': 'Fare calculation dispute',
        'category': 'payment',
        'message': 'Driver took an alternative long route without notification',
        'status': 'open',
        'created_at': '2026-11-12 18:30:00',
        'admin_reply': null,
      };
      final ticket = SupportTicket.fromJson(ticketJson);
      expect(ticket.id, 101);
      expect(ticket.category, 'payment');
      expect(ticket.status, 'open');
      expect(ticket.bookingId, 45);
    });

    testWidgets('2. HelpSupportScreen renders tabs, search bar, and contact action strip', (tester) async {
      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriveMateProvider>.value(
            value: provider,
            child: const HelpSupportScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('FAQs & Guide'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Topics'), findsOneWidget);
      expect(find.text('Booking Support'), findsOneWidget);
      expect(find.text('Payment & Invoice'), findsOneWidget);
      expect(find.text('Report a Problem'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('3. HelpSupportScreen category chip switching and search filtering works', (tester) async {
      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriveMateProvider>.value(
            value: provider,
            child: const HelpSupportScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on 'Payment & Invoice' category chip
      final paymentChip = find.text('Payment & Invoice');
      expect(paymentChip, findsOneWidget);
      await tester.tap(paymentChip);
      await tester.pump();

      // Enter search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'OTP');
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('4. Tapping "Report a Problem" FAB opens create ticket modal bottom sheet', (tester) async {
      final provider = DriveMateProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<DriveMateProvider>.value(
            value: provider,
            child: const HelpSupportScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap FAB
      final fab = find.text('Report a Problem');
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify modal content
      expect(find.text('Report a Problem / Support Request'), findsOneWidget);
      expect(find.text('ISSUE CATEGORY'), findsOneWidget);
      expect(find.text('SUBJECT'), findsOneWidget);
      expect(find.text('DETAILED DESCRIPTION'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    test('5. Backend API: fetchFaqsAndContact retrieves authoritative contact & FAQ entries', () async {
      final provider = DriveMateProvider();
      await provider.fetchFaqsAndContact();

      expect(provider.faqs.isNotEmpty, true);
      expect(provider.supportContact != null, true);
      expect(provider.supportContact!.helpline, contains('98000'));
    });

    test('6. Backend API: createSupportTicket submits ticket and fetches myTickets authoritatively', () async {
      final provider = DriveMateProvider();
      final loginSuccess = await provider.loginWithApi(
        email: 'customer@drivemate.com',
        password: 'password123',
        expectedRole: UserRole.customer,
      );
      expect(loginSuccess, true);

      final success = await provider.createSupportTicket(
        subject: 'Automated Test Ticket - App Latency',
        category: 'app',
        message: 'Verifying automated customer support flow and status dispatch.',
      );
      expect(success, true);

      await provider.fetchMyTickets();
      expect(provider.myTickets.isNotEmpty, true);
      final hasOurTicket = provider.myTickets.any((t) => t.subject.contains('Automated Test Ticket'));
      expect(hasOurTicket, true);
    });
  });
}
