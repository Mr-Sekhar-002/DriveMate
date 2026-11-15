import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class OffersRewardsScreen extends StatefulWidget {
  const OffersRewardsScreen({super.key});

  @override
  State<OffersRewardsScreen> createState() => _OffersRewardsScreenState();
}

class _OffersRewardsScreenState extends State<OffersRewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriveMateProvider>().fetchPromotions();
      context.read<DriveMateProvider>().fetchUserRewards();
    });
  }

  void _showRedeemSheet(BuildContext context, DriveMateProvider provider, int availablePoints) {
    int pointsToRedeem = 50;
    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    final sheetBg = isDark ? AppColors.darkCardBg : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;
    final unselectedPillBg = isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: borderSubtle)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Redeem Reward Points', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Convert points to DriveMate Wallet cash (1 Point = ₹1.00)', style: TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Text('Available Balance: $availablePoints Points', style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                children: [50, 100, 200, 300].map((pts) {
                  final isSel = pointsToRedeem == pts;
                  final isEnabled = availablePoints >= pts;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isSel ? AppColors.accentCyan : borderSubtle),
                          backgroundColor: isSel ? AppColors.accentCyan.withOpacity(0.15) : unselectedPillBg,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isEnabled ? () => setSheetState(() => pointsToRedeem = pts) : null,
                        child: Text(
                          '$pts pts\n₹$pts',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isEnabled ? (isSel ? AppColors.accentCyan : textPrimary) : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await provider.redeemRewardPoints(pointsToRedeem);
                  },
                  child: Text('CONVERT $pointsToRedeem PTS TO ₹$pointsToRedeem CASH', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final rewards = provider.userRewards;
    final promotions = provider.promotions;
    final rewardPoints = rewards?.rewardPoints ?? 150;
    final referralCode = rewards?.referralCode ?? 'DRIVE-CUST101';

    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    final pageBg = isDark ? AppColors.darkBg : AppColors.page;
    final cardBg = isDark ? AppColors.darkCardBg : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;
    final elevatedBg = isDark ? AppColors.darkCardElevated : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
        title: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded, color: AppColors.accentCyan, size: 22),
            const SizedBox(width: 8),
            Text('Offers & Rewards', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // REWARDS CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF831843), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DRIVEMATE REWARDS', style: TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.pinkAccent.withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars_rounded, color: Colors.pinkAccent, size: 14),
                            SizedBox(width: 4),
                            Text('Tier: Gold', style: TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$rewardPoints', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      const Text('Points', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('Worth ₹$rewardPoints.00', style: const TextStyle(color: AppColors.accentCyan, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Earn 10 points for every ₹100 spent on completed rides & rentals.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.currency_rupee, size: 16),
                      label: const Text('REDEEM POINTS TO WALLET', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _showRedeemSheet(context, provider, rewardPoints),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // REFERRAL SYSTEM CARD
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.share_arrival_time_outlined, color: AppColors.accentCyan, size: 22),
                      const SizedBox(width: 10),
                      Text('Refer a Friend & Earn ₹150', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your friend gets ₹150 off their first booking. You earn 150 points once their first trip is completed!',
                    style: TextStyle(color: textSecondary, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: elevatedBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(referralCode, style: const TextStyle(color: AppColors.accentCyan, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                              const Icon(Icons.copy, color: AppColors.textMuted, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () {
                          provider.showToast('Referral code $referralCode copied to clipboard!');
                        },
                        child: const Text('COPY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // PROMO COUPONS SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Exclusive Promo Coupons', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                if (provider.appliedPromoCode != null)
                  TextButton.icon(
                    onPressed: () => provider.clearPromoCode(),
                    icon: const Icon(Icons.close, size: 14, color: AppColors.errorRed),
                    label: Text('Remove (${provider.appliedPromoCode})', style: const TextStyle(color: AppColors.errorRed, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Active Coupon Banner if applied
            if (provider.appliedPromoCode != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.successGreen.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.successGreen, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Coupon "${provider.appliedPromoCode}" active: ₹${provider.appliedDiscountAmount.toStringAsFixed(2)} discount applied to booking fare.',
                        style: const TextStyle(color: AppColors.successGreen, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            if (promotions.isEmpty)
              ...[
                PromotionOffer(id: 1, code: 'WELCOME50', title: '50% Off First Booking', description: 'Get 50% discount up to ₹150 on your first trip', discountType: 'percentage', discountValue: 50.0, maxDiscountCap: 150.0),
                PromotionOffer(id: 2, code: 'DRIVE10', title: 'Flat 10% Off All Rides', description: 'Save 10% on every ride across West Bengal', discountType: 'percentage', discountValue: 10.0, maxDiscountCap: 100.0),
                PromotionOffer(id: 3, code: 'FLAT100', title: 'Flat ₹100 Off Mega Saver', description: 'Instant ₹100 discount on bookings above ₹500', discountType: 'flat', discountValue: 100.0, minOrderAmount: 500.0),
                PromotionOffer(id: 4, code: 'SUPER200', title: '₹200 Off Outstation Trips', description: 'Exclusive ₹200 off on round-trip rentals', discountType: 'flat', discountValue: 200.0, minOrderAmount: 1000.0),
              ].map((promo) => _buildPromoCard(context, provider, promo))
            else
              ...promotions.map((promo) => _buildPromoCard(context, provider, promo)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCard(BuildContext context, DriveMateProvider provider, PromotionOffer promo) {
    final isApplied = provider.appliedPromoCode == promo.code;
    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    final cardBg = isDark ? AppColors.darkCardBg : Colors.white;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isApplied ? AppColors.successGreen : borderSubtle, width: isApplied ? 1.5 : 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isApplied ? AppColors.successGreen.withOpacity(0.12) : AppColors.accentCyan.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(isApplied ? Icons.check_circle : Icons.local_offer_rounded, color: isApplied ? AppColors.successGreen : AppColors.accentCyan, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(promo.code, style: TextStyle(color: isApplied ? AppColors.successGreen : AppColors.accentCyan, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        promo.discountType == 'percentage' ? '${promo.discountValue.toInt()}% OFF' : '₹${promo.discountValue.toInt()} OFF',
                        style: const TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(promo.title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(promo.description, style: TextStyle(color: textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          isApplied
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                    side: const BorderSide(color: AppColors.errorRed),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => provider.clearPromoCode(),
                  child: const Text('REMOVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    await provider.validateAndApplyCoupon(
                      code: promo.code,
                      orderAmount: 500.0,
                    );
                  },
                  child: const Text('APPLY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
        ],
      ),
    );
  }
}
