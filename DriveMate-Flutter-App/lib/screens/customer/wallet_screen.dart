import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String _activeTab = 'All'; // 'All', 'Credits', 'Debits'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriveMateProvider>().fetchWalletDetails();
    });
  }

  void _showAddMoneySheet(BuildContext context, DriveMateProvider provider) {
    final amountCtrl = TextEditingController(text: '500');
    String selectedMethod = 'UPI';
    final isDark = AppColors.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardBg : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Money to Wallet',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Top up your balance for one-tap payments on rides and rentals.',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(color: AppColors.accentCyan, fontSize: 22, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                // Quick Amount Presets
                Row(
                  children: [200, 500, 1000, 2000].map((preset) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: amountCtrl.text == preset.toString() ? AppColors.accentCyan : AppColors.borderSubtle,
                            ),
                            backgroundColor: amountCtrl.text == preset.toString()
                                ? AppColors.accentCyan.withOpacity(0.15)
                                : (isDark ? AppColors.darkCardElevated : Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            setSheetState(() => amountCtrl.text = preset.toString());
                          },
                          child: Text('+₹$preset',
                              style: TextStyle(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text('Payment Method', style: TextStyle(color: AppColors.accentCyan, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: ['UPI', 'Credit/Debit Card', 'Net Banking'].map((m) {
                    final isSel = selectedMethod == m;
                    return ChoiceChip(
                      label: Text(m,
                          style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              fontSize: 12)),
                      selected: isSel,
                      selectedColor: AppColors.primaryBlue,
                      backgroundColor: isDark ? AppColors.darkCardElevated : Colors.white,
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedMethod = m);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (amount < 10) {
                        provider.showToast('Minimum top-up amount is ₹10');
                        return;
                      }
                      Navigator.pop(ctx);
                      await provider.addWalletFunds(amount, paymentMethod: selectedMethod);
                    },
                    child: const Text('PROCEED TO ADD MONEY', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWithdrawSheet(BuildContext context, DriveMateProvider provider) {
    final amountCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    String payoutMethod = 'upi'; // 'upi' or 'bank_transfer'
    final isDark = AppColors.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardBg : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Withdraw Funds / Payout',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Available: ₹${provider.walletBalance.toStringAsFixed(2)} • Minimum: ₹100',
                  style: const TextStyle(color: AppColors.accentCyan, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            'UPI Transfer',
                            style: TextStyle(
                              fontSize: 12,
                              color: payoutMethod == 'upi'
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                            ),
                          ),
                        ),
                        selected: payoutMethod == 'upi',
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: isDark ? AppColors.darkCardElevated : AppColors.cardBg,
                        onSelected: (val) {
                          if (val) setSheetState(() => payoutMethod = 'upi');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            'Bank Account',
                            style: TextStyle(
                              fontSize: 12,
                              color: payoutMethod == 'bank_transfer'
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                            ),
                          ),
                        ),
                        selected: payoutMethod == 'bank_transfer',
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: isDark ? AppColors.darkCardElevated : AppColors.cardBg,
                        onSelected: (val) {
                          if (val) setSheetState(() => payoutMethod = 'bank_transfer');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Withdrawal Amount (₹)',
                    labelStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.accentCyan),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: payoutMethod == 'upi' ? 'UPI ID (e.g. name@okhdfcbank)' : 'Account Number & IFSC',
                    labelStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    filled: true,
                    fillColor: isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: Icon(payoutMethod == 'upi' ? Icons.qr_code : Icons.account_balance, color: AppColors.accentCyan),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      final target = targetCtrl.text.trim();
                      if (amount < 100) {
                        provider.showToast('Minimum withdrawal amount is ₹100');
                        return;
                      }
                      if (target.isEmpty) {
                        provider.showToast('Please enter your payout UPI ID or Bank Account');
                        return;
                      }
                      Navigator.pop(ctx);
                      await provider.withdrawWalletFunds(
                        amount: amount,
                        payoutMethod: payoutMethod,
                        accountOrUpi: target,
                      );
                    },
                    child: const Text('CONFIRM WITHDRAWAL', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final wallet = provider.walletDetails;
    final balance = wallet?.balance ?? provider.walletBalance;
    final transactions = wallet?.transactions ?? [];
    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.cardBgOf(context);
    final bgSecondary = AppColors.cardElevatedOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    final filteredList = transactions.where((tx) {
      if (_activeTab == 'Credits') return tx.isCredit;
      if (_activeTab == 'Debits') return !tx.isCredit;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCardBg : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AppColors.accentCyan, size: 22),
            const SizedBox(width: 8),
            Text('DriveMate Wallet', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textSecondary),
            tooltip: 'Refresh Balance',
            onPressed: () => provider.fetchWalletDetails(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PREMIUM WALLET CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.2),
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
                      const Text(
                        'AVAILABLE BALANCE',
                        style: TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.successGreen.withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, color: AppColors.successGreen, size: 12),
                            SizedBox(width: 4),
                            Text('Secure Ledger', style: TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '₹${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Instant checkout enabled • Zero payment gateway processing charges',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('ADD MONEY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _showAddMoneySheet(context, provider),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentCyan,
                            side: const BorderSide(color: AppColors.accentCyan),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                          label: const Text('WITHDRAW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _showWithdrawSheet(context, provider),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SUPPORTED PAYMENT MODES CHIPS
            const Text(
              'Supported Payment Modes',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPaymentBadge(Icons.account_balance_wallet, 'DriveMate Wallet'),
                  _buildPaymentBadge(Icons.qr_code_2, 'UPI (GPay / PhonePe)'),
                  _buildPaymentBadge(Icons.credit_card, 'Cards (Visa / Master)'),
                  _buildPaymentBadge(Icons.account_balance, 'Net Banking'),
                  _buildPaymentBadge(Icons.money, 'Cash on Trip'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // TRANSACTION HISTORY SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction History',
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: ['All', 'Credits', 'Debits'].map((tab) {
                    final isSel = _activeTab == tab;
                    return InkWell(
                      onTap: () => setState(() => _activeTab = tab),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primaryBlue : (isDark ? AppColors.darkCardElevated : AppColors.cardBg),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tab,
                          style: TextStyle(
                            color: isSel ? Colors.white : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (filteredList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 40),
                    const SizedBox(height: 10),
                    Text('No Transactions Yet', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Your ride charges, top-ups and payouts will appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              )
            else
              ...filteredList.map((tx) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tx.isCredit ? AppColors.successGreen.withOpacity(0.15) : AppColors.errorRed.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: tx.isCredit ? AppColors.successGreen : AppColors.errorRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description.isNotEmpty ? tx.description : (tx.isCredit ? 'Credit' : 'Debit'),
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ref: ${tx.referenceId.isNotEmpty ? tx.referenceId : "#${tx.id}"} • ${tx.createdAt}',
                            style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${tx.isCredit ? "+" : "-"}₹${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: tx.isCredit ? AppColors.successGreen : AppColors.errorRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bal: ₹${tx.balanceAfter.toStringAsFixed(2)}',
                          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
            const SizedBox(height: 24),

            // DIGITAL INVOICE & REFUND BANNER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.accentCyan, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('100% Instant Refund Guarantee', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Cancellations are credited immediately to your DriveMate Wallet without deduction.', style: TextStyle(color: textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(IconData icon, String label) {
    final isDark = AppColors.isDark(context);
    return InkWell(
      onTap: () => _showPaymentMethodDetails(context, label),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCardElevated : AppColors.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.accentCyan, size: 14),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodDetails(BuildContext context, String methodName) {
    final provider = context.read<DriveMateProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payment_rounded, color: AppColors.primaryBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                methodName,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (methodName.contains('Wallet')) ...[
              Text(
                'Current Available Balance: ₹${provider.walletBalance.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'DriveMate Wallet provides 1-tap checkout with 0% gateway transaction fees, instant cancellation refunds, and automatic invoice generation.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Money Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAddMoneySheet(context, provider);
                  },
                ),
              ),
            ] else if (methodName.contains('UPI')) ...[
              const Text(
                'Supported UPI Providers:',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Chip(label: Text('Google Pay', style: TextStyle(fontSize: 11))),
                  Chip(label: Text('PhonePe', style: TextStyle(fontSize: 11))),
                  Chip(label: Text('Paytm UPI', style: TextStyle(fontSize: 11))),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Direct app-switch UPI intent and dynamic QR code generation are fully integrated via backend payment engine.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ] else if (methodName.contains('Cards')) ...[
              const Text(
                'Credit & Debit Card Gateways:',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Accepting Visa, MasterCard, RuPay, and American Express. Protected by 256-bit AES end-to-end encryption & RBI-mandated 2-factor OTP authorization.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ] else if (methodName.contains('Net Banking')) ...[
              const Text(
                'Supported Indian Banks:',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'SBI, HDFC Bank, ICICI Bank, Axis Bank, Kotak Mahindra, Punjab National Bank, and 50+ other scheduled commercial banks.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ] else ...[
              const Text(
                'Cash on Trip Payment Rules:',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please pay the exact fare shown on your digital invoice to the verified driver at journey completion. Do not pay without receiving the trip completion OTP confirmation on your app.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
