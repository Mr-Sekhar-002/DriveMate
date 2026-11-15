import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/drivemate_provider.dart';
import '../../models/drivemate_models.dart';
import '../../theme/app_theme.dart';
import '../../components/live_trip_map_card.dart';
import '../../components/fare_negotiation_dialog.dart';
import '../../helpers/phone_dialer_helper.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  /// Unified Call Customer handler:
  /// 1. Fetches authentic customer phone number from PHP/MySQL backend if not in memory.
  /// 2. Launches external Android phone dialer using `tel:` URI with `LaunchMode.externalApplication`.
  /// 3. Does not use CALL_PHONE permission or auto-call.
  /// 4. Shows clear user-facing error message if phone is missing or invalid.
  static Future<void> handleCallCustomer(
    BuildContext context,
    DriveMateProvider provider, {
    String? bookingId,
    String? phone,
  }) async {
    String? targetPhone = phone?.trim();

    // Fetch customer's actual phone from backend if not already populated
    if ((targetPhone == null || targetPhone.isEmpty) && bookingId != null && bookingId.isNotEmpty) {
      targetPhone = await provider.fetchCustomerPhoneFromBackend(bookingId);
    }

    if (!context.mounted) return;

    await PhoneDialerHelper.makePhoneCall(context, targetPhone);
  }

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DriveMateProvider>().fetchDriverBackendData();
      }
    });
  }

  Future<void> _openNavigationApp(BuildContext context, double? lat, double? lng, String address) async {
    final Uri mapUri = (lat != null && lng != null)
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')
        : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}');
    try {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Routing to: $address')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigating towards: $address')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final profile = provider.driverProfile;
    final activeTrip = provider.activeTrip;
    final incomingRequest = provider.incomingDriverRequest;

    final activeBooking = activeTrip != null
        ? provider.bookings.cast<Booking?>().firstWhere(
            (b) => b?.id == activeTrip.bookingId || b?.id == 'BK-${activeTrip.bookingId}',
            orElse: () => null,
          )
        : incomingRequest;

    return RefreshIndicator(
      onRefresh: () => provider.fetchDriverBackendData(),
      color: AppColors.cyanAccent,
      backgroundColor: AppColors.navy900,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backend Error Banner (if connection failed)
            if (provider.backendError != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E1C05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentGold.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: AppColors.accentGold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        provider.backendError!,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.cyanAccent,
                      ),
                      onPressed: () => provider.fetchDriverBackendData(),
                      child: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          // ─── Top Header: Driver Status & Online Duty Toggle ─────────────
          Card(
            color: AppColors.navy900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: AppColors.electricBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.airline_seat_recline_extra, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          profile.driverName,
                                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified, color: AppColors.cyanAccent, size: 16),
                                    ],
                                  ),
                                  Text(
                                    'License: ${profile.licenseNumber} • Rating: ${profile.rating}★',
                                    style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Help & Support Shortcut
                      IconButton(
                        icon: const Icon(Icons.help_outline, color: AppColors.cyanAccent, size: 22),
                        tooltip: 'Help & Support',
                        onPressed: () => provider.navigateTo(ActiveCustomerScreen.helpSupport),
                      ),

                      // Online / Offline Switch
                      Column(
                        children: [
                          Switch(
                            value: profile.isOnline,
                            activeColor: AppColors.successGreen,
                            activeTrackColor: AppColors.successGreen.withOpacity(0.3),
                            onChanged: (_) => provider.toggleDriverOnline(),
                          ),
                          Text(
                            profile.isOnline ? 'ONLINE' : 'OFFLINE',
                            style: TextStyle(
                              color: profile.isOnline ? AppColors.successGreen : Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
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

          const SizedBox(height: 12),

          // ─── Today's Metrics Overview ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Today\'s Earnings',
                  value: '₹${profile.earningsToday.toInt()}',
                  subtitle: 'Direct UPI Payout Ready',
                  icon: Icons.account_balance_wallet,
                  color: AppColors.cyanAccent,
                  onTap: () => _openMyEarningsSheet(context, provider),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Trips',
                  value: '${profile.totalTrips}',
                  subtitle: '4.9★ Top Rating',
                  icon: Icons.local_taxi,
                  color: AppColors.accentGold,
                  onTap: () => _openTripHistorySheet(context, provider),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ─── Section 4: Driver Account Action Hub ──────────────────────
          _buildDriverAccountHub(context, provider, activeBooking, activeTrip),

          const SizedBox(height: 16),

          // ─── Section 1: Booking Requests ───────────────────────────────
          if (incomingRequest != null && profile.isOnline) ...[
            _buildBookingRequestCard(context, provider, incomingRequest),
            const SizedBox(height: 16),
          ],

          // ─── Section 2 & 3: Active Trip Management (En Route / Arrived / On Trip)
          if (activeTrip != null && activeTrip.status != TripStatus.completed) ...[
            // Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Trip Operations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeTrip.status == TripStatus.onTrip
                        ? AppColors.successGreen.withOpacity(0.2)
                        : (activeTrip.status == TripStatus.driverArrived
                            ? AppColors.accentGold.withOpacity(0.2)
                            : AppColors.cyanAccent.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: activeTrip.status == TripStatus.onTrip
                          ? AppColors.successGreen
                          : (activeTrip.status == TripStatus.driverArrived ? AppColors.accentGold : AppColors.cyanAccent),
                    ),
                  ),
                  child: Text(
                    activeTrip.status.label.toUpperCase(),
                    style: TextStyle(
                      color: activeTrip.status == TripStatus.onTrip
                          ? AppColors.successGreen
                          : (activeTrip.status == TripStatus.driverArrived ? AppColors.accentGold : AppColors.cyanAccent),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Section 2: Pickup Management Card (When Driver Assigned & heading to pickup)
            if (activeTrip.status == TripStatus.assigned) ...[
              _buildPickupManagementCard(context, provider, activeTrip, activeBooking),
              const SizedBox(height: 14),
            ],

            // Section 3: Trip Management OTP Verification Card (When Driver Arrived at pickup)
            if (activeTrip.status == TripStatus.driverArrived) ...[
              _buildTripManagementOtpCard(context, provider, activeTrip, activeBooking),
              const SizedBox(height: 14),
            ],

            // Active OSRM Route Navigation (Available across all active trip stages)
            LiveTripMapCard(
              trip: activeTrip,
              booking: activeBooking,
              isOnline: profile.isOnline,
              onSimulateStep: () => provider.simulateTripStep(),
              onCompleteTrip: activeTrip.status == TripStatus.onTrip ? () => provider.completeTrip() : null,
              onDismissCompleted: () => provider.clearActiveTrip(),
            ),
          ] else if (activeTrip != null && activeTrip.status == TripStatus.completed) ...[
            // Completed Trip Summary & Receipt Card
            LiveTripMapCard(
              trip: activeTrip,
              booking: activeBooking,
              isOnline: profile.isOnline,
              onSimulateStep: () {},
              onDismissCompleted: () => provider.clearActiveTrip(),
              onCollectCash: () => provider.collectCashPayment(
                    bookingId: activeTrip.bookingId,
                    amount: activeTrip.fare,
                  ),
            ),
          ] else ...[
            // Idle Radar Map for New / Idle Driver: Live GPS map centered on driver, "You are Online – Waiting for Booking"
            LiveTripMapCard(
              trip: null,
              booking: null,
              isOnline: profile.isOnline,
              onSimulateStep: () {},
            ),
          ],
        ],
      ),
    ),
  );
}

  // ─── Metric Card Helper ──────────────────────────────────────────────
  static Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ),
  );
}

  // ─── Section 4: Driver Account Action Hub ────────────────────────────
  Widget _buildDriverAccountHub(
    BuildContext context,
    DriveMateProvider provider,
    Booking? activeBooking,
    Trip? activeTrip,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_accounts, color: AppColors.electricBlue, size: 16),
              SizedBox(width: 6),
              Text(
                'Driver Account & Services',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAccountButton(
                  icon: Icons.history,
                  label: 'Trip History',
                  color: AppColors.electricBlue,
                  onTap: () => _openTripHistorySheet(context, provider),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAccountButton(
                  icon: Icons.account_balance_wallet,
                  label: 'My Earnings',
                  color: AppColors.successGreen,
                  onTap: () => _openMyEarningsSheet(context, provider),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAccountButton(
                  icon: Icons.person_pin,
                  label: 'Customer Details',
                  color: const Color(0xFF0284C7),
                  onTap: () => _openCustomerDetailsSheet(context, provider, activeBooking, activeTrip),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAccountButton(
                  icon: Icons.support_agent,
                  label: 'Support & SOS',
                  color: AppColors.accentGold,
                  onTap: () => _openSupportSheet(context, provider),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Section 1: Booking Request Card ─────────────────────────────────
  Widget _buildBookingRequestCard(
    BuildContext context,
    DriveMateProvider provider,
    Booking incomingRequest,
  ) {
    final hasNegotiated = incomingRequest.negotiatedFare != null &&
        incomingRequest.negotiatedFare != incomingRequest.totalAmount;
    final displayFare = (incomingRequest.negotiatedFare ?? incomingRequest.totalAmount).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F264A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGold.withOpacity(0.2),
            blurRadius: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  incomingRequest.negotiationStatus == 'PENDING' ? 'CUSTOMER FARE OFFER' : 'INCOMING RIDE REQUEST',
                  style: const TextStyle(color: AppColors.navy900, fontSize: 10.5, fontWeight: FontWeight.w900),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasNegotiated) ...[
                    Text(
                      '₹${incomingRequest.totalAmount.toInt()}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12, decoration: TextDecoration.lineThrough),
                    ),
                    Text(
                      '₹$displayFare',
                      style: const TextStyle(color: AppColors.cyanAccent, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ] else ...[
                    Text(
                      '₹$displayFare',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Customer: ${incomingRequest.userName}',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(
            'Car: ${incomingRequest.customerCarModel ?? "Sedan"} • ${incomingRequest.hoursOrDaysText}',
            style: const TextStyle(color: AppColors.cyanAccent, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.trip_origin, size: 14, color: AppColors.cyanAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  incomingRequest.pickupLocation,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.accentGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  incomingRequest.destination,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Functional Action Buttons: Reject Booking, Negotiate Fare, Accept Booking
          Row(
            children: [
              // 1. Reject Booking
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => provider.rejectDriverRequest(incomingRequest.id),
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Negotiate Fare
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyanAccent,
                    side: const BorderSide(color: AppColors.cyanAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => FareNegotiationDialog.show(context, incomingRequest),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Negotiate', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),

              // 3. Accept Booking
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => provider.acceptDriverRequest(incomingRequest),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    'Accept ₹$displayFare',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section 2: Pickup Management Card ───────────────────────────────
  Widget _buildPickupManagementCard(
    BuildContext context,
    DriveMateProvider provider,
    Trip trip,
    Booking? booking,
  ) {
    final customerPhone = booking?.customerPhone ?? trip.customerPhone;
    final customerName = booking?.userName ?? trip.customerName ?? 'Customer';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F3D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyanAccent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccent.withOpacity(0.12),
            blurRadius: 10,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cyanAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car, color: AppColors.cyanAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'PICKUP MANAGEMENT',
                    style: TextStyle(
                      color: AppColors.cyanAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'EN ROUTE TO PICKUP',
                  style: TextStyle(color: AppColors.cyanAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Passenger: $customerName',
            style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 15, color: AppColors.accentGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pickup: ${trip.startLocation}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Pickup Functional Buttons: Navigate to Pickup, I've Arrived, Call Customer
          Row(
            children: [
              // 1. Navigate to Pickup
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => _openNavigationApp(context, trip.startLat, trip.startLng, trip.startLocation),
                  icon: const Icon(Icons.navigation, size: 15, color: AppColors.cyanAccent),
                  label: const Text('Navigate', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Call Customer
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => DriverDashboardScreen.handleCallCustomer(
                    context,
                    provider,
                    bookingId: booking?.id ?? trip.bookingId,
                    phone: customerPhone,
                  ),
                  icon: const Icon(Icons.call, size: 15, color: AppColors.successGreen),
                  label: const Text('Call', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),

              // 3. I've Arrived
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyanAccent,
                    foregroundColor: AppColors.navy900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: () => provider.markDriverArrived(),
                  icon: const Icon(Icons.pin_drop, size: 17),
                  label: const Text('I\'ve Arrived', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Section 3: Trip Management & OTP Verification Card ──────────────
  Widget _buildTripManagementOtpCard(
    BuildContext context,
    DriveMateProvider provider,
    Trip trip,
    Booking? booking,
  ) {
    return _DriverTripManagementOtpCard(provider: provider, trip: trip, booking: booking);
  }

  // ─── Modals: Driver Account Sheets ───────────────────────────────────

  // Sheet 1: Trip History
  static void _openTripHistorySheet(BuildContext context, DriveMateProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final trips = provider.bookings;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Driver Trip History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                  Text('${trips.length} Total Bookings', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 14),
              if (trips.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  child: const Column(
                    children: [
                      Icon(Icons.history_toggle_off, size: 48, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text(
                        'No Trip History Yet',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy900),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'You are Online – Waiting for Booking. When you complete trips, receipts will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: trips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = trips[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Booking #${item.id} • ${item.bookingType.title}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.status == BookingStatus.completed ? AppColors.successGreen.withOpacity(0.15) : AppColors.cyanAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(item.status.label, style: TextStyle(color: item.status == BookingStatus.completed ? AppColors.successGreen : AppColors.navy900, fontSize: 9.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Pickup: ${item.pickupLocation}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('Drop: ${item.destination}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Customer: ${item.userName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              Text('₹${item.totalAmount.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Sheet 2: My Earnings
  static void _openMyEarningsSheet(BuildContext context, DriveMateProvider provider) {
    final profile = provider.driverProfile;
    final todayGross = profile.earningsToday;
    final todayNet = todayGross * 0.85; // 85% payout after 15% platform commission
    final lifetimeGross = profile.totalEarnings;
    final lifetimeNet = lifetimeGross * 0.85;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: AppColors.successGreen, size: 22),
                  SizedBox(width: 8),
                  Text('My Earnings & Payouts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                ],
              ),
              const SizedBox(height: 14),

              // Gross vs Net Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F264A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Today\'s Net Payout:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('₹${todayNet.toInt()}', style: const TextStyle(color: AppColors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Today\'s Gross Fare:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Text('₹${todayGross.toInt()}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Platform Fee (15%):', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        Text('- ₹${(todayGross * 0.15).toInt()}', style: const TextStyle(color: AppColors.accentGold, fontSize: 12)),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Lifetime Net Earned:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('₹${lifetimeNet.toInt()}', style: const TextStyle(color: AppColors.successGreen, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Direct UPI Settlement Status
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.successGreen, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Direct UPI Settlement: Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                          Text('VPA: amitava.driver@okaxis • Instant Auto-Payout', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text('Settlement Policy: All fares are settled instantly to driver UPI after trip completion.', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }

  // Sheet 3: Customer Details
  static void _openCustomerDetailsSheet(
    BuildContext context,
    DriveMateProvider provider,
    Booking? booking,
    Trip? trip,
  ) {
    if (booking == null && trip == null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('No Active Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy900)),
              SizedBox(height: 6),
              Text('Customer details are displayed only when an active booking exists in the database.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
      return;
    }

    final name = booking?.userName ?? trip?.customerName ?? 'Customer Details on File';
    final phone = booking?.customerPhone ?? trip?.customerPhone;
    final car = booking?.customerCarModel ?? trip?.vehicleModel ?? 'Vehicle on File';
    final pickup = booking?.pickupLocation ?? trip?.startLocation ?? 'Pickup Location';
    final drop = booking?.destination ?? trip?.endLocation ?? 'Destination';
    final notes = booking?.notes ?? 'Direct booking from DriveMate.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Customer Profile & Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.successGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                    child: const Text('VERIFIED RIDER', style: TextStyle(color: AppColors.successGreen, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Details card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.electricBlue,
                          radius: 20,
                          child: Icon(Icons.person, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                              Text(
                                phone ?? 'Phone registered in backend',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone, color: AppColors.successGreen),
                          tooltip: 'Call Customer',
                          onPressed: () {
                            Navigator.pop(context);
                            DriverDashboardScreen.handleCallCustomer(
                              context,
                              provider,
                              bookingId: booking?.id ?? trip?.bookingId,
                              phone: phone,
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildDetailRow('Vehicle Model:', car),
                    const SizedBox(height: 6),
                    _buildDetailRow('Pickup Point:', pickup),
                    const SizedBox(height: 6),
                    _buildDetailRow('Drop Point:', drop),
                    const SizedBox(height: 6),
                    _buildDetailRow('Rider Notes:', notes),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              const Text('Safety Guidelines: Verify customer identity and inspect car controls before commencing the drive.', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy900))),
      ],
    );
  }

  // Sheet 4: Notifications & Support
  static void _openSupportSheet(BuildContext context, DriveMateProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.support_agent, color: AppColors.accentGold, size: 22),
                  SizedBox(width: 8),
                  Text('Driver Notifications & Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                ],
              ),
              const SizedBox(height: 14),

              // Emergency SOS Button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.errorRed.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning, color: AppColors.errorRed, size: 24),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Emergency SOS Assistance', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B), fontSize: 13)),
                            Text('Police Helpline & Live Location Sharing', style: TextStyle(color: Color(0xFF7F1D1D), fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
                      onPressed: () => PhoneDialerHelper.makePhoneCall(context, '112'),
                      child: const Text('SOS', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 24/7 Helpline
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2FE), child: Icon(Icons.headset_mic, color: AppColors.electricBlue)),
                title: const Text('24x7 Driver Support Helpline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('1800-DRIVEMATE • Toll-Free Help Desk', style: TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.phone, color: AppColors.electricBlue),
                  onPressed: () => PhoneDialerHelper.makePhoneCall(context, '+91 98000 11223'),
                ),
              ),

              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy900,
                    side: const BorderSide(color: AppColors.navy900),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    provider.navigateTo(ActiveCustomerScreen.helpSupport);
                  },
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Open Help & Support Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),

              const Divider(),

              // Live System Notifications
              const Text('Active System Alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy900)),
              const SizedBox(height: 8),
              _buildNotificationTile('Ride Dispatch', 'Instant dispatch alert for Kakdwip - Namkhana sector.', '10m ago'),
              _buildNotificationTile('UPI Settlement', 'Payout of ₹600 processed to bank account.', '1h ago'),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildNotificationTile(String title, String desc, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.cyanAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy900)),
                    Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section 3: StateFul Driver Trip Management OTP Verification Card ───
class _DriverTripManagementOtpCard extends StatefulWidget {
  final DriveMateProvider provider;
  final Trip trip;
  final Booking? booking;

  const _DriverTripManagementOtpCard({
    required this.provider,
    required this.trip,
    this.booking,
  });

  @override
  State<_DriverTripManagementOtpCard> createState() => _DriverTripManagementOtpCardState();
}

class _DriverTripManagementOtpCardState extends State<_DriverTripManagementOtpCard> {
  final _otpController = TextEditingController();
  bool _hasError = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      setState(() => _hasError = true);
      widget.provider.showToast('Please enter the 4-digit Ride OTP provided by passenger');
      return;
    }

    final success = await widget.provider.verifyRideOtp(otp);
    if (!success) {
      setState(() => _hasError = true);
    } else {
      setState(() => _hasError = false);
    }
  }

  void _startTrip() {
    if (!widget.provider.isOtpVerified) {
      widget.provider.showToast('Please verify passenger OTP before starting the trip.');
      return;
    }
    widget.provider.startTrip();
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.booking?.userName ?? widget.trip.customerName ?? 'Customer';
    final customerPhone = widget.booking?.customerPhone ?? widget.trip.customerPhone;
    final isOtpVerified = widget.provider.isOtpVerified;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F264A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOtpVerified ? AppColors.successGreen : AppColors.accentGold,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOtpVerified ? AppColors.successGreen : AppColors.accentGold).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isOtpVerified ? AppColors.successGreen : AppColors.accentGold).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOtpVerified ? Icons.check_circle : Icons.pin,
                  color: isOtpVerified ? AppColors.successGreen : AppColors.accentGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOtpVerified ? 'OTP VERIFIED • READY TO START' : 'RIDE START OTP VERIFICATION',
                      style: TextStyle(
                        color: isOtpVerified ? AppColors.successGreen : AppColors.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      isOtpVerified
                          ? 'Passenger $customerName is verified onboard.'
                          : 'Ask Customer ($customerName) for the 4-digit security OTP',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Call customer icon
              IconButton(
                icon: const Icon(Icons.phone, color: AppColors.cyanAccent, size: 20),
                tooltip: 'Call Customer',
                onPressed: () => DriverDashboardScreen.handleCallCustomer(
                  context,
                  widget.provider,
                  bookingId: widget.booking?.id ?? widget.trip.bookingId,
                  phone: customerPhone,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Input field & Verify / Start buttons
          if (!isOtpVerified) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '••••',
                      hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 8),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _hasError ? AppColors.errorRed : Colors.white24,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _hasError ? AppColors.errorRed : AppColors.cyanAccent,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      if (_hasError) setState(() => _hasError = false);
                      if (val.length == 4) _verifyOtp();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyanAccent,
                    foregroundColor: AppColors.navy900,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _verifyOtp,
                  icon: const Icon(Icons.verified, size: 18),
                  label: const Text('Verify OTP', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ] else ...[
            // Verified Status Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.successGreen),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.successGreen, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '4-Digit OTP Verified via Backend. Tap "Start Trip" to begin navigation and telemetry.',
                      style: TextStyle(color: AppColors.successGreen, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Functional Start Trip Button (Enabled only after OTP verification)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isOtpVerified ? AppColors.successGreen : Colors.grey.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isOtpVerified ? _startTrip : null,
              icon: const Icon(Icons.play_circle, size: 20),
              label: Text(
                isOtpVerified ? 'Start Trip & Open Meter' : 'Start Trip (Verify OTP First)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Text(
            'Security Protocol: OTP is never shown on driver app. Customer must share their private code verbally.',
            style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
