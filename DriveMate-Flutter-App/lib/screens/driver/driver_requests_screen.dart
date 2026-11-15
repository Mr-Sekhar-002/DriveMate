import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';
import '../../components/fare_negotiation_dialog.dart';

class DriverRequestsScreen extends StatelessWidget {
  const DriverRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final incomingRequest = provider.incomingDriverRequest;
    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.cardBgOf(context);
    final pageBg = AppColors.pageBgOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        title: Text(
          'Booking Requests',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.cyanAccent),
            tooltip: 'Refresh Requests',
            onPressed: () => provider.fetchDriverBackendData(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incoming & Pending Ride Requests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Review passenger pickup, route, fare offers, and accept or negotiate in real-time.',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
            const SizedBox(height: 16),
            if (incomingRequest != null)
              _buildBookingRequestCard(context, provider, incomingRequest)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 52, color: AppColors.textMuted),
                    const SizedBox(height: 14),
                    Text(
                      'No Pending Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You are Online and active in Kakdwip area. As soon as a customer requests a chauffeur or car, the instant alert with distance and fare will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingRequestCard(
    BuildContext context,
    DriveMateProvider provider,
    Booking request,
  ) {
    final hasNegotiated = request.negotiatedFare != null &&
        request.negotiatedFare != request.totalAmount;
    final displayFare = (request.negotiatedFare ?? request.totalAmount).toInt();
    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.cardBgOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final inputFill = AppColors.inputFillOf(context);
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.negotiationStatus == 'PENDING'
                      ? 'CUSTOMER FARE OFFER'
                      : 'NEW BOOKING REQUEST',
                  style: const TextStyle(
                    color: AppColors.navy900,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasNegotiated) ...[
                    Text(
                      '₹${request.totalAmount.toInt()}',
                      style: TextStyle(
                        color: textSecondary.withOpacity(0.5),
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      '₹$displayFare',
                      style: const TextStyle(
                        color: AppColors.cyanAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ] else ...[
                    Text(
                      '₹$displayFare',
                      style: const TextStyle(
                        color: AppColors.cyanAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Fixed Estimated Fare',
                      style: TextStyle(color: textSecondary, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Customer Info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: inputFill,
                child: const Icon(Icons.person, color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.userName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    'Verified DriveMate Customer • 4.9★',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: borderSubtle, height: 1),
          const SizedBox(height: 14),

          // Route Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                children: [
                  Icon(Icons.circle, color: AppColors.primaryBlue, size: 12),
                  SizedBox(height: 18),
                  Icon(Icons.location_on, color: AppColors.errorRed, size: 14),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.pickupLocation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      request.destination,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Action Buttons: Accept / Reject / Negotiate
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => provider.rejectDriverRequest(request.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                    side: const BorderSide(color: AppColors.errorRed),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => FareNegotiationDialog.show(context, request),
                icon: const Icon(Icons.handshake_outlined, size: 16),
                label: const Text('Counter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentGold,
                  side: const BorderSide(color: AppColors.accentGold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => provider.acceptDriverRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Accept Ride',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
