import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';

class CustomerReportsScreen extends StatefulWidget {
  const CustomerReportsScreen({super.key});

  @override
  State<CustomerReportsScreen> createState() => _CustomerReportsScreenState();
}

class _CustomerReportsScreenState extends State<CustomerReportsScreen> {
  String _selectedRange = '6 Months';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final bookings = provider.bookings;
    final totalTrips = bookings.isNotEmpty ? bookings.length : 24;
    final totalRevenue = bookings.isNotEmpty
        ? bookings.fold<double>(0, (sum, b) => sum + (b.negotiatedFare ?? b.totalAmount)).toInt()
        : 18500;

    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    final cardBg = isDark ? AppColors.darkCardBg : Colors.white;
    final pageBg = isDark ? AppColors.darkBg : AppColors.page;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
        title: Text(
          'Reports',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Two Top Blue KPI Cards Side-by-Side
            Row(
              children: [
                // Total Trips
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.blueGlowShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.directions_car_rounded, color: Colors.white, size: 24),
                        const SizedBox(height: 12),
                        const Text(
                          'Total Trips',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$totalTrips',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Total Revenue / Spent
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.blueGlowShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                        const SizedBox(height: 12),
                        const Text(
                          'Total Revenue',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalRevenue > 0 ? totalRevenue : 18500}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2. Monthly Revenue Section with Bar Chart
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark ? [] : AppColors.softShadow,
                border: Border.all(color: borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Revenue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCardElevated : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRange,
                            dropdownColor: cardBg,
                            isDense: true,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textPrimary),
                            items: ['6 Months', '3 Months', '1 Year']
                                .map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        v,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedRange = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Bar Chart (Jan, Feb, Mar, Apr, May, Jun)
                  SizedBox(
                    height: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ChartBar(label: 'Jan', heightFraction: 0.35, textColor: textSecondary),
                        _ChartBar(label: 'Feb', heightFraction: 0.50, textColor: textSecondary),
                        _ChartBar(label: 'Mar', heightFraction: 0.45, textColor: textSecondary),
                        _ChartBar(label: 'Apr', heightFraction: 0.65, textColor: textSecondary),
                        _ChartBar(label: 'May', heightFraction: 0.70, textColor: textSecondary),
                        _ChartBar(label: 'Jun', heightFraction: 0.90, textColor: textSecondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Top Locations Section
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark ? [] : AppColors.softShadow,
                border: Border.all(color: borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Top Locations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildLocationRow('Kakdwip', 0.35, '35%', AppColors.primaryBlue, textPrimary, borderSubtle),
                  const SizedBox(height: 14),
                  _buildLocationRow('Namkhana', 0.30, '30%', const Color(0xFFF97316), textPrimary, borderSubtle),
                  const SizedBox(height: 14),
                  _buildLocationRow('Canning', 0.20, '20%', AppColors.accentCyan, textPrimary, borderSubtle),
                  const SizedBox(height: 14),
                  _buildLocationRow('Others', 0.15, '15%', AppColors.textMuted, textPrimary, borderSubtle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(String name, double fraction, String percent, Color color, Color textPrimary, Color trackBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              percent,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: trackBg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ChartBar extends StatelessWidget {
  final String label;
  final double heightFraction;
  final Color textColor;

  const _ChartBar({required this.label, required this.heightFraction, this.textColor = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 100 * heightFraction,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
