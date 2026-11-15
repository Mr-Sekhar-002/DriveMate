import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../models/drivemate_models.dart';
import '../theme/app_theme.dart';

class InvoiceDetailsSheet {
  static void show(BuildContext context, TripInvoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InvoiceBottomSheetContent(invoice: invoice),
    );
  }
}

class _InvoiceBottomSheetContent extends StatelessWidget {
  final TripInvoice invoice;

  const _InvoiceBottomSheetContent({required this.invoice});

  String _generatePlainTextInvoice() {
    return '''
========================================
       DRIVEMATE MOBILITY TAX INVOICE
========================================
Invoice No:    ${invoice.invoiceNumber}
Date:          ${invoice.invoiceDate}
Booking Ref:   #${invoice.bookingId} (${invoice.bookingType})

CUSTOMER DETAILS:
Name:          ${invoice.customerName}
Phone:         ${invoice.customerPhone}
Email:         ${invoice.customerEmail}

CHAUFFEUR & VEHICLE:
Chauffeur:     ${invoice.driverName}
Contact:       ${invoice.driverPhone}
Rating:        ${invoice.driverRating} ★
Vehicle:       ${invoice.vehicleInfo}

JOURNEY DETAILS:
Pickup:        ${invoice.pickupLocation}
Destination:   ${invoice.destination}
Distance:      ${invoice.distanceKm} km

FARE BREAKDOWN:
Journey Subtotal:    ₹${invoice.subtotal.toStringAsFixed(2)}
Platform Fee:        ₹${invoice.platformFee.toStringAsFixed(2)}
CGST (2.5%):         ₹${invoice.cgst.toStringAsFixed(2)}
SGST (2.5%):         ₹${invoice.sgst.toStringAsFixed(2)}
Total GST (5%):      ₹${invoice.gstTotal.toStringAsFixed(2)}
----------------------------------------
TOTAL AMOUNT:        ₹${invoice.totalAmount.toStringAsFixed(2)}
----------------------------------------

PAYMENT SUMMARY:
Payment Method:      ${invoice.paymentMethod}
Payment Status:      ${invoice.paymentStatus}
Transaction Ref:     ${invoice.transactionId}
${invoice.paidAt != null ? 'Paid At:             ${invoice.paidAt}' : ''}
========================================
    Thank you for riding with DriveMate!
========================================
''';
  }

  void _shareInvoice(BuildContext context) {
    final text = _generatePlainTextInvoice();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tax invoice copied to clipboard! Ready to share.'),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _downloadInvoice(BuildContext context) async {
    final text = _generatePlainTextInvoice();
    Clipboard.setData(ClipboardData(text: text));

    final cleanId = invoice.bookingId.replaceAll(RegExp(r'[^0-9]'), '');
    final bId = int.tryParse(cleanId) ?? 1;
    final pdfUri = ApiConfig.getUri('/payments/invoice/pdf', {'booking_id': '$bId'});

    try {
      final launched = await launchUrl(pdfUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback: launch without external application mode
        await launchUrl(pdfUri);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading Tax Invoice #${invoice.invoiceNumber}. PDF opened.'),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[downloadInvoice] launch notice: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice #${invoice.invoiceNumber} text copied & ready for download.'),
            backgroundColor: AppColors.electricBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.paymentStatus.toUpperCase() == 'PAID';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF07172F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cyanAccent, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long, color: AppColors.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tax Invoice & Breakdown',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(color: AppColors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPaid ? AppColors.successGreen.withOpacity(0.2) : AppColors.accentGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isPaid ? AppColors.successGreen : AppColors.accentGold),
                  ),
                  child: Text(
                    isPaid ? 'PAID' : 'PAYMENT DUE',
                    style: TextStyle(
                      color: isPaid ? AppColors.successGreen : AppColors.accentGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fare Total Pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F264A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cyanAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mutually Accepted Final Fare',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Inclusive of 5% GST',
                              style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 10),
                            ),
                          ],
                        ),
                        Text(
                          '₹${invoice.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.cyanAccent,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Route Card
                  _buildSectionHeader('JOURNEY ROUTE'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1D3A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _buildRouteRow(Icons.radio_button_checked, AppColors.successGreen, 'Pickup', invoice.pickupLocation),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(width: 1.5, height: 16, color: Colors.white24),
                          ),
                        ),
                        _buildRouteRow(Icons.location_on, AppColors.errorRed, 'Destination', invoice.destination),
                        const Divider(color: Colors.white12, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Road Distance: ${invoice.distanceKm} km', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            Text('Date: ${invoice.invoiceDate}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Chauffeur & Customer details
                  _buildSectionHeader('SERVICE PARTICIPANTS'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1D3A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Chauffeur', '${invoice.driverName} (${invoice.driverRating} ★)'),
                        const SizedBox(height: 6),
                        _buildInfoRow('Vehicle', invoice.vehicleInfo),
                        const SizedBox(height: 6),
                        _buildInfoRow('Customer', invoice.customerName),
                        const SizedBox(height: 6),
                        _buildInfoRow('Customer Phone', invoice.customerPhone),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Itemized Tax Breakdown
                  _buildSectionHeader('ITEMIZED FARE BREAKDOWN (GST COMPLIANT)'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1D3A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _buildBreakdownRow('Journey Base Subtotal', '₹${invoice.subtotal.toStringAsFixed(2)}'),
                        const SizedBox(height: 6),
                        _buildBreakdownRow('Platform & Safety Fee (Included)', '₹${invoice.platformFee.toStringAsFixed(2)}'),
                        const SizedBox(height: 6),
                        _buildBreakdownRow('Central GST (CGST 2.5%)', '₹${invoice.cgst.toStringAsFixed(2)}'),
                        const SizedBox(height: 6),
                        _buildBreakdownRow('State GST (SGST 2.5%)', '₹${invoice.sgst.toStringAsFixed(2)}'),
                        const Divider(color: Colors.white24, height: 16),
                        _buildBreakdownRow(
                          'Total Fare (INR)',
                          '₹${invoice.totalAmount.toStringAsFixed(2)}',
                          isBold: true,
                          highlightColor: AppColors.cyanAccent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Record
                  _buildSectionHeader('PAYMENT INFORMATION'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1D3A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Payment Method', invoice.paymentMethod),
                        const SizedBox(height: 6),
                        _buildInfoRow('Transaction Ref', invoice.transactionId),
                        const SizedBox(height: 6),
                        _buildInfoRow('Payment Status', invoice.paymentStatus),
                        if (invoice.paidAt != null) ...[
                          const SizedBox(height: 6),
                          _buildInfoRow('Paid At', invoice.paidAt!),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Action Buttons: View, Download, Share
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F264A),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cyanAccent,
                      side: const BorderSide(color: AppColors.cyanAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _shareInvoice(context),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyanAccent,
                      foregroundColor: AppColors.navy900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _downloadInvoice(context),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.cyanAccent,
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? Colors.white : Colors.white70,
            fontSize: isBold ? 13 : 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlightColor ?? (isBold ? Colors.white : Colors.white.withOpacity(0.9)),
            fontSize: isBold ? 15 : 12,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
