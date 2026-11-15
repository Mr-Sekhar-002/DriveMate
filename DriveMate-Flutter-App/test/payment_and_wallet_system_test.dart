import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/customer/wallet_screen.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    ApiConfig.activeEnvironment = ApiEnvironment.local;
  });

  group('Feature 6: Payment & Wallet System Tests', () {
    late DriveMateProvider provider;

    setUp(() async {
      provider = DriveMateProvider();
      await provider.loginWithApi(
        email: 'customer@drivemate.com',
        password: 'password123',
        expectedRole: UserRole.customer,
      );
    });

    Widget createTestApp() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<DriveMateProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: WalletScreen(),
        ),
      );
    }

    test('1. WalletDetails and WalletTransactionItem models parse backend JSON correctly', () {
      final json = {
        'wallet_id': 1,
        'balance': 7150.0,
        'currency': 'INR',
        'transactions': [
          {
            'id': 101,
            'wallet_id': 1,
            'user_id': 2,
            'type': 'credit',
            'amount': 500.0,
            'reference_type': 'topup',
            'reference_id': 'TOP_TEST101',
            'description': 'Wallet Top-up via UPI',
            'balance_after': 7150.0,
            'created_at': '2026-11-12 18:00:00',
          },
          {
            'id': 102,
            'wallet_id': 1,
            'user_id': 2,
            'type': 'debit',
            'amount': 350.0,
            'reference_type': 'trip_fare',
            'reference_id': 'DM-BK-404',
            'description': 'Trip Fare Payment',
            'balance_after': 6800.0,
            'created_at': '2026-11-12 18:30:00',
          }
        ]
      };

      final wallet = WalletDetails.fromJson(json);
      expect(wallet.walletId, 1);
      expect(wallet.balance, 7150.0);
      expect(wallet.currency, 'INR');
      expect(wallet.transactions.length, 2);

      final creditTx = wallet.transactions.first;
      expect(creditTx.isCredit, isTrue);
      expect(creditTx.amount, 500.0);
      expect(creditTx.referenceType, 'topup');

      final debitTx = wallet.transactions.last;
      expect(debitTx.isCredit, isFalse);
      expect(debitTx.amount, 350.0);
    });

    testWidgets('2. WalletScreen renders balance card, action buttons, and payment modes', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DriveMate Wallet'), findsWidgets);
      expect(find.text('AVAILABLE BALANCE'), findsOneWidget);
      expect(find.text('Secure Ledger'), findsOneWidget);
      expect(find.text('ADD MONEY'), findsOneWidget);
      expect(find.text('WITHDRAW'), findsOneWidget);

      expect(find.text('Supported Payment Modes'), findsOneWidget);
      expect(find.text('UPI (GPay / PhonePe)'), findsOneWidget);
      expect(find.text('Cards (Visa / Master)'), findsOneWidget);
      expect(find.text('Net Banking'), findsOneWidget);
      expect(find.text('Cash on Trip'), findsOneWidget);

      expect(find.text('Transaction History'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget);
      expect(find.text('Debits'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('3. Tapping ADD MONEY opens modal sheet with quick amount chips', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final addBtn = find.text('ADD MONEY');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Add Money to Wallet'), findsOneWidget);
      expect(find.text('+₹200'), findsOneWidget);
      expect(find.text('+₹500'), findsOneWidget);
      expect(find.text('+₹1000'), findsOneWidget);
      expect(find.text('+₹2000'), findsOneWidget);
      expect(find.text('PROCEED TO ADD MONEY'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('4. Tapping WITHDRAW opens payout sheet with UPI and Bank transfer', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final withdrawBtn = find.text('WITHDRAW');
      expect(withdrawBtn, findsOneWidget);
      await tester.tap(withdrawBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Withdraw Funds / Payout'), findsOneWidget);
      expect(find.text('UPI Transfer'), findsOneWidget);
      expect(find.text('Bank Account'), findsOneWidget);
      expect(find.text('CONFIRM WITHDRAWAL'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    test('5. Backend API: fetchWalletDetails returns authoritative balance and ledger', () async {
      final details = await provider.fetchWalletDetails();
      expect(details, isNotNull);
      expect(details!.walletId, greaterThan(0));
      expect(details.currency, 'INR');
      expect(details.balance, greaterThanOrEqualTo(0.0));
    });

    test('6. Backend API: addWalletFunds tops up wallet balance authoritatively', () async {
      final initialBalance = provider.walletBalance;
      final success = await provider.addWalletFunds(200.0);
      expect(success, isTrue);
      expect(provider.walletBalance, greaterThanOrEqualTo(initialBalance + 200.0));
    });
  });
}
