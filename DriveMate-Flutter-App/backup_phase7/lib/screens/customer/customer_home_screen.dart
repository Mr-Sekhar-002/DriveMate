import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drivemate_provider.dart';
import '../../models/drivemate_models.dart';
import '../../theme/app_theme.dart';
import '../../components/trip_search_widget.dart';
import '../../components/osm_interactive_map.dart';
import '../../components/fare_negotiation_dialog.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final activeTrip = provider.activeTrip;
    final carListings = provider.carListings;
    final drivers = provider.availableDrivers;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blueprint Hero Header Section
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.navy900,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Blueprint Feature Badges
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildBlueprintPill(Icons.phone_android, 'One App (Customer & Driver)'),
                      const SizedBox(width: 8),
                      _buildBlueprintPill(Icons.bolt, 'Seamless Ride'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'What do you need?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Car Rental (Self-Drive / With Driver) + Hire a Driver',
                  style: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 16),

                // Main UI Search Feature
                TripSearchWidget(
                  initialPickup: provider.searchQuery.pickupLocation,
                  initialDestination: provider.searchQuery.destination,
                  initialPickupCoordinates: provider.searchQuery.pickupCoordinates,
                  initialDestCoordinates: provider.searchQuery.destinationCoordinates,
                  initialDate: provider.searchQuery.travelDate,
                  initialServiceType: provider.searchQuery.serviceType,
                  onCoordinatesUpdated: (pCoord, dCoord) {
                    provider.updateSearchCoordinates(pCoord, dCoord);
                  },
                  onSearchAndBook: (pickup, dest, date, type) {
                    provider.performSearchAndNavigate(
                      pickup: pickup,
                      destination: dest,
                      travelDate: date,
                      serviceType: type,
                    );
                  },
                ),

                const SizedBox(height: 14),

                // Live OpenStreetMap Route & Fare Preview Card
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.navy800,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Stack(
                      children: [
                        OsmInteractiveMap(
                          initialCenter: provider.searchQuery.pickupCoordinates,
                          pickupLocation: provider.searchQuery.pickupCoordinates,
                          destinationLocation: provider.searchQuery.destinationCoordinates,
                          polylinePoints: provider.currentRoutePolyline,
                          showControls: false,
                          isInteractive: true,
                        ),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.navy900.withOpacity(0.92),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.route, color: AppColors.cyanAccent, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  '${provider.routeDistanceKm} km • ~${provider.routeDurationMins}m • ₹${provider.calculatedFare.toInt()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Explore Direct Services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // 3 Primary Direct Service Cards (from Blueprint)
                _buildServiceCard(
                  context: context,
                  title: 'Hire a Driver',
                  subtitle: 'Customer owns the car • On-demand Chauffeurs',
                  badge: 'POPULAR',
                  icon: Icons.airline_seat_recline_extra,
                  accentColor: AppColors.cyanAccent,
                  onTap: () {
                    provider.fetchEligibleDrivers();
                    provider.navigateTo(ActiveCustomerScreen.driverSelection);
                  },
                ),
                const SizedBox(height: 10),
                _buildServiceCard(
                  context: context,
                  title: 'Rent a Car',
                  subtitle: 'Self-Drive • Hourly & Daily Verified Fleet',
                  badge: 'FLEXIBLE',
                  icon: Icons.directions_car,
                  accentColor: const Color(0xFF38BDF8),
                  onTap: () => provider.navigateTo(ActiveCustomerScreen.rentCarFlow),
                ),
                const SizedBox(height: 10),
                _buildServiceCard(
                  context: context,
                  title: 'Rent Car + Driver',
                  subtitle: 'Chauffeur Driven • Premium comfort & outstation',
                  badge: 'ALL-IN-ONE',
                  icon: Icons.workspace_premium,
                  accentColor: AppColors.accentGold,
                  onTap: () => provider.navigateTo(ActiveCustomerScreen.rentCarAndDriverFlow),
                ),
              ],
            ),
          ),

          // Active Fare Negotiation Alert Banner (Customer Flow)
          if (provider.activeNegotiationBooking != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActiveNegotiationCard(context, provider, provider.activeNegotiationBooking!),
            ),
          ],

          // Active Trip Ongoing Alert Banner
          if (activeTrip != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () => provider.navigateTo(ActiveCustomerScreen.activeTripTracking),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F264A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.electricBlue.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.navigation, color: AppColors.successGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Ride in Progress',
                              style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Driver ${activeTrip.driverName} • ${(activeTrip.currentProgress * 100).toInt()}% Along Route',
                              style: const TextStyle(color: AppColors.cyanAccent, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.cyanAccent),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Featured Fleet Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Featured Fleet for Rental',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => provider.navigateTo(ActiveCustomerScreen.rentCarFlow),
                  child: const Text('View All', style: TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Horizontal List of Car Listings
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: carListings.length,
              itemBuilder: (context, index) {
                final listing = carListings[index];
                return Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.cyanLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                listing.vehicle.type,
                                style: const TextStyle(color: AppColors.navy900, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              '₹${listing.dailyRate.toInt()}/day',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.electricBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listing.vehicle.model,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${listing.vehicle.transmission} • ${listing.vehicle.fuelType} • ${listing.vehicle.capacity} Seats',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listing.description,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy900,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              provider.navigateTo(ActiveCustomerScreen.rentCarFlow);
                            },
                            child: const Text('Book Car', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Verified Professional Drivers Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Verified Professional Chauffeurs',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: drivers.map((driver) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
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
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.navy900,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: AppColors.cyanAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  driver.driverName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, color: AppColors.electricBlue, size: 14),
                              ],
                            ),
                            Text(
                              '${driver.experienceYears} Years Exp • ${driver.vehicleTypePreference}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, color: AppColors.accentGold, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                '${driver.rating}',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimaryDark),
                              ),
                            ],
                          ),
                          Text('${driver.totalTrips} trips', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 18),

          // Help & Support Access Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () => provider.navigateTo(ActiveCustomerScreen.helpSupport),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D233A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cyanAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cyanAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent, color: AppColors.cyanAccent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need Help or Facing an Issue?',
                            style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'FAQs, 24x7 Helpline, and Ticket Resolution',
                            style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: AppColors.cyanAccent, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildBlueprintPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.cyanAccent, size: 13),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveNegotiationCard(BuildContext context, DriveMateProvider provider, Booking booking) {
    final negotiations = provider.getNegotiationsForBooking(booking.id);
    final latestOffer = negotiations.isNotEmpty ? negotiations.last : null;
    final isAgreed = booking.negotiationStatus == 'AGREED';
    final isDriverCounter = latestOffer != null && latestOffer.senderRole == 'driver' && latestOffer.status == NegotiationStatus.pending;
    final offeredPrice = (booking.negotiatedFare ?? booking.totalAmount).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAgreed
            ? const Color(0xFF0D3326)
            : isDriverCounter
                ? const Color(0xFF0F264A)
                : const Color(0xFF2E2405),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAgreed
              ? AppColors.successGreen
              : isDriverCounter
                  ? AppColors.cyanAccent
                  : AppColors.accentGold,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAgreed
                    ? AppColors.successGreen
                    : isDriverCounter
                        ? AppColors.cyanAccent
                        : AppColors.accentGold)
                .withOpacity(0.15),
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
                  Icon(
                    isAgreed
                        ? Icons.check_circle
                        : (isDriverCounter ? Icons.swap_horiz : Icons.hourglass_top),
                    color: isAgreed
                        ? AppColors.successGreen
                        : (isDriverCounter ? AppColors.cyanAccent : AppColors.accentGold),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAgreed
                          ? AppColors.successGreen
                          : isDriverCounter
                              ? AppColors.cyanAccent
                              : AppColors.accentGold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isAgreed
                          ? 'FARE AGREED & CONFIRMED'
                          : isDriverCounter
                              ? 'DRIVER COUNTER-OFFER RECEIVED'
                              : 'OFFER PENDING DRIVER RESPONSE',
                      style: TextStyle(
                        color: isDriverCounter ? AppColors.navy900 : Colors.black,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '₹$offeredPrice',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isAgreed
                ? 'Mutually agreed fare ₹$offeredPrice with Chauffeur Amitava Roy. Ride Start OTP: ${booking.startOtp}'
                : isDriverCounter
                    ? 'Chauffeur Amitava proposed counter-offer ₹$offeredPrice. You can accept or counter again.'
                    : 'Your offer ₹$offeredPrice has been submitted to Chauffeur Amitava Roy. Awaiting reply.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isDriverCounter) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => provider.respondToFareOffer(booking.id, 'accept'),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text('Accept ₹$offeredPrice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => FareNegotiationDialog.show(context, booking),
                  icon: const Icon(Icons.history, size: 16),
                  label: Text(isAgreed ? 'View Agreed Details' : 'Negotiate / History', style: const TextStyle(fontSize: 12)),
                ),
              ),
              if (!isAgreed) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Cancel Negotiation',
                  icon: const Icon(Icons.close, color: AppColors.errorRed, size: 20),
                  onPressed: () => provider.cancelActiveNegotiation(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
