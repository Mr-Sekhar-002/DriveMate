import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drivemate_models.dart';
import '../providers/drivemate_provider.dart';
import '../theme/app_theme.dart';

class SmartFareBreakdownSheet extends StatefulWidget {
  final SmartFareBreakdown fare;
  final VoidCallback? onConfirmBooking;

  const SmartFareBreakdownSheet({
    super.key,
    required this.fare,
    this.onConfirmBooking,
  });

  static Future<void> show(
    BuildContext context, {
    required SmartFareBreakdown fare,
    VoidCallback? onConfirmBooking,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartFareBreakdownSheet(
        fare: fare,
        onConfirmBooking: onConfirmBooking,
      ),
    );
  }

  @override
  State<SmartFareBreakdownSheet> createState() => _SmartFareBreakdownSheetState();
}

class _SmartFareBreakdownSheetState extends State<SmartFareBreakdownSheet> {
  late TextEditingController _promoController;
  late SmartFareBreakdown _currentFare;
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    _currentFare = widget.fare;
    _promoController = TextEditingController(text: widget.fare.promoCode ?? '');
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon(DriveMateProvider provider) async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isCalculating = true);
    final updated = await provider.calculateAuthoritativeFare(
      serviceType: _currentFare.serviceType,
      hiringType: _currentFare.hiringType,
      distanceKm: _currentFare.distanceKm,
      durationMinutes: _currentFare.durationMinutes,
      hours: _currentFare.hours,
      days: _currentFare.days,
      waitingMinutes: _currentFare.waitingMinutes,
      tollCharges: _currentFare.tollCharges,
      parkingCharges: _currentFare.parkingCharges,
      promoCode: code,
      isFinal: _currentFare.isFinalFare,
    );
    if (mounted && updated != null) {
      setState(() {
        _currentFare = updated;
        _isCalculating = false;
      });
    } else {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final fare = _currentFare;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.cyanAccent, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppColors.cyanAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Transparent Fare Breakdown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Telemetry & Authoritative Status Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified, color: AppColors.cyanAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            fare.isEstimated ? 'ESTIMATED FARE' : 'FINAL AUTHORITATIVE FARE',
                            style: const TextStyle(
                              color: AppColors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${fare.distanceKm.toStringAsFixed(1)} km • ~${fare.durationMinutes} mins',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Fare Components Card ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fare Components',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      _buildFareRow('Base Pickup Fare', '₹${fare.baseFare.toStringAsFixed(2)}'),
                      _buildFareRow('Distance Charges (${fare.distanceKm.toStringAsFixed(1)} km @ ₹${fare.ratePerKm.toStringAsFixed(0)}/km)', '₹${fare.distanceCharges.toStringAsFixed(2)}'),

                      if (fare.hourlyCharges > 0)
                        _buildFareRow('Hourly Duration Package (${fare.hours} hrs @ ₹${fare.hourlyRate}/hr)', '₹${fare.hourlyCharges.toStringAsFixed(2)}'),

                      if (fare.dailyCharges > 0)
                        _buildFareRow('Daily Rental Package (${fare.days} days @ ₹${fare.dailyRate}/day)', '₹${fare.dailyCharges.toStringAsFixed(2)}'),

                      if (fare.hasNightSurcharge)
                        _buildFareRow('Night Surcharge (${fare.nightChargePercent} • ${fare.nightHours})', '₹${fare.nightCharges.toStringAsFixed(2)}', icon: Icons.nightlight_round, iconColor: Colors.amber),

                      if (fare.hasWaitingCharges)
                        _buildFareRow('Waiting Charges (${fare.waitingMinutes} mins @ ₹${fare.waitingRatePerMin}/min)', '₹${fare.waitingCharges.toStringAsFixed(2)}'),

                      if (fare.tollCharges > 0)
                        _buildFareRow('Highway Toll Pass-Through', '₹${fare.tollCharges.toStringAsFixed(2)}'),

                      if (fare.parkingCharges > 0)
                        _buildFareRow('Airport / Station Parking Pass-Through', '₹${fare.parkingCharges.toStringAsFixed(2)}'),

                      _buildFareRow('Platform Safety & Technology Fee', '₹${fare.platformFee.toStringAsFixed(2)}'),

                      const Divider(color: Colors.white12, height: 20),
                      _buildFareRow('Subtotal', '₹${fare.subtotal.toStringAsFixed(2)}', isBold: true),

                      if (fare.hasDiscount) ...[
                        const SizedBox(height: 6),
                        _buildFareRow(
                          'Promo Discount (${fare.promoCode ?? 'Promo'})',
                          '- ₹${fare.discount.toStringAsFixed(2)}',
                          valueColor: AppColors.successGreen,
                          isBold: true,
                        ),
                        if (fare.discountDetails != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 4),
                            child: Text(
                              fare.discountDetails!,
                              style: const TextStyle(color: AppColors.successGreen, fontSize: 11),
                            ),
                          ),
                      ],

                      const Divider(color: Colors.white12, height: 20),
                      _buildFareRow('Taxable Ride Fare', '₹${fare.taxableAmount.toStringAsFixed(2)}'),
                      _buildFareRow('CGST (2.5%)', '₹${fare.cgst.toStringAsFixed(2)}'),
                      _buildFareRow('SGST (2.5%)', '₹${fare.sgst.toStringAsFixed(2)}'),
                      _buildFareRow('Total GST Levies (5%)', '₹${fare.totalTax.toStringAsFixed(2)}'),

                      const Divider(color: AppColors.cyanAccent, height: 24, thickness: 1.5),

                      // Grand Total Highlight
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL PAYABLE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'All taxes & platform charges included',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '₹${fare.totalFare.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.cyanAccent,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Promo Coupon Input Card ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_offer, color: AppColors.cyanAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Apply Coupon / Promo Code',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _promoController,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: 'WELCOME50, DRIVE10, FLAT100',
                                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                                filled: true,
                                fillColor: AppColors.bgSecondary,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.borderSubtle)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.borderSubtle)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cyanAccent)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isCalculating ? null : () => _applyCoupon(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cyanAccent,
                              foregroundColor: AppColors.bgDark,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _isCalculating
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDark))
                                : const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Preset Coupon Chips
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildCouponChip('WELCOME50', '₹50 OFF', provider),
                          _buildCouponChip('DRIVE10', '10% OFF', provider),
                          _buildCouponChip('FLAT100', '₹100 OFF', provider),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── Zero Hidden Charges Guarantee ───────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cyanAccent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cyanAccent.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.cyanAccent, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Zero Hidden Charges Guarantee: Authoritative pricing computed on DriveMate server. Drivers cannot demand cash overages beyond this invoice.',
                          style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Confirm / Close Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onConfirmBooking?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      widget.onConfirmBooking != null ? 'Accept Authoritative Fare & Book' : 'Close Breakdown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponChip(String code, String label, DriveMateProvider provider) {
    return ActionChip(
      backgroundColor: AppColors.bgSecondary,
      side: const BorderSide(color: AppColors.cyanAccent, width: 0.8),
      label: Text('$code ($label)', style: const TextStyle(color: AppColors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
      onPressed: () {
        _promoController.text = code;
        _applyCoupon(provider);
      },
    );
  }

  Widget _buildFareRow(String label, String value, {bool isBold = false, Color? valueColor, IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: iconColor ?? AppColors.cyanAccent, size: 14),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isBold ? Colors.white : AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? (isBold ? Colors.white : AppColors.textPrimary),
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
