import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';
import '../../components/booking_card.dart';
import '../../components/invoice_details_sheet.dart';
import '../../components/rating_review_dialog.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = context.read<DriveMateProvider>().bookingFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriveMateProvider>().fetchCustomerBackendBookings();
    });
  }

  void _openInvoice(BuildContext context, Booking booking) async {
    final provider = context.read<DriveMateProvider>();
    final invoice = await provider.fetchTripInvoice(booking.id);
    if (!context.mounted) return;

    if (invoice != null) {
      InvoiceDetailsSheet.show(context, invoice);
    } else {
      // Fallback synthetic invoice constructed from booking data
      final totalAmt = booking.negotiatedFare ?? booking.totalAmount;
      final subtotal = roundDouble(totalAmt / 1.05, 2);
      final gst = roundDouble(totalAmt - subtotal, 2);

      final fallbackInvoice = TripInvoice(
        invoiceNumber: 'INV-DM-${booking.id.replaceAll(RegExp(r'[^0-9]'), '').padLeft(6, '0')}',
        invoiceDate: booking.startDate,
        bookingId: booking.id,
        bookingType: booking.bookingType.name,
        customerName: booking.userName,
        customerPhone: booking.customerPhone ?? '',
        customerEmail: 'customer@drivemate.in',
        driverName: booking.driverName ?? 'Assigned Chauffeur',
        driverPhone: '+91 98112 23344',
        driverRating: '4.95',
        vehicleInfo: booking.customerCarModel ?? booking.vehicleModel ?? 'Sedan Service',
        pickupLocation: booking.pickupLocation,
        destination: booking.destination,
        distanceKm: '12.5',
        subtotal: subtotal,
        cgst: roundDouble(gst / 2, 2),
        sgst: roundDouble(gst / 2, 2),
        gstTotal: gst,
        platformFee: 25.0,
        totalAmount: totalAmt,
        paymentMethod: 'UPI',
        paymentStatus: booking.status == BookingStatus.completed ? 'PAID' : 'DUE',
        transactionId: 'DM_TXN_${booking.id}',
        paidAt: booking.status == BookingStatus.completed ? 'Completed' : null,
      );
      InvoiceDetailsSheet.show(context, fallbackInvoice);
    }
  }

  double roundDouble(double val, int places) {
    return double.parse(val.toStringAsFixed(places));
  }

  void _openRating(BuildContext context, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => RatingReviewDialog(
        driverName: booking.driverName ?? 'Assigned Chauffeur',
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

    final filtered = bookings.where((b) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'In Progress') return b.status == BookingStatus.inProgress;
      if (_selectedFilter == 'Completed') return b.status == BookingStatus.completed;
      if (_selectedFilter == 'Confirmed') return b.status == BookingStatus.confirmed;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Bookings & Rentals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Hire a Driver & Car Rental History', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surfaceCard,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'In Progress', 'Confirmed', 'Completed'].map((tab) {
                  final isSelected = _selectedFilter == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tab, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.navy900, fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: AppColors.navy900,
                      backgroundColor: AppColors.surfaceLight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedFilter = tab);
                          provider.setBookingFilter(tab);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(height: 1, color: Colors.black12),

          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No bookings match this filter.', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final booking = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BookingCard(
                          booking: booking,
                          onTrackRide: () => provider.navigateTo(ActiveCustomerScreen.activeTripTracking),
                          onViewInvoice: () => _openInvoice(context, booking),
                          onRateDriver: () => _openRating(context, booking),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
