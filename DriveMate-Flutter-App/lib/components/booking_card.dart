import 'package:flutter/material.dart';
import '../models/drivemate_models.dart';
import '../theme/app_theme.dart';
import 'fare_negotiation_dialog.dart';

class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTrackRide;
  final VoidCallback? onRateDriver;
  final VoidCallback? onViewInvoice;

  const BookingCard({
    super.key,
    required this.booking,
    this.onTrackRide,
    this.onRateDriver,
    this.onViewInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || AppColors.isDarkModeGlobal;
    Color statusColor;
    Color statusBgColor;

    switch (booking.status) {
      case BookingStatus.inProgress:
        statusColor = AppColors.electricBlue;
        statusBgColor = isDark ? const Color(0xFF1E293B) : AppColors.cyanLight;
        break;
      case BookingStatus.completed:
        statusColor = AppColors.successGreen;
        statusBgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
        break;
      case BookingStatus.confirmed:
        statusColor = const Color(0xFFF59E0B);
        statusBgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
        break;
      case BookingStatus.pending:
        statusColor = AppColors.accentGold;
        statusBgColor = isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB);
        break;
      case BookingStatus.cancelled:
        statusColor = AppColors.errorRed;
        statusBgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
        break;
    }

    return Card(
      elevation: 2,
      color: isDark ? AppColors.darkCardBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: ID, Service Badge & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardElevated : AppColors.navy,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        booking.id,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardElevated : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
                      ),
                      child: Text(
                        booking.bookingType.title,
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.navy700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Pickup & Destination Route Visual
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.radio_button_checked, size: 14, color: AppColors.electricBlue),
                    Container(
                      width: 1.5,
                      height: 24,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                    ),
                    const Icon(Icons.location_on, size: 16, color: AppColors.accentGold),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.pickupLocation,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        booking.destination,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryOf(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(color: AppColors.borderSubtleOf(context), height: 1),
            const SizedBox(height: 12),

            // Car / Driver / Total Fare Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (booking.vehicleModel != null)
                      Row(
                        children: [
                          Icon(Icons.directions_car, size: 14, color: AppColors.textSecondaryOf(context)),
                          const SizedBox(width: 4),
                          Text(
                            booking.vehicleModel!,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryOf(context)),
                          ),
                        ],
                      ),
                    if (booking.driverName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 14, color: AppColors.textSecondaryOf(context)),
                            const SizedBox(width: 4),
                            Text(
                              'Driver: ${booking.driverName}',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryOf(context)),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      booking.hoursOrDaysText,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      booking.negotiatedFare != null ? 'Agreed Fare (INR)' : 'Total Fare (INR)',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      '₹${(booking.negotiatedFare ?? booking.totalAmount).toInt()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.electricBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Fare Negotiation Button
            if (booking.status != BookingStatus.completed && booking.status != BookingStatus.cancelled) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.navy,
                    side: BorderSide(
                      color: booking.negotiationStatus == 'PENDING'
                          ? AppColors.accentGold
                          : booking.negotiationStatus == 'AGREED'
                              ? AppColors.successGreen
                              : AppColors.electricBlue,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => FareNegotiationDialog.show(context, booking),
                  icon: Icon(
                    Icons.swap_horiz,
                    size: 16,
                    color: booking.negotiationStatus == 'PENDING'
                        ? AppColors.accentGold
                        : booking.negotiationStatus == 'AGREED'
                            ? AppColors.successGreen
                            : AppColors.electricBlue,
                  ),
                  label: Text(
                    booking.negotiationStatus == 'AGREED'
                        ? 'Agreed Fare: ₹${(booking.negotiatedFare ?? booking.totalAmount).toInt()} (View Details)'
                        : booking.negotiationStatus == 'PENDING'
                            ? 'Negotiation Pending (Respond)'
                            : 'Negotiate Fare (Two-Way)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],

            // Actions for In-Progress or Completed trips
            if (booking.status == BookingStatus.inProgress && onTrackRide != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkCardElevated : AppColors.navy,
                    foregroundColor: AppColors.cyanAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onTrackRide,
                  icon: const Icon(Icons.navigation, size: 16),
                  label: const Text('Track Live Ride (OSRM Routing)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ] else if (booking.status == BookingStatus.completed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onViewInvoice != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.darkCardElevated : AppColors.navy,
                          foregroundColor: AppColors.cyanAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: onViewInvoice,
                        icon: const Icon(Icons.receipt_long, size: 15),
                        label: const Text('View Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  if (onViewInvoice != null && onRateDriver != null) const SizedBox(width: 8),
                  if (onRateDriver != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accentGold,
                          side: const BorderSide(color: AppColors.accentGold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: onRateDriver,
                        icon: const Icon(Icons.star_rate, size: 15),
                        label: const Text('Rate Chauffeur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
