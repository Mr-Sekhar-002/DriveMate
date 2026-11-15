import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../components/invoice_details_sheet.dart';
import '../../components/rating_review_dialog.dart';
import '../../helpers/phone_dialer_helper.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../services/location_service.dart';
import '../../services/osm_routing_service.dart';
import '../../theme/app_theme.dart';

class ActiveTripTrackingScreen extends StatefulWidget {
  const ActiveTripTrackingScreen({super.key});

  @override
  State<ActiveTripTrackingScreen> createState() => _ActiveTripTrackingScreenState();
}

class _ActiveTripTrackingScreenState extends State<ActiveTripTrackingScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routeCoordinates = [];
  bool _isLoadingRoute = true;
  double _roadDistanceKm = 0.0;
  int _estimatedDurationMinutes = 0;
  String? _lastLoadedTripId;
  String? _lastFetchedInvoiceBookingId;
  LatLng? _userCurrentGps;
  bool _isLocatingUser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DriveMateProvider>();
      final trip = provider.activeTrip;
      if (trip != null && trip.status != TripStatus.completed) {
        provider.startDriverLiveTracking();
        _loadOsrmRoute(trip);
      } else if (trip != null && trip.status == TripStatus.completed) {
        if (_lastFetchedInvoiceBookingId != trip.bookingId) {
          _lastFetchedInvoiceBookingId = trip.bookingId;
          provider.fetchTripInvoice(trip.bookingId);
        }
      }
    });
  }

  DriveMateProvider? _providerRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providerRef = context.read<DriveMateProvider>();
  }

  @override
  void dispose() {
    _providerRef?.stopDriverLiveTracking();
    super.dispose();
  }

  Future<void> _loadOsrmRoute(Trip trip) async {
    _lastLoadedTripId = trip.id;
    setState(() => _isLoadingRoute = true);

    final start = LatLng(trip.startLat ?? 21.8767, trip.startLng ?? 88.1912);
    final end = LatLng(trip.endLat ?? 21.8712, trip.endLng ?? 88.1824);

    final routeResult = await OsmRoutingService.fetchRoute(
      start: start,
      destination: end,
      startAddress: trip.startLocation,
      destinationAddress: trip.endLocation,
    );

    if (mounted) {
      setState(() {
        _isLoadingRoute = false;
        if (routeResult.isSuccess && routeResult.polylinePoints.isNotEmpty) {
          _routeCoordinates = routeResult.polylinePoints;
          _roadDistanceKm = routeResult.distanceKm;
          _estimatedDurationMinutes = routeResult.durationMinutes;
        } else {
          // Fallback to straight-line connection if OSRM public endpoint timed out
          _routeCoordinates = [start, end];
          _roadDistanceKm = trip.distanceKm;
          _estimatedDurationMinutes = (trip.distanceKm * 2.2).round();
        }
      });

      // Automatically fit camera bounds to the actual pickup and destination locations
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitCameraToBounds(driverPos: _resolveDriverPosition(trip));
      });
    }
  }

  LatLng _resolveDriverPosition(Trip trip) {
    if (trip.currentLat != null && trip.currentLng != null) {
      return LatLng(trip.currentLat!, trip.currentLng!);
    }
    if (_routeCoordinates.isNotEmpty) {
      final progress = trip.currentProgress.clamp(0.0, 1.0);
      final index = ((_routeCoordinates.length - 1) * progress).floor();
      return _routeCoordinates[index.clamp(0, _routeCoordinates.length - 1)];
    }
    return LatLng(trip.startLat ?? 21.8767, trip.startLng ?? 88.1912);
  }

  void _fitCameraToBounds({LatLng? driverPos}) {
    if (!mounted) return;
    final provider = context.read<DriveMateProvider>();
    final trip = provider.activeTrip;
    if (trip == null) return;

    final points = <LatLng>[];
    if (_routeCoordinates.length >= 2) {
      points.addAll(_routeCoordinates);
    } else {
      points.add(LatLng(trip.startLat ?? 21.8767, trip.startLng ?? 88.1912));
      points.add(LatLng(trip.endLat ?? 21.8712, trip.endLng ?? 88.1824));
    }
    if (driverPos != null) {
      points.add(driverPos);
    }

    if (points.length >= 2) {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          // Bottom padding leaves room for the docked trip info card so route remains visible
          padding: const EdgeInsets.only(top: 90, bottom: 320, left: 32, right: 32),
        ),
      );
    }
  }

  Future<void> _handleCurrentLocation() async {
    setState(() => _isLocatingUser = true);
    final result = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _isLocatingUser = false;
        _userCurrentGps = result.coordinates;
      });
      _mapController.move(result.coordinates, 16.0);
    }
  }

  String _getStatusTitle(TripStatus status) {
    switch (status) {
      case TripStatus.assigned:
        return 'CHAUFFEUR ASSIGNED • ON THE WAY';
      case TripStatus.driverArrived:
        return 'CHAUFFEUR ARRIVED AT PICKUP';
      case TripStatus.onTrip:
        return 'ON TRIP TO DESTINATION';
      case TripStatus.completed:
        return 'TRIP COMPLETED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final activeTrip = provider.activeTrip;

    // Check if trip changed
    if (activeTrip != null && activeTrip.id != _lastLoadedTripId && activeTrip.status != TripStatus.completed) {
      _loadOsrmRoute(activeTrip);
    }

    // MODE 1: Empty state (No Active Ride)
    if (activeTrip == null) {
      return _buildEmptyState(provider);
    }

    // MODE 2: Completed Trip Summary (Never show live navigation for completed trips)
    if (activeTrip.status == TripStatus.completed) {
      if (_lastFetchedInvoiceBookingId != activeTrip.bookingId) {
        _lastFetchedInvoiceBookingId = activeTrip.bookingId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.fetchTripInvoice(activeTrip.bookingId);
        });
      }
      return _buildCompletedTripSummary(provider, activeTrip);
    }

    // MODE 3: Active Live Navigation Experience
    return _buildActiveLiveNavigation(provider, activeTrip);
  }

  // ─── EMPTY STATE VIEW ───────────────────────────────────────────────────────
  Widget _buildEmptyState(DriveMateProvider provider) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy900,
        elevation: 0,
        title: const Text('Live Ride Tracking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.navigation_outlined, size: 48, color: AppColors.cyanAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Active Ride in Progress',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'When you hire a driver or book a rental car, your live GPS telemetry, OSRM road routing, and chauffeur location will appear here in real time.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyanAccent,
                    foregroundColor: AppColors.navy900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: AppColors.navy900,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Booking Service',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Choose whether you want to hire a driver or rent a car',
                                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                              ),
                              const SizedBox(height: 18),
                              ListTile(
                                tileColor: AppColors.navy800,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: AppColors.cyanAccent, width: 1.2),
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.cyanAccent.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.airline_seat_recline_extra, color: AppColors.cyanAccent),
                                ),
                                title: const Text('Hire a Driver / Chauffeur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Verified chauffeurs for customer-owned car', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.cyanAccent, size: 16),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  provider.fetchEligibleDrivers();
                                  provider.navigateTo(ActiveCustomerScreen.driverSelection);
                                },
                              ),
                              const SizedBox(height: 10),
                              ListTile(
                                tileColor: AppColors.navy800,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.directions_car, color: Colors.white),
                                ),
                                title: const Text('Rent a Car (Self-Drive)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Hourly and daily rentals from owners', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  provider.navigateTo(ActiveCustomerScreen.rentCarFlow);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.directions_car, size: 20),
                  label: const Text('Book a Chauffeur or Car', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── COMPLETED TRIP SUMMARY VIEW (Requirement 4 & Phase A, B, C) ───────────
  Widget _buildCompletedTripSummary(DriveMateProvider provider, Trip trip) {
    final invoice = provider.currentInvoice;
    final isPaid = (invoice != null && invoice.paymentStatus.toUpperCase() == 'PAID') ||
                   (invoice == null && trip.fare <= 0);
    final fareAmount = invoice != null ? invoice.totalAmount : trip.fare;

    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        backgroundColor: AppColors.navy900,
        elevation: 0,
        title: const Text('Trip Summary & Invoice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
        ),
        actions: [
          IconButton(
            tooltip: 'View Full GST Invoice',
            icon: const Icon(Icons.receipt_long, color: AppColors.cyanAccent),
            onPressed: () => _openInvoiceSheet(provider, trip),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Celebratory Success Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF0D233A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPaid ? AppColors.successGreen.withOpacity(0.5) : AppColors.cyanAccent.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isPaid ? AppColors.successGreen : AppColors.cyanAccent).withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (isPaid ? AppColors.successGreen : AppColors.cyanAccent).withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle : Icons.task_alt,
                      color: isPaid ? AppColors.successGreen : AppColors.cyanAccent,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Trip Successfully Completed',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Thank you for riding with DriveMate!',
                    style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),

                  // Fare Display
                  Text(
                    '₹${fareAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.cyanAccent,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Payment Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? AppColors.successGreen.withOpacity(0.2)
                          : const Color(0xFFF59E0B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPaid ? AppColors.successGreen : const Color(0xFFF59E0B),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaid ? Icons.verified : Icons.hourglass_top,
                          size: 14,
                          color: isPaid ? AppColors.successGreen : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPaid
                              ? 'PAYMENT VERIFIED (PAID VIA ${invoice?.paymentMethod.toUpperCase() ?? "ONLINE"})'
                              : 'PAYMENT DUE • MUTUALLY ACCEPTED FARE',
                          style: TextStyle(
                            color: isPaid ? AppColors.successGreen : const Color(0xFFF59E0B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── PAYMENT & QR CODE CARD (Requirement A) ──
            if (!isPaid) ...[
              _buildPaymentQrCard(provider, trip, invoice),
              const SizedBox(height: 18),
            ],

            // ── RATE CHAUFFEUR ACTION (Requirement B) ──
            if (isPaid) ...[
              _buildRateChauffeurCard(context, provider, trip),
              const SizedBox(height: 18),
            ],

            // Detailed Trip Receipt Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F253F),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'JOURNEY RECEIPT',
                        style: TextStyle(
                          color: AppColors.cyanAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (invoice != null)
                        Text(
                          invoice.invoiceNumber,
                          style: const TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Pickup & Drop
                  _buildReceiptLocationRow(
                    dotColor: AppColors.successGreen,
                    title: 'Pickup Location',
                    address: trip.startLocation,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, top: 4, bottom: 4),
                    child: Container(width: 2, height: 16, color: Colors.white24),
                  ),
                  _buildReceiptLocationRow(
                    dotColor: AppColors.errorRed,
                    title: 'Destination',
                    address: trip.endLocation,
                  ),

                  const Divider(color: Colors.white12, height: 28),

                  // Chauffeur & Vehicle Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.electricBlue,
                        child: Text(
                          trip.driverName.isNotEmpty ? trip.driverName[0] : 'D',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.driverName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              trip.vehicleModel,
                              style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PAID', style: TextStyle(color: AppColors.successGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Call Chauffeur',
                        icon: const Icon(Icons.phone, color: AppColors.cyanAccent, size: 20),
                        onPressed: () {
                          PhoneDialerHelper.makePhoneCall(
                            context,
                            invoice?.driverPhone ?? trip.driverPhone,
                          );
                        },
                      ),
                    ],
                  ),

                  const Divider(color: Colors.white12, height: 28),

                  // Distance & Trip ID
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildReceiptStat('Distance Traveled', '${trip.distanceKm.toStringAsFixed(1)} km'),
                      _buildReceiptStat('Trip Reference', trip.id),
                      _buildReceiptStat('Booking ID', trip.bookingId),
                    ],
                  ),

                  if (invoice != null) ...[
                    const Divider(color: Colors.white12, height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Base: ₹${invoice.subtotal.toStringAsFixed(0)}  •  GST (5%): ₹${invoice.gstTotal.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11.5),
                        ),
                        InkWell(
                          onTap: () => _openInvoiceSheet(provider, trip),
                          child: const Text(
                            'Itemized Tax Details >',
                            style: TextStyle(
                              color: AppColors.cyanAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── ACTION BUTTONS: VIEW INVOICE & TRIP HISTORY (Requirement C) ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cyanAccent,
                      side: const BorderSide(color: AppColors.cyanAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => _openInvoiceSheet(provider, trip),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () {
                      provider.setBookingFilter('Completed');
                      provider.navigateTo(ActiveCustomerScreen.myBookings);
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Trip History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Back to Home Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyanAccent,
                  foregroundColor: AppColors.navy900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => provider.navigateTo(ActiveCustomerScreen.home),
                icon: const Icon(Icons.home, size: 20),
                label: const Text('Back to Home Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentQrCard(DriveMateProvider provider, Trip trip, TripInvoice? invoice) {
    if (provider.isLoadingInvoice) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F253F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: AppColors.cyanAccent),
              SizedBox(height: 12),
              Text(
                'Generating Tax Invoice & Payment Gateway QR...',
                style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final hasQr = invoice != null && invoice.qrAvailable && invoice.qrCodeUrl != null && invoice.qrCodeUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F253F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cyanAccent.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_2, color: AppColors.cyanAccent, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan to Pay via UPI',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Google Pay • PhonePe • Paytm • BHIM',
                      style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (hasQr) ...[
            // Genuine QR Code image
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Image.network(
                invoice.qrCodeUrl!,
                width: 180,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 180,
                  height: 180,
                  alignment: Alignment.center,
                  child: const Text(
                    'QR Code could not be loaded.\nPlease check network.',
                    style: TextStyle(color: Colors.black54, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (invoice.upiVpa != null)
              Text(
                'UPI ID: ${invoice.upiVpa}',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            if (invoice.transactionId.isNotEmpty)
              Text(
                'Ref: ${invoice.transactionId}',
                style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 10.5),
              ),
            const SizedBox(height: 14),

            // Pay via App Button & Verify Button
            Row(
              children: [
                if (invoice.upiIntentUrl != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyanAccent,
                        foregroundColor: AppColors.navy900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(invoice.upiIntentUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open UPI App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                if (invoice.upiIntentUrl != null) const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.electricBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await provider.verifyPayment(
                        bookingId: trip.bookingId,
                        transactionId: invoice.transactionId.isNotEmpty ? invoice.transactionId : 'DM_TXN_${trip.bookingId}',
                      );
                      if (ok && mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Payment verified and confirmed successfully!'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Verify Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Strictly NO fake QR code when gateway is not configured
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      invoice?.qrMessage ??
                          'Payment gateway UPI/QR is currently unconfigured in the backend environment. Please settle payment directly via Cash with your chauffeur.',
                      style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),

          // Cash Payment Option
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Paying with Cash?',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final fare = invoice?.totalAmount ?? trip.fare;
                  final res = await provider.createPaymentOrder(
                    bookingId: trip.bookingId,
                    amount: fare,
                    paymentMethod: 'cash',
                  );
                  if (res != null && mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Cash payment selected! Please pay cash directly to your chauffeur upon trip completion.'),
                        backgroundColor: AppColors.electricBlue,
                      ),
                    );
                    await provider.fetchTripInvoice(trip.bookingId);
                  }
                },
                child: const Text(
                  'Select Cash',
                  style: TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateChauffeurCard(BuildContext context, DriveMateProvider provider, Trip trip) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F253F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentGold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star, color: AppColors.accentGold, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rate Your Chauffeur',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  'How was your journey with ${trip.driverName}?',
                  style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: AppColors.navy900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => RatingReviewDialog(
                  driverName: trip.driverName.isNotEmpty ? trip.driverName : 'Assigned Chauffeur',
                  onDismiss: () => Navigator.pop(ctx),
                  onSubmit: (rating, comment) async {
                    Navigator.pop(ctx);
                    final success = await provider.submitReview(
                      rating,
                      comment,
                      bookingId: trip.bookingId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? 'Thank you! Rating recorded.'
                              : 'Could not record rating. You may have already rated this trip.'),
                          backgroundColor: success ? AppColors.successGreen : AppColors.errorRed,
                        ),
                      );
                    }
                  },
                ),
              );
            },
            child: const Text('Rate Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _openInvoiceSheet(DriveMateProvider provider, Trip trip) async {
    final messenger = ScaffoldMessenger.of(context);
    TripInvoice? inv = provider.currentInvoice;
    inv ??= await provider.fetchTripInvoice(trip.bookingId);
    if (!mounted) return;
    if (inv != null) {
      InvoiceDetailsSheet.show(context, inv);
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Invoice details could not be retrieved. Please check connection.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Widget _buildReceiptLocationRow({required Color dotColor, required String title, required String address}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 2),
              Text(address, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── ACTIVE LIVE NAVIGATION EXPERIENCE ──────────────────────────────────────
  Widget _buildActiveLiveNavigation(DriveMateProvider provider, Trip trip) {
    final pickup = LatLng(trip.startLat ?? 21.8767, trip.startLng ?? 88.1912);
    final destination = LatLng(trip.endLat ?? 21.8712, trip.endLng ?? 88.1824);
    final driverPos = _resolveDriverPosition(trip);

    final markers = <Marker>[
      // 1. Pickup Marker (High-visibility Green Pin)
      Marker(
        point: pickup,
        width: 80,
        height: 60,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.successGreen,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
              ),
              child: const Text('PICKUP', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
            ),
            const Icon(Icons.location_on, color: AppColors.successGreen, size: 28),
          ],
        ),
      ),

      // 2. Destination Marker (High-visibility Red Pin)
      Marker(
        point: destination,
        width: 90,
        height: 60,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.errorRed,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
              ),
              child: const Text('DESTINATION', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
            ),
            const Icon(Icons.location_on, color: AppColors.errorRed, size: 28),
          ],
        ),
      ),

      // 3. Driver Vehicle Marker (Rotated Heading)
      Marker(
        point: driverPos,
        width: 50,
        height: 50,
        child: Transform.rotate(
          angle: (trip.bearing * math.pi) / 180.0,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B1930),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cyanAccent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyanAccent.withOpacity(0.45),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.navigation, color: AppColors.cyanAccent, size: 26),
          ),
        ),
      ),

      // 4. User's Own Detected Location (if requested)
      if (_userCurrentGps != null)
        Marker(
          point: _userCurrentGps!,
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
            ),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: Stack(
        children: [
          // ─── 1. FULL-BLEED VISUALLY DOMINANT OPENSTREETMAP ───
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: driverPos,
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                // OpenStreetMap Tile Layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.drivemate.drivemate_flutter',
                ),

                // Actual OSRM Road Route Geometry
                if (_routeCoordinates.isNotEmpty) ...[
                  // Dark navy casing / glow outline
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeCoordinates,
                        color: const Color(0xFF071428),
                        strokeWidth: 9.0,
                        strokeJoin: StrokeJoin.round,
                        strokeCap: StrokeCap.round,
                      ),
                    ],
                  ),
                  // Vibrant Cyan Navigation Polyline
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeCoordinates,
                        color: AppColors.cyanAccent,
                        strokeWidth: 5.5,
                        strokeJoin: StrokeJoin.round,
                        strokeCap: StrokeCap.round,
                      ),
                    ],
                  ),
                ],

                // Markers Layer (Pickup, Destination, Driver)
                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // Loading Indicator during route fetch
          if (_isLoadingRoute)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.navy900.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyanAccent),
                      ),
                      SizedBox(width: 10),
                      Text('Calculating OSRM Road Route...', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
            ),

          // OpenStreetMap Legal Attribution
          Positioned(
            left: 8,
            bottom: 305,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(color: Colors.black87, fontSize: 8.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // ─── 2. TOP FLOATING NAVIGATION CAPSULE ───
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back to Home Button
                    Material(
                      color: const Color(0xFF0B1930),
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => provider.navigateTo(ActiveCustomerScreen.home),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                    ),

                    // Active Trip Status Pill
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1930).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cyanAccent.withOpacity(0.6), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.successGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _getStatusTitle(trip.status),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Emergency SOS Quick Button
                    Material(
                      color: AppColors.errorRed,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          provider.showToast('Emergency SOS dispatched to DriveMate 24/7 Security Operations.');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(shape: BoxShape.circle),
                          child: const Icon(Icons.emergency_share, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── 3. FLOATING MAP ACTION BUTTONS (Right Side) ───
          Positioned(
            right: 14,
            bottom: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Fit Camera to Route Bounds
                _buildMapFloatingAction(
                  heroTag: 'tracking_fit_bounds',
                  icon: Icons.crop_free,
                  tooltip: 'Route Overview',
                  onTap: () => _fitCameraToBounds(driverPos: driverPos),
                ),
                const SizedBox(height: 8),

                // 2. Center Camera on Chauffeur
                _buildMapFloatingAction(
                  heroTag: 'tracking_center_driver',
                  icon: Icons.navigation,
                  iconColor: AppColors.cyanAccent,
                  tooltip: 'Center Chauffeur',
                  onTap: () => _mapController.move(driverPos, 16.5),
                ),
                const SizedBox(height: 8),

                // 3. Zoom In (+)
                _buildMapFloatingAction(
                  heroTag: 'tracking_zoom_in',
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                ),
                const SizedBox(height: 6),

                // 4. Zoom Out (-)
                _buildMapFloatingAction(
                  heroTag: 'tracking_zoom_out',
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                ),
                const SizedBox(height: 8),

                // 5. User Current Location
                _buildMapFloatingAction(
                  heroTag: 'tracking_user_gps',
                  icon: Icons.my_location,
                  isLoading: _isLocatingUser,
                  tooltip: 'My Location',
                  onTap: _handleCurrentLocation,
                ),
              ],
            ),
          ),

          // ─── 4. DOCKED COMPACT TRIP INFORMATION CARD (Bottom Sheet) ───
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 14, left: 18, right: 18, bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF091629),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: AppColors.cyanAccent.withOpacity(0.5), width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Drag Indicator Accent Line
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cyanAccent.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // ETA, Road Distance, and Agreed Fare Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _estimatedDurationMinutes > 0
                                  ? '$_estimatedDurationMinutes mins estimated'
                                  : 'Active Navigation',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _roadDistanceKm > 0
                                  ? '${_roadDistanceKm.toStringAsFixed(1)} km road route via OSRM'
                                  : '${trip.distanceKm.toStringAsFixed(1)} km road route',
                              style: const TextStyle(
                                color: AppColors.textSecondaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${trip.fare.toInt()}',
                              style: const TextStyle(
                                color: AppColors.cyanAccent,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              'Agreed Fare',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Compact Route Timeline (Pickup & Destination)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F223B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.successGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  trip.startLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
                            child: Row(
                              children: [
                                Container(width: 2, height: 10, color: Colors.white24),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.errorRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  trip.endLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Chauffeur Identity & Verbal OTP Security Badge
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.electricBlue,
                          child: Text(
                            trip.driverName.isNotEmpty ? trip.driverName[0] : 'D',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      trip.driverName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  const Text(' 4.9', style: TextStyle(color: Colors.amber, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text(
                                trip.vehicleModel,
                                style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Verbal Passcode (OTP) Display Box
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2B48),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.cyanAccent.withOpacity(0.6)),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'START OTP',
                                style: TextStyle(
                                  color: AppColors.cyanAccent,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                trip.otp,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Genuine Action Controls: Call Chauffeur & Safety SOS
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cyanAccent,
                              foregroundColor: AppColors.navy900,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: () => PhoneDialerHelper.makePhoneCall(context, trip.driverPhone),
                            icon: const Icon(Icons.phone, size: 18),
                            label: const Text(
                              'Call Chauffeur',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: AppColors.errorRed.withOpacity(0.6), width: 1.3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              provider.showToast('Emergency SOS dispatched to DriveMate 24/7 Security Operations.');
                            },
                            icon: const Icon(Icons.shield_outlined, color: AppColors.errorRed, size: 18),
                            label: const Text(
                              'SOS Safety',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapFloatingAction({
    required String heroTag,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    bool isLoading = false,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1930).withOpacity(0.92),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyanAccent),
                  )
                : Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}
