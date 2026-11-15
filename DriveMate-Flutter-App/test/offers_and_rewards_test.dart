import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drivemate_flutter/config/api_config.dart';
import 'package:drivemate_flutter/models/drivemate_models.dart';
import 'package:drivemate_flutter/providers/drivemate_provider.dart';
import 'package:drivemate_flutter/screens/customer/offers_rewards_screen.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    ApiConfig.activeEnvironment = ApiEnvironment.local;
  });

  group('Feature 9: Offers & Rewards Tests', () {
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
          home: OffersRewardsScreen(),
        ),
      );
    }

    test('1. PromotionOffer and UserRewardsData models parse backend JSON accurately', () {
      final promoJson = {
        'id': 1,
        'code': 'WELCOME50',
        'title': '50% Off First Booking',
        'description': 'Save 50% on first trip',
        'discount_type': 'percentage',
        'discount_value': 50.0,
        'min_order_amount': 100.0,
        'max_discount_cap': 150.0,
      };

      final promo = PromotionOffer.fromJson(promoJson);
      expect(promo.code, 'WELCOME50');
      expect(promo.discountType, 'percentage');
      expect(promo.discountValue, 50.0);
      expect(promo.maxDiscountCap, 150.0);

      final rewardJson = {
        'referral_code': 'DRIVE-CUST101',
        'reward_points': 350,
        'points_value_inr': 350.0,
        'lifetime_points_earned': 500,
        'referrals_count': 2,
        'referral_bonus_inr': 150.0,
        'share_message': 'Use my referral code DRIVE-CUST101',
      };

      final rewards = UserRewardsData.fromJson(rewardJson);
      expect(rewards.referralCode, 'DRIVE-CUST101');
      expect(rewards.rewardPoints, 350);
      expect(rewards.pointsValueInr, 350.0);
      expect(rewards.referralsCount, 2);
    });

    testWidgets('2. OffersRewardsScreen renders rewards card, referral box, and promo coupons', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Offers & Rewards'), findsOneWidget);
      expect(find.text('DRIVEMATE REWARDS'), findsOneWidget);
      expect(find.text('REDEEM POINTS TO WALLET'), findsOneWidget);

      expect(find.text('Refer a Friend & Earn ₹150'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);

      expect(find.text('Exclusive Promo Coupons'), findsOneWidget);
      expect(find.text('WELCOME50'), findsOneWidget);
      expect(find.text('DRIVE10'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('3. Tapping REDEEM POINTS TO WALLET opens conversion sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final redeemBtn = find.text('REDEEM POINTS TO WALLET');
      expect(redeemBtn, findsOneWidget);
      await tester.tap(redeemBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Redeem Reward Points'), findsOneWidget);
      expect(find.text('50 pts\n₹50'), findsOneWidget);
      expect(find.text('100 pts\n₹100'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    test('4. Backend API: fetchPromotions returns active authoritative promotions', () async {
      final promos = await provider.fetchPromotions();
      expect(promos.isNotEmpty, isTrue);
      expect(promos.any((p) => p.code == 'WELCOME50'), isTrue);
    });

    test('5. Backend API: fetchUserRewards returns referral code and points', () async {
      final rewards = await provider.fetchUserRewards();
      expect(rewards, isNotNull);
      expect(rewards!.referralCode.isNotEmpty, isTrue);
      expect(rewards.rewardPoints, greaterThan(0));
    });

    test('6. Backend API: redeemRewardPoints converts points to wallet cash authoritatively', () async {
      final success = await provider.redeemRewardPoints(50);
      expect(success, isTrue);
    });
  });
}
