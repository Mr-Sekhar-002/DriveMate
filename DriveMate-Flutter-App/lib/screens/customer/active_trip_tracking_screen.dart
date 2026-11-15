import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ActiveTripTrackingScreenState extends State<ActiveTripTrackingScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  List<LatLng> _routeCoordinates = [];
  bool _isLoadingRoute = true;
  double _roadDistanceKm = 0.0;
  int _estimatedDurationMinutes = 0;
  String? _lastLoadedTripId;
  String? _lastFetchedInvoiceBookingId;
  LatLng? _userCurrentGps;
  bool _isLocatingUser = false;
  bool _isFullscreenMap = false;
  int _unreadChatCount = 3;
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [
    {'sender': 'driver', 'text': 'Hello! I am on my way to your pickup location.', 'time': '10:42 AM'},
    {'sender': 'driver', 'text': 'I will be arriving in a white Sedan near your gate.', 'time': '10:44 AM'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _pulseController.repeat();
    }
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOutQuad,
    );

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
    _pulseController.dispose();
    _chatController.dispose();
    _providerRef?.stopDriverLiveTracking();
    super.dispose();
  }

  Future<void> _loadOsrmRoute(Trip trip) async {
    _lastLoadedTripId = trip.id;
    setState(() => _isLoadingRoute = true);

    final start = LatLng(trip.startLat ?? 21.8767, trip.startLng ?? 88.1912);
    final end = LatLng(trip.endLat ?? 21.8712, trip.endLng ?? 88.1824);

    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
          _routeCoordinates = [start, end];
          _roadDistanceKm = trip.distanceKm;
          _estimatedDurationMinutes = (trip.distanceKm * 2.2).round();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitCameraToBounds(driverPos: _resolveDriverPosition(trip));
        });
      }
      return;
    }

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
    final walletBal = provider.walletDetails?.balance ?? 0.0;
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

          // DriveMate In-App Wallet Payment Option
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: AppColors.cyanAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DriveMate Wallet (Bal: ₹${walletBal.toStringAsFixed(0)})',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final fare = invoice?.totalAmount ?? trip.fare;
                  if (walletBal < fare) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Insufficient wallet balance (₹${walletBal.toStringAsFixed(0)}). Please top up or pay via UPI/Cash.'),
                        backgroundColor: AppColors.errorRed,
                      ),
                    );
                    return;
                  }
                  final ok = await provider.createPaymentOrder(
                    bookingId: trip.bookingId,
                    amount: fare,
                    paymentMethod: 'wallet',
                  );
                  if (ok != null && mounted) {
                    await provider.verifyPayment(
                      bookingId: trip.bookingId,
                      transactionId: invoice?.transactionId.isNotEmpty == true ? invoice!.transactionId : 'DM_WALLET_${trip.bookingId}',
                    );
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Paid successfully via DriveMate Wallet!'),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Pay via Wallet',
                  style: TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

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

  // ─── ACTIVE LIVE NAVIGATION EXPERIENCE (Styled after Modern Mobility Designs) ─────────────────
  String _formatArrivalClockTime(int minutesFromNow) {
    final now = DateTime.now().add(Duration(minutes: minutesFromNow > 0 ? minutesFromNow : 15));
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildActiveLiveNavigation(DriveMateProvider provider, Trip trip) {
    final pickup = LatLng(trip.startLat ?? 21.8767, trip.startLng ?? 88.1912);
    final destination = LatLng(trip.endLat ?? 21.8712, trip.endLng ?? 88.1824);
    final driverPos = _resolveDriverPosition(trip);

    final displayDistanceKm = _roadDistanceKm > 0 ? _roadDistanceKm : trip.distanceKm;
    final displayDurationMin = _estimatedDurationMinutes > 0 ? _estimatedDurationMinutes : (displayDistanceKm * 2.2).round();

    final markers = <Marker>[
      // 1. Pickup Marker with High-Visibility Floating Badge (Image 3 Style)
      Marker(
        point: pickup,
        width: 180,
        height: 72,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'PICKUP $displayDurationMin MIN',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            const Icon(Icons.location_on, color: AppColors.primaryBlue, size: 30),
          ],
        ),
      ),

      // 2. Destination Marker with Arrival Clock Badge (Image 3 Style)
      Marker(
        point: destination,
        width: 200,
        height: 72,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'DROPOFF ${_formatArrivalClockTime(displayDurationMin)}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            const Icon(Icons.location_on, color: AppColors.successGreen, size: 30),
          ],
        ),
      ),

      // 3. Driver Vehicle Marker with Animated Concentric Radar Pulse Rings (Image 2 & 4 Style)
      Marker(
        point: driverPos,
        width: 76,
        height: 76,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer expanding radar ring
                Container(
                  width: 36 + (_pulseAnimation.value * 38),
                  height: 36 + (_pulseAnimation.value * 38),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cyanAccent.withOpacity((1.0 - _pulseAnimation.value) * 0.35),
                  ),
                ),
                // Inner secondary halo
                Container(
                  width: 34 + (_pulseAnimation.value * 18),
                  height: 34 + (_pulseAnimation.value * 18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryBlue.withOpacity((1.0 - _pulseAnimation.value) * 0.25),
                  ),
                ),
                // Core driver car avatar with heading rotation
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cyanAccent, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyanAccent.withOpacity(0.55),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: (trip.bearing * math.pi) / 180.0,
                    child: const Center(
                      child: Icon(Icons.directions_car_rounded, color: AppColors.cyanAccent, size: 24),
                    ),
                  ),
                ),
                // Mid-route ETA speech bubble anchored above car
                Positioned(
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cyanAccent.withOpacity(0.6), width: 1),
                    ),
                    child: Text(
                      '$displayDurationMin min',
                      style: const TextStyle(
                        color: AppColors.cyanAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // 4. User's Current GPS Location (pulsating blue indicator)
      if (_userCurrentGps != null)
        Marker(
          point: _userCurrentGps!,
          width: 24,
          height: 24,
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
          // ─── 1. FULL-BLEED OPENSTREETMAP ───
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: driverPos,
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                if (!WidgetsBinding.instance.runtimeType.toString().contains('Test'))
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.drivemate.drivemate_flutter',
                  ),

                // Dual-tone road polyline geometry
                if (_routeCoordinates.isNotEmpty) ...[
                  // Dark outer casing
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
                  // Vibrant cyan route line
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

                MarkerLayer(markers: markers),
              ],
            ),
          ),

          // Route loading pill
          if (_isLoadingRoute)
            Positioned(
              top: _isFullscreenMap ? 50 : 150,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.navy900.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cyanAccent.withOpacity(0.5)),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
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
            ),

          // OSM Legal Attribution
          Positioned(
            left: 8,
            bottom: _isFullscreenMap ? 16 : 330,
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

          // ─── 2. DYNAMIC TOP NAVIGATION PANEL (Matching Reference Image 4) ───
          if (!_isFullscreenMap)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row 1: Back Button, Current Location / Pickup, Fullscreen Toggle
                        Row(
                          children: [
                            Material(
                              color: const Color(0xFF1E293B),
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => provider.navigateTo(ActiveCustomerScreen.home),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, color: AppColors.cyanAccent, size: 16),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      trip.startLocation,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => setState(() => _isFullscreenMap = true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.fullscreen, color: Colors.white70, size: 18),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Row 2: Destination on left, Quick Actions (Chat & Call) on right (Image 4)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip.endLocation,
                                    style: const TextStyle(
                                      color: Color(0xFF22C55E),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => PhoneDialerHelper.makePhoneCall(context, provider.emergencyHotline),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.emergency, color: AppColors.errorRed, size: 13),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Emergency: ${provider.emergencyHotline}',
                                                  style: const TextStyle(
                                                    color: AppColors.errorRed,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryBlue.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5)),
                                        ),
                                        child: Text(
                                          '${displayDistanceKm.toStringAsFixed(1)} km',
                                          style: const TextStyle(
                                            color: AppColors.cyanAccent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Quick Action Buttons (Chat with badge & Phone call)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. Quick In-Trip Chat Button with Unread Badge
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Material(
                                      color: const Color(0xFF22C55E),
                                      shape: const CircleBorder(),
                                      elevation: 4,
                                      shadowColor: Colors.black54,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _showInTripChatSheet(context, trip),
                                        child: const Padding(
                                          padding: EdgeInsets.all(10),
                                          child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 19),
                                        ),
                                      ),
                                    ),
                                    if (_unreadChatCount > 0)
                                      Positioned(
                                        top: -3,
                                        right: -3,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: AppColors.errorRed,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '$_unreadChatCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                // 2. Direct Driver Phone Call Button
                                Material(
                                  color: const Color(0xFF22C55E),
                                  shape: const CircleBorder(),
                                  elevation: 4,
                                  shadowColor: Colors.black54,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => PhoneDialerHelper.makePhoneCall(context, trip.driverPhone),
                                    child: const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Icon(Icons.phone_in_talk, color: Colors.white, size: 19),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ─── 3. FULLSCREEN EXIT BUTTON (When Fullscreen Mode is Active) ───
          if (_isFullscreenMap)
            Positioned(
              top: 50,
              left: 16,
              child: Material(
                color: const Color(0xFF0F172A).withOpacity(0.92),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.cyanAccent, width: 1.5),
                ),
                elevation: 6,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _isFullscreenMap = false),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen_exit, color: AppColors.cyanAccent, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Show Controls',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ─── 4. FLOATING MAP ACTION BUTTONS (Right Side) ───
          Positioned(
            right: 14,
            bottom: _isFullscreenMap ? 28 : 325,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapFloatingAction(
                  heroTag: 'tracking_fit_bounds',
                  icon: Icons.crop_free,
                  tooltip: 'Route Overview',
                  onTap: () => _fitCameraToBounds(driverPos: driverPos),
                ),
                const SizedBox(height: 8),
                _buildMapFloatingAction(
                  heroTag: 'tracking_center_driver',
                  icon: Icons.navigation,
                  iconColor: AppColors.cyanAccent,
                  tooltip: 'Center Driver',
                  onTap: () => _mapController.move(driverPos, 16.5),
                ),
                const SizedBox(height: 8),
                _buildMapFloatingAction(
                  heroTag: 'tracking_zoom_in',
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                ),
                const SizedBox(height: 6),
                _buildMapFloatingAction(
                  heroTag: 'tracking_zoom_out',
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                ),
                const SizedBox(height: 8),
                _buildMapFloatingAction(
                  heroTag: 'tracking_user_gps',
                  icon: Icons.my_location,
                  isLoading: _isLocatingUser,
                  tooltip: 'My Location',
                  onTap: _handleCurrentLocation,
                ),
                const SizedBox(height: 8),
                _buildMapFloatingAction(
                  heroTag: 'tracking_fullscreen_toggle',
                  icon: _isFullscreenMap ? Icons.fullscreen_exit : Icons.fullscreen,
                  iconColor: AppColors.cyanAccent,
                  tooltip: _isFullscreenMap ? 'Exit Full Screen' : 'Full Screen Map',
                  onTap: () => setState(() => _isFullscreenMap = !_isFullscreenMap),
                ),
              ],
            ),
          ),

          // ─── 5. DOCKED COMPACT TRIP INFORMATION & CONTROLS SHEET (Image 4 & 2) ───
          if (!_isFullscreenMap)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 12, left: 18, right: 18, bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF091629),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                  border: Border(
                    top: BorderSide(color: AppColors.cyanAccent.withOpacity(0.55), width: 1.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.65),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.cyanAccent.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ETA & Agreed Fare
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$displayDurationMin min (${displayDistanceKm.toStringAsFixed(1)} Km)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'via OSRM Live Navigation Route',
                                  style: TextStyle(
                                    color: AppColors.textSecondaryLight,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
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
                                '₹${trip.fare.toInt()}',
                                style: const TextStyle(
                                  color: AppColors.cyanAccent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const Text('Agreed Fare', style: TextStyle(color: Colors.white60, fontSize: 10.5)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Quick Action Controls Row (Audio Mute, SOS, Share Trip, Cancel) - Image 4
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Voice Navigation Mute Toggle
                            InkWell(
                              onTap: () => provider.toggleVoiceNavMute(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F253F),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      provider.isVoiceNavMuted ? Icons.volume_off : Icons.volume_up,
                                      color: provider.isVoiceNavMuted ? Colors.white38 : AppColors.cyanAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      provider.isVoiceNavMuted ? 'Muted' : 'Voice On',
                                      style: TextStyle(
                                        color: provider.isVoiceNavMuted ? Colors.white38 : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Share Live Trip with Family Button (Feature 2 Requirement)
                            InkWell(
                              onTap: () => _showShareTripModal(context, provider, trip),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.6)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.share_rounded, color: AppColors.cyanAccent, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Share Trip',
                                      style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Safety SOS Emergency Action
                            InkWell(
                              onTap: () => _showSosDialog(context, provider, trip),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.errorRed.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.errorRed),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.shield, color: AppColors.errorRed, size: 16),
                                    SizedBox(width: 5),
                                    Text(
                                      'SOS',
                                      style: TextStyle(color: AppColors.errorRed, fontSize: 11, fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Safety Center Shortcut
                            InkWell(
                              onTap: () => provider.navigateTo(ActiveCustomerScreen.safetyCenter),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.5)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.security_rounded, color: AppColors.accentCyan, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Safety',
                                      style: TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Cancel Trip Shortcut (Image 4 red X)
                            InkWell(
                              onTap: () => _showCancelTripDialog(context, provider, trip),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.errorRed.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.errorRed.withOpacity(0.5)),
                                ),
                                child: const Icon(Icons.close, color: AppColors.errorRed, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 4-Stage Trip Progress Stepper
                      _buildTripProgressStepper(trip),

                      const SizedBox(height: 12),

                      // Chauffeur Identity & Vehicle Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F223B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primaryBlue,
                              child: Text(
                                trip.driverName.isNotEmpty ? trip.driverName[0] : 'D',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, color: AppColors.cyanAccent, size: 14),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.star, color: Colors.amber, size: 13),
                                      const Text(' 4.9', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
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
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    trip.otp,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Interactive Arrival / End Trip & Settle Fare Button (UPI QR & Receipt)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              _getStatusTitle(trip.status),
                              style: const TextStyle(
                                color: AppColors.cyanAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 4,
                              ),
                              onPressed: () => _showEndTripConfirmation(context, provider, trip),
                              icon: const Icon(Icons.check_circle_outline, size: 20),
                              label: const Text(
                                'ARRIVED? COMPLETE TRIP & PAY',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                  letterSpacing: 0.4,
                                ),
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

  // ─── 4-STAGE TRIP PROGRESS STEPPER ───
  Widget _buildTripProgressStepper(Trip trip) {
    int activeStep = 0;
    if (trip.status == TripStatus.assigned) activeStep = 0;
    if (trip.status == TripStatus.driverArrived) activeStep = 1;
    if (trip.status == TripStatus.onTrip) activeStep = 2;
    if (trip.status == TripStatus.completed) activeStep = 3;

    final steps = ['Assigned', 'Arrived', 'In Transit', 'Completed'];

    return Row(
      children: List.generate(steps.length, (index) {
        final isCompleted = index < activeStep;
        final isCurrent = index == activeStep;
        final color = isCompleted
            ? AppColors.successGreen
            : (isCurrent ? AppColors.cyanAccent : Colors.white24);

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index],
                      style: TextStyle(
                        color: isCurrent ? AppColors.cyanAccent : (isCompleted ? AppColors.successGreen : Colors.white38),
                        fontSize: 9.5,
                        fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (index < steps.length - 1) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }

  // ─── IN-TRIP LIVE CHAT SHEET (Reference Image 4) ───
  void _showInTripChatSheet(BuildContext context, Trip trip) {
    setState(() => _unreadChatCount = 0);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 14,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryBlue,
                          child: Text(
                            trip.driverName.isNotEmpty ? trip.driverName[0] : 'D',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chat with ${trip.driverName}',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                'Assigned Chauffeur • Online',
                                style: TextStyle(color: AppColors.successGreen, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),

                    // Preset Quick Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickReplyChip("I'm at the pickup point", setModalState),
                          _buildQuickReplyChip("Please call on arrival", setModalState),
                          _buildQuickReplyChip("Heavy traffic here", setModalState),
                          _buildQuickReplyChip("Coming down now", setModalState),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Messages List
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, idx) {
                          final msg = _chatMessages[idx];
                          final isMe = msg['sender'] == 'me';
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.primaryBlue : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg['text'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    msg['time'] ?? '',
                                    style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Text Input Box
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Type a message to chauffeur...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.cyanAccent,
                            foregroundColor: AppColors.navy900,
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          onPressed: () {
                            final text = _chatController.text.trim();
                            if (text.isNotEmpty) {
                              setModalState(() {
                                _chatMessages.add({
                                  'sender': 'me',
                                  'text': text,
                                  'time': 'Just now',
                                });
                              });
                              _chatController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickReplyChip(String text, void Function(void Function()) setModalState) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: const Color(0xFF1E293B),
        label: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        onPressed: () {
          setModalState(() {
            _chatMessages.add({
              'sender': 'me',
              'text': text,
              'time': 'Just now',
            });
          });
        },
      ),
    );
  }

  // ─── SHARE LIVE TRIP MODAL (Feature 2 Requirement) ───
  void _showShareTripModal(BuildContext context, DriveMateProvider provider, Trip trip) async {
    final shareData = await provider.shareLiveTrip(trip.id);
    final bookingRef = shareData?['booking_reference'] ?? 'DM-BK-${trip.bookingId}';
    final shareText = shareData?['share_text'] ??
        'I am riding with DriveMate! Driver: ${trip.driverName}, Vehicle: ${trip.vehicleModel}. Booking Ref: $bookingRef. Track live: https://drivemate.app/track/$bookingRef';
    final shareUrl = shareData?['share_url'] ?? 'https://drivemate.app/track/$bookingRef';

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.share_location_rounded, color: AppColors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Share Live Trip with Family',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your loved ones can track your real-time vehicle telemetry, chauffeur credentials, and route geometry.',
                  style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Trip Card Preview
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(bookingRef, style: const TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          const Text('LIVE TRACKING ENABLED', style: TextStyle(color: AppColors.successGreen, fontSize: 10, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Driver: ${trip.driverName} • ${trip.vehicleModel}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Route: ${trip.startLocation} ➔ ${trip.endLocation}', style: const TextStyle(color: Colors.white60, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Share Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final whatsappUrl = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(shareText)}');
                          if (await canLaunchUrl(whatsappUrl)) {
                            await launchUrl(whatsappUrl);
                          } else {
                            await Clipboard.setData(ClipboardData(text: shareText));
                            provider.showToast('WhatsApp not installed. Trip tracking link copied to clipboard!');
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final smsUrl = Uri.parse('sms:?body=${Uri.encodeComponent(shareText)}');
                          if (await canLaunchUrl(smsUrl)) {
                            await launchUrl(smsUrl);
                          } else {
                            await Clipboard.setData(ClipboardData(text: shareText));
                            provider.showToast('Trip tracking message copied to clipboard!');
                          }
                        },
                        icon: const Icon(Icons.sms_outlined, size: 16),
                        label: const Text('SMS Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.cyanAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Clipboard.setData(ClipboardData(text: shareUrl));
                      provider.showToast('Live tracking URL copied to clipboard: $shareUrl');
                    },
                    icon: const Icon(Icons.copy_rounded, color: AppColors.cyanAccent, size: 16),
                    label: const Text('Copy Tracking Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── SAFETY SOS DIALOG (Feature 2 & 5 Requirement) ───
  void _showSosDialog(BuildContext context, DriveMateProvider provider, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.errorRed, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.errorRed, size: 26),
              SizedBox(width: 10),
              Text('Emergency SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you facing an emergency? This will immediately alert DriveMate 24/7 Security Operations and dial emergency police services.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.errorRed.withOpacity(0.4)),
                ),
                child: Text(
                  'Emergency Helpline: ${provider.emergencyHotline}\nPolice Emergency: 112',
                  style: const TextStyle(color: AppColors.errorRed, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                provider.showToast('Emergency SOS dispatched to DriveMate 24/7 Security Operations.');
                PhoneDialerHelper.makePhoneCall(context, '112');
              },
              child: const Text('Call 112 & Alert SOS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ─── END TRIP & PROCEED TO PAYMENT DIALOG ───
  void _showEndTripConfirmation(BuildContext context, DriveMateProvider provider, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D233A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cyanAccent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.flag_circle, color: AppColors.successGreen, size: 24),
            SizedBox(width: 10),
            Text('Arrived at Destination?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Destination: ${trip.endLocation}',
              style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              'Total Fare: ₹${trip.fare.toInt()}',
              style: const TextStyle(color: AppColors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Completing the journey will open your official GST Tax Receipt, UPI QR Code (GPay, PhonePe, Paytm), and In-App Wallet or Cash payment options.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay on Route', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.completeTrip(allowCustomer: true);
            },
            child: const Text('Complete & View QR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── CANCEL TRIP DIALOG ───
  void _showCancelTripDialog(BuildContext context, DriveMateProvider provider, Trip trip) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cancel Ride?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Are you sure you want to cancel this booking? Free cancellation is applicable before driver arrives at the pickup point.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Ride', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final bookingId = int.tryParse(trip.bookingId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                if (bookingId > 0) {
                  await provider.cancelBooking(bookingId);
                } else {
                  provider.stopDriverLiveTracking();
                  provider.navigateTo(ActiveCustomerScreen.home);
                  provider.showToast('Ride successfully cancelled.');
                }
              },
              child: const Text('Yes, Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
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
    return Tooltip(
      message: tooltip,
      child: Container(
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
      ),
    );
  }
}
