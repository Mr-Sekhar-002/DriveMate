import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/drivemate_models.dart';
import '../providers/drivemate_provider.dart';
import '../theme/app_theme.dart';

class FareNegotiationDialog extends StatefulWidget {
  final Booking booking;

  const FareNegotiationDialog({
    super.key,
    required this.booking,
  });

  static Future<void> show(BuildContext context, Booking booking) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FareNegotiationDialog(booking: booking),
    );
  }

  @override
  State<FareNegotiationDialog> createState() => _FareNegotiationDialogState();
}

class _FareNegotiationDialogState extends State<FareNegotiationDialog> {
  final TextEditingController _offerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final currentFare = widget.booking.negotiatedFare ?? widget.booking.totalAmount;
    _offerController.text = currentFare.toInt().toString();
  }

  @override
  void dispose() {
    _offerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final currentRole = provider.currentRole;
    final negotiations = provider.getNegotiationsForBooking(widget.booking.id);
    final latestOffer = negotiations.isNotEmpty ? negotiations.last : null;
    final isAgreed = widget.booking.negotiationStatus == 'AGREED' || latestOffer?.status == NegotiationStatus.accepted;
    final isRejected = widget.booking.negotiationStatus == 'REJECTED' || latestOffer?.status == NegotiationStatus.rejected;
    final isMyTurn = latestOffer == null || (latestOffer.status == NegotiationStatus.pending && latestOffer.senderRole != currentRole.name);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle & Header
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Two-Way Fare Negotiation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy900,
                      ),
                    ),
                    Text(
                      'Booking #${widget.booking.id} • ${widget.booking.bookingType.title}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(widget.booking.negotiationStatus),
              ],
            ),

            const SizedBox(height: 16),

            // Route & Current Agreed or Estimated Fare Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trip_origin, size: 16, color: AppColors.electricBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.booking.pickupLocation,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.accentGold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.booking.destination,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated / Base Fare:',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                      ),
                      Text(
                        '₹${widget.booking.totalAmount.toInt()}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy900),
                      ),
                    ],
                  ),
                  if (widget.booking.negotiatedFare != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Negotiated Offer:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.electricBlue),
                        ),
                        Text(
                          '₹${widget.booking.negotiatedFare!.toInt()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isAgreed ? AppColors.successGreen : AppColors.electricBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Negotiation Rounds Timeline
            const Text(
              'Negotiation History',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy900),
            ),
            const SizedBox(height: 8),

            if (negotiations.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  'No offers submitted yet. Start negotiation by entering your preferred fare below.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: negotiations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = negotiations[index];
                    final isCustomerOffer = item.senderRole == 'customer';
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCustomerOffer ? AppColors.cyanLight.withOpacity(0.3) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCustomerOffer ? AppColors.cyanAccent.withOpacity(0.5) : AppColors.successGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCustomerOffer ? Icons.person : Icons.airline_seat_recline_extra,
                                size: 16,
                                color: isCustomerOffer ? AppColors.navy800 : AppColors.successGreen,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${isCustomerOffer ? "Customer" : "Driver"} ${item.status.label}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy900),
                                  ),
                                  if (item.notes != null && item.notes!.isNotEmpty)
                                    Text(
                                      item.notes!,
                                      style: TextStyle(fontSize: 10, color: AppColors.textSecondaryDark),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            '₹${item.offeredFare.toInt()}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.navy900),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Negotiation Controls (If not finalized)
            if (isAgreed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.successGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.successGreen, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Agreed Fare Confirmed at ₹${(widget.booking.negotiatedFare ?? widget.booking.totalAmount).toInt()}! Booking is locked and ready for trip.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              )
            else if (isRejected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.errorRed),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel, color: AppColors.errorRed, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Fare offer was rejected. You may submit a revised offer or book at standard rate.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Offer Amount Input
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _offerController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Your Fare (INR)',
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy900),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick adjustment chips
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final val = int.tryParse(_offerController.text) ?? 300;
                      if (val > 50) _offerController.text = '${val - 50}';
                    },
                    child: const Text('- ₹50', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final val = int.tryParse(_offerController.text) ?? 300;
                      _offerController.text = '${val + 50}';
                    },
                    child: const Text('+ ₹50', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'Optional Note / Route Specifics (e.g. Kakdwip Station pickup)',
                  labelStyle: const TextStyle(fontSize: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              if (latestOffer != null && latestOffer.status == NegotiationStatus.pending && isMyTurn) ...[
                Row(
                  children: [
                    // Accept button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                setState(() => _isSubmitting = true);
                                provider.respondToFareOffer(
                                  widget.booking.id,
                                  'accept',
                                  notes: 'Accepted proposed fare of ₹${latestOffer.offeredFare.toInt()}',
                                );
                                Navigator.pop(context);
                              },
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(
                          'Accept ₹${latestOffer.offeredFare.toInt()}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Counter button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.electricBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final fare = double.tryParse(_offerController.text.trim()) ?? 0;
                                if (fare <= 0) return;
                                setState(() => _isSubmitting = true);
                                provider.respondToFareOffer(
                                  widget.booking.id,
                                  'counter',
                                  counterFare: fare,
                                  notes: _notesController.text.trim(),
                                );
                                Navigator.pop(context);
                              },
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Counter Offer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            provider.respondToFareOffer(widget.booking.id, 'reject');
                            Navigator.pop(context);
                          },
                    child: const Text(
                      'Decline Offer',
                      style: TextStyle(color: AppColors.errorRed, fontSize: 12),
                    ),
                  ),
                ),
              ] else if (!isMyTurn && latestOffer.status == NegotiationStatus.pending) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Offer sent (₹${latestOffer.offeredFare.toInt()}). Waiting for ${currentRole == UserRole.customer ? "driver" : "customer"} to respond...',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Initial offer submit button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electricBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            final fare = double.tryParse(_offerController.text.trim()) ?? 0;
                            if (fare <= 0) return;
                            setState(() => _isSubmitting = true);
                            provider.submitFareOffer(
                              widget.booking.id,
                              fare,
                              notes: _notesController.text.trim(),
                            );
                            Navigator.pop(context);
                          },
                    icon: const Icon(Icons.local_offer, size: 18),
                    label: const Text('Submit Preferred Fare', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label = status;

    switch (status) {
      case 'AGREED':
        bg = const Color(0xFFD1FAE5);
        text = const Color(0xFF065F46);
        label = 'AGREED (₹)';
        break;
      case 'PENDING':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFF92400E);
        label = 'IN NEGOTIATION';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFF991B1B);
        label = 'REJECTED';
        break;
      default:
        bg = AppColors.surfaceLight;
        text = AppColors.textSecondaryDark;
        label = 'STANDARD FARE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }
}
