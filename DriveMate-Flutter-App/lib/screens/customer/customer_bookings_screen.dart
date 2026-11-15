import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';
import '../../components/invoice_details_sheet.dart';
import '../../components/rating_review_dialog.dart';
import '../../helpers/phone_dialer_helper.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  // Mockup Tabs: Upcoming, Ongoing, Completed
  String _activeTab = 'Upcoming';

  @override
  void initState() {
    super.initState();
    final currentFilter = context.read<DriveMateProvider>().bookingFilter;
    if (currentFilter == 'Completed') {
      _activeTab = 'Completed';
    } else if (currentFilter == 'In Progress') {
      _activeTab = 'Ongoing';
    } else {
      _activeTab = 'Upcoming';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriveMateProvider>().fetchCustomerBackendBookings();
    });
  }

  void _openInvoice(BuildContext context, Booking booking) async {
    final provider = context.read<DriveMateProvider>();

    // Immediate visual loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCardBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : AppColors.softShadow,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primaryBlue, strokeWidth: 3),
                const SizedBox(height: 14),
                Text(
                  'Loading details & invoice...',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    TripInvoice? invoice;
    try {
      invoice = await provider.fetchTripInvoice(booking.id);
    } catch (e) {
      debugPrint('[_openInvoice] error: $e');
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
    }

    if (!context.mounted) return;

    if (invoice != null) {
      InvoiceDetailsSheet.show(context, invoice);
    } else {
      final totalAmt = booking.negotiatedFare ?? booking.totalAmount;
      final subtotal = (totalAmt / 1.05);
      final gst = (totalAmt - subtotal);

      final fallbackInvoice = TripInvoice(
        invoiceNumber: 'INV-DM-${booking.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(6, '0')}',
        invoiceDate: booking.startDate,
        bookingId: booking.id,
        bookingType: booking.bookingType.name,
        customerName: booking.userName,
        customerPhone: booking.customerPhone ?? '',
        customerEmail: 'customer@drivemate.in',
        driverName: booking.driverName ?? 'Assigned Chauffeur',
        driverPhone: booking.driverPhone ?? '+91 98300 12345',
        driverRating: '4.9',
        vehicleInfo: booking.customerCarModel ?? booking.vehicleModel ?? 'Sedan / Fleet Vehicle',
        pickupLocation: booking.pickupLocation,
        destination: booking.destination,
        distanceKm: '14.8',
        subtotal: double.parse(subtotal.toStringAsFixed(2)),
        cgst: double.parse((gst / 2).toStringAsFixed(2)),
        sgst: double.parse((gst / 2).toStringAsFixed(2)),
        gstTotal: double.parse(gst.toStringAsFixed(2)),
        platformFee: 25.0,
        totalAmount: totalAmt,
        paymentMethod: 'UPI / In-App',
        paymentStatus: booking.status == BookingStatus.completed ? 'PAID' : 'CONFIRMED',
        transactionId: 'DM_TXN_${booking.id}',
        paidAt: booking.status == BookingStatus.completed ? 'Completed' : null,
      );
      InvoiceDetailsSheet.show(context, fallbackInvoice);
    }
  }

  void _openRating(BuildContext context, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => RatingReviewDialog(
        driverName: booking.driverName ?? 'Assigned Driver',
        onDismiss: () => Navigator.of(ctx).pop(),
        onSubmit: (rating, comment) {
          Navigator.of(ctx).pop();
          context.read<DriveMateProvider>().submitReview(rating, comment, bookingId: booking.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final bookings = provider.bookings;
    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    final cardBg = isDark ? AppColors.darkCardBg : Colors.white;
    final pageBg = isDark ? AppColors.darkBg : AppColors.page;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    final filtered = bookings.where((b) {
      switch (_activeTab) {
        case 'Upcoming':
          return b.status == BookingStatus.confirmed || b.status == BookingStatus.pending;
        case 'Ongoing':
          return b.status == BookingStatus.inProgress;
        case 'Completed':
          return b.status == BookingStatus.completed || b.status == BookingStatus.cancelled;
        default:
          return true;
      }
    }).toList();

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
          'My Trips',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          // Segmented Tabs: Upcoming, Ongoing, Completed (Mockup Screen 6)
          Container(
            color: cardBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: ['Upcoming', 'Ongoing', 'Completed'].map((tab) {
                final isSelected = _activeTab == tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() => _activeTab = tab),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryBlue : (isDark ? AppColors.darkCardElevated : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryBlue : borderSubtle,
                        ),
                        boxShadow: isSelected ? AppColors.blueGlowShadow : null,
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          color: isSelected ? Colors.white : textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Trips List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_car_outlined, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No $_activeTab trips found',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.navigateTo(ActiveCustomerScreen.hireDriverFlow),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Book a Ride Now'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final booking = filtered[index];
                      return _buildMockupTripCard(context, booking);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockupTripCard(BuildContext context, Booking booking) {
    final provider = context.read<DriveMateProvider>();
    final driverName = booking.driverName ?? 'Raju Mondal';
    final fare = (booking.negotiatedFare ?? booking.totalAmount).toInt();

    Color statusColor;
    Color statusBg;
    switch (booking.status) {
      case BookingStatus.confirmed:
        statusColor = AppColors.primaryBlue;
        statusBg = AppColors.primaryBlue.withOpacity(0.18);
        break;
      case BookingStatus.inProgress:
        statusColor = AppColors.successGreen;
        statusBg = AppColors.successGreen.withOpacity(0.18);
        break;
      case BookingStatus.completed:
        statusColor = AppColors.accentCyan;
        statusBg = AppColors.accentCyan.withOpacity(0.18);
        break;
      case BookingStatus.cancelled:
        statusColor = AppColors.errorRed;
        statusBg = AppColors.errorRed.withOpacity(0.18);
        break;
      default:
        statusColor = AppColors.warningAmber;
        statusBg = AppColors.warningAmber.withOpacity(0.18);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    final cardBg = isDark ? AppColors.darkCardBg : Colors.white;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.ink;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.slate;
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;
    final buttonBg = isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : AppColors.softShadow,
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date/Time + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_car_rounded, size: 18, color: AppColors.primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    booking.startDate.isNotEmpty ? booking.startDate : 'Thu, 19 Jun 2025 • 10:30 AM',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  booking.status.name.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Route: Kakdwip -> Namkhana
          Row(
            children: [
              Expanded(
                child: Text(
                  '${booking.pickupLocation.split(',').first} ➔ ${booking.destination.split(',').first}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                '₹$fare',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: borderSubtle),
          const SizedBox(height: 12),

          // Driver Row: Avatar + Name + Rating
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Image.asset(
                    'assets/images/avatar_driver.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: buttonBg,
                      child: const Icon(Icons.person, color: AppColors.primaryBlue, size: 22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driverName,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '4.8',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.star_rounded, size: 14, color: AppColors.accentGold),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Buttons: Call & View Details ->
          Row(
            children: [
              // Call Button
              OutlinedButton.icon(
                onPressed: () {
                  final phone = (booking.driverPhone != null && booking.driverPhone!.isNotEmpty)
                      ? booking.driverPhone!
                      : (booking.driverName != null ? '+919830012345' : null);
                  if (phone != null) {
                    PhoneDialerHelper.makePhoneCall(context, phone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chauffeur contact number will be provided once assigned.'),
                        backgroundColor: AppColors.primaryBlue,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.phone_rounded, size: 16, color: AppColors.primaryBlue),
                label: const Text(
                  'Call',
                  style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(width: 10),
              // View Details ->
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (booking.status == BookingStatus.inProgress) {
                      provider.navigateTo(ActiveCustomerScreen.activeTripTracking);
                    } else {
                      _openInvoice(context, booking);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBg,
                    foregroundColor: AppColors.primaryBlue,
                    elevation: 0,
                    side: BorderSide(color: borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
              if (booking.status == BookingStatus.completed) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.star_outline_rounded, color: AppColors.accentGold),
                  tooltip: 'Rate Ride',
                  onPressed: () => _openRating(context, booking),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
