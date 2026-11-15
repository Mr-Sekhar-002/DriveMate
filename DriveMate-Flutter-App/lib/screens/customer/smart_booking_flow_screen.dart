import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/drivemate_models.dart';
import '../../providers/drivemate_provider.dart';
import '../../theme/app_theme.dart';
import '../../components/location_search_dialog.dart';
import '../../components/smart_fare_breakdown_sheet.dart';

class SmartBookingFlowScreen extends StatefulWidget {
  final BookingType initialService;

  const SmartBookingFlowScreen({
    super.key,
    this.initialService = BookingType.hireDriver,
  });

  @override
  State<SmartBookingFlowScreen> createState() => _SmartBookingFlowScreenState();
}

class _SmartBookingFlowScreenState extends State<SmartBookingFlowScreen> {
  late BookingType _selectedService;
  BookingDurationType _selectedDuration = BookingDurationType.hourly;
  int _hourlyCount = 4;
  bool _isScheduled = false;
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _scheduledTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 2)));

  // Selected vehicle or car model
  String _customerCarModel = 'Hyundai Creta';
  int _selectedCarListingIndex = 0;
  final bool _includeTolls = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<DriveMateProvider>();
    _selectedService = provider.selectedSmartBookingService;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.refreshRouteAndFare();
      provider.fetchEligibleDrivers();
      _checkAvailability();
    });
  }

  void _checkAvailability() {
    final provider = context.read<DriveMateProvider>();
    final start = _isScheduled
        ? DateTime(
            _scheduledDate.year,
            _scheduledDate.month,
            _scheduledDate.day,
            _scheduledTime.hour,
            _scheduledTime.minute,
          )
        : DateTime.now();

    final end = start.add(Duration(hours: _hourlyCount));

    int? vId;
    if (_selectedService == BookingType.rentCar || _selectedService == BookingType.rentCarAndDriver) {
      if (provider.carListings.isNotEmpty) {
        final listing = provider.carListings[_selectedCarListingIndex % provider.carListings.length];
        vId = int.tryParse(listing.vehicleId.replaceAll(RegExp(r'[^0-9]'), ''));
      }
    }

    int? dId;
    if (_selectedService == BookingType.hireDriver || _selectedService == BookingType.rentCarAndDriver) {
      if (provider.eligibleDrivers.isNotEmpty) {
        dId = provider.eligibleDrivers.first.id;
      }
    }

    provider.checkResourceAvailability(
      vehicleId: vId,
      driverId: dId,
      start: start,
      end: end,
    );
  }

  double _calculateAuthoritativeFare(DriveMateProvider provider) {
    final distKm = provider.routeDistanceKm > 0 ? provider.routeDistanceKm : 18.0;

    switch (_selectedService) {
      case BookingType.hireDriver:
        switch (_selectedDuration) {
          case BookingDurationType.hourly:
            return 150.0 + (_hourlyCount * 120.0);
          case BookingDurationType.halfDay:
            return 550.0;
          case BookingDurationType.fullDay:
            return 1200.0;
          case BookingDurationType.daily:
            return 1600.0;
          case BookingDurationType.outstation:
            return (distKm * 14.0) + 400.0 + (_includeTolls ? 250.0 : 0.0);
        }
      case BookingType.rentCar:
        final baseDaily = provider.carListings.isNotEmpty
            ? provider.carListings[_selectedCarListingIndex % provider.carListings.length].dailyRate
            : 2200.0;
        switch (_selectedDuration) {
          case BookingDurationType.hourly:
            return (baseDaily / 10.0) * _hourlyCount;
          case BookingDurationType.halfDay:
            return baseDaily * 0.6;
          case BookingDurationType.fullDay:
          case BookingDurationType.daily:
            return baseDaily;
          case BookingDurationType.outstation:
            return (baseDaily * 1.5) + (distKm * 6.0);
        }
      case BookingType.rentCarAndDriver:
        final carRate = provider.carListings.isNotEmpty
            ? provider.carListings[_selectedCarListingIndex % provider.carListings.length].dailyRate
            : 2200.0;
        switch (_selectedDuration) {
          case BookingDurationType.hourly:
            return ((carRate / 8.0) + 150.0) * _hourlyCount;
          case BookingDurationType.halfDay:
            return (carRate * 0.6) + 600.0;
          case BookingDurationType.fullDay:
          case BookingDurationType.daily:
            return carRate + 1200.0;
          case BookingDurationType.outstation:
            return (carRate * 1.5) + (distKm * 15.0) + 500.0;
        }
      case BookingType.outstation:
        return (distKm * 16.0) + 800.0 + (_includeTolls ? 350.0 : 0.0);
    }
  }

  Future<void> _pickScheduleDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(data: AppTheme.darkTheme, child: child!),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _scheduledTime,
        builder: (context, child) => Theme(data: AppTheme.darkTheme, child: child!),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _scheduledDate = pickedDate;
          _scheduledTime = pickedTime;
          _isScheduled = true;
        });
        _checkAvailability();
      }
    }
  }

  void _confirmBooking() {
    final provider = context.read<DriveMateProvider>();
    final fare = _calculateAuthoritativeFare(provider);

    final startDt = _isScheduled
        ? DateTime(
            _scheduledDate.year,
            _scheduledDate.month,
            _scheduledDate.day,
            _scheduledTime.hour,
            _scheduledTime.minute,
          )
        : DateTime.now();

    final endDt = startDt.add(Duration(hours: _hourlyCount));
    final startDateStr = DateFormat('yyyy-MM-dd HH:mm').format(startDt);
    final endDateStr = DateFormat('yyyy-MM-dd HH:mm').format(endDt);

    CarListing? assignedListing;
    if (_selectedService != BookingType.hireDriver && provider.carListings.isNotEmpty) {
      assignedListing = provider.carListings[_selectedCarListingIndex % provider.carListings.length];
    }

    final booking = provider.createBooking(
      bookingType: _selectedService,
      startDate: startDateStr,
      endDate: endDateStr,
      pickupLocation: provider.searchQuery.pickupLocation,
      pickupLat: provider.searchQuery.pickupCoordinates.latitude,
      pickupLng: provider.searchQuery.pickupCoordinates.longitude,
      destination: provider.searchQuery.destination,
      destLat: provider.searchQuery.destinationCoordinates.latitude,
      destLng: provider.searchQuery.destinationCoordinates.longitude,
      totalAmount: fare,
      customerCarModel: _selectedService == BookingType.hireDriver ? _customerCarModel : null,
      carListing: assignedListing,
      paymentMethod: PaymentMethod.razorpay,
    );

    _showBookingSuccessModal(booking);
  }

  void _showBookingSuccessModal(Booking booking) {
    final isDark = AppColors.isDark(context);
    final cardBg = AppColors.cardBgOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final inputFill = AppColors.inputFillOf(context);
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;
    final bookingRef = booking.bookingReference ?? 'DM-BK-${DateTime.now().year}${booking.id.replaceAll('BK-', '')}';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.successGreen, width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.successGreen, size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Booking ID: $bookingRef',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cyanAccent,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ride Start OTP',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          booking.startOtp.isNotEmpty ? booking.startOtp : '4912',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.0,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${booking.totalAmount.toInt()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        final p = context.read<DriveMateProvider>();
                        p.navigateTo(ActiveCustomerScreen.myBookings);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        final p = context.read<DriveMateProvider>();
                        p.navigateTo(ActiveCustomerScreen.activeTripTracking);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Track Live', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 6),
                          Icon(Icons.navigation_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriveMateProvider>();
    final fare = _calculateAuthoritativeFare(provider);
    final isDark = AppColors.isDark(context);
    final pageBg = AppColors.pageBgOf(context);
    final cardBg = AppColors.cardBgOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final inputFill = AppColors.inputFillOf(context);
    final borderSubtle = isDark ? AppColors.darkBorder : AppColors.borderSubtle;

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
          'Smart Booking System',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: AppColors.cyanAccent, size: 14),
                SizedBox(width: 4),
                Text(
                  'Instant Lock',
                  style: TextStyle(color: AppColors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Service Switcher (4 Core Services) ────────────────────────
            Text(
              'Select Service',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textPrimary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildServiceTab(
                  type: BookingType.hireDriver,
                  label: 'Hire Driver',
                  icon: Icons.airline_seat_recline_extra_rounded,
                  cardBg: cardBg,
                  borderSubtle: borderSubtle,
                ),
                const SizedBox(width: 8),
                _buildServiceTab(
                  type: BookingType.rentCar,
                  label: 'Self-Drive',
                  icon: Icons.directions_car_filled_rounded,
                  cardBg: cardBg,
                  borderSubtle: borderSubtle,
                ),
                const SizedBox(width: 8),
                _buildServiceTab(
                  type: BookingType.rentCarAndDriver,
                  label: 'Car + Driver',
                  icon: Icons.car_rental_rounded,
                  cardBg: cardBg,
                  borderSubtle: borderSubtle,
                ),
                const SizedBox(width: 8),
                _buildServiceTab(
                  type: BookingType.outstation,
                  label: 'Outstation',
                  icon: Icons.explore_rounded,
                  cardBg: cardBg,
                  borderSubtle: borderSubtle,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ─── 2. Duration / Package Selector ────────────────────────────────
            Text(
              'Booking Duration / Package',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textPrimary),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDurationChip(BookingDurationType.hourly, 'Hourly', cardBg, borderSubtle),
                  _buildDurationChip(BookingDurationType.halfDay, 'Half-Day (4h)', cardBg, borderSubtle),
                  _buildDurationChip(BookingDurationType.fullDay, 'Full-Day (8h)', cardBg, borderSubtle),
                  _buildDurationChip(BookingDurationType.daily, 'Daily Rental', cardBg, borderSubtle),
                  _buildDurationChip(BookingDurationType.outstation, 'Outstation Trip', cardBg, borderSubtle),
                ],
              ),
            ),

            // Hourly Slider (if hourly selected)
            if (_selectedDuration == BookingDurationType.hourly) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: AppColors.cyanAccent, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      '$_hourlyCount Hours Required',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                    ),
                    Expanded(
                      child: Slider(
                        value: _hourlyCount.toDouble(),
                        min: 1,
                        max: 12,
                        divisions: 11,
                        activeColor: AppColors.primaryBlue,
                        inactiveColor: isDark ? Colors.white24 : AppColors.lightLine,
                        label: '$_hourlyCount hrs',
                        onChanged: (val) {
                          setState(() => _hourlyCount = val.toInt());
                          _checkAvailability();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // ─── 3. Pickup & Destination Card ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderSubtle),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      LocationSearchDialog.show(
                        context: context,
                        title: 'Select Pickup Location',
                        initialQuery: provider.searchQuery.pickupLocation,
                        onLocationSelected: (address, coords) {
                          provider.updateSearchQuery(
                            pickup: address,
                            pickupCoordinates: coords,
                          );
                          _checkAvailability();
                        },
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.trip_origin_rounded, color: AppColors.successGreen, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PICKUP LOCATION', style: TextStyle(color: textSecondary, fontSize: 10.5, fontWeight: FontWeight.bold)),
                              Text(
                                provider.searchQuery.pickupLocation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_location_alt_outlined, color: AppColors.cyanAccent, size: 18),
                      ],
                    ),
                  ),
                  Divider(color: borderSubtle, height: 20),
                  InkWell(
                    onTap: () {
                      LocationSearchDialog.show(
                        context: context,
                        title: 'Select Destination',
                        initialQuery: provider.searchQuery.destination,
                        onLocationSelected: (address, coords) {
                          provider.updateSearchQuery(
                            destination: address,
                            destinationCoordinates: coords,
                          );
                          _checkAvailability();
                        },
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_rounded, color: AppColors.errorRed, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DESTINATION', style: TextStyle(color: textSecondary, fontSize: 10.5, fontWeight: FontWeight.bold)),
                              Text(
                                provider.searchQuery.destination,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_location_alt_outlined, color: AppColors.cyanAccent, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ─── 4. Schedule (Immediate vs Future) ───────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Booking Schedule',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() => _isScheduled = false);
                                _checkAvailability();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: !_isScheduled ? AppColors.primaryBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Ride Now',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: !_isScheduled ? Colors.white : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _pickScheduleDateTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isScheduled ? AppColors.primaryBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Schedule',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isScheduled ? Colors.white : textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isScheduled) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickScheduleDateTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.cyanAccent.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, color: AppColors.cyanAccent, size: 15),
                                const SizedBox(width: 8),
                                Text(
                                  '${DateFormat('EEE, d MMM yyyy').format(_scheduledDate)} at ${_scheduledTime.format(context)}',
                                  style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Text('Change', style: TextStyle(color: AppColors.cyanAccent, fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ─── 5. Resource Selection (Driver vs Vehicle) ───────────────────
            if (_selectedService == BookingType.hireDriver) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Car Model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: _customerCarModel),
                      onChanged: (val) => _customerCarModel = val,
                      style: TextStyle(color: textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputFill,
                        hintText: 'e.g. Hyundai Creta, Honda City',
                        hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 12.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.directions_car_outlined, color: AppColors.cyanAccent, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              _buildSelectedDriverCard(provider, cardBg, inputFill, textPrimary, textSecondary, borderSubtle),
            ] else ...[
              // Vehicle Carousel for Car Rental
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Fleet Vehicle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 115,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.carListings.length,
                      itemBuilder: (context, idx) {
                        final listing = provider.carListings[idx];
                        final isSelected = _selectedCarListingIndex == idx;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedCarListingIndex = idx);
                            _checkAvailability();
                          },
                          child: Container(
                            width: 155,
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.cyanAccent : borderSubtle,
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listing.vehicle.model,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                Text(
                                  listing.vehicle.type,
                                  style: TextStyle(color: textSecondary, fontSize: 10.5),
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('₹${listing.dailyRate.toInt()}/day', style: const TextStyle(color: AppColors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11.5)),
                                    if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.cyanAccent, size: 16),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_selectedService == BookingType.rentCarAndDriver)
                _buildSelectedDriverCard(provider, cardBg, inputFill, textPrimary, textSecondary, borderSubtle),
            ],

            const SizedBox(height: 14),

            // ─── 6. Live Availability Checking Status Pill ─────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: provider.isResourceAvailable
                    ? AppColors.successGreen.withOpacity(0.12)
                    : AppColors.errorRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: provider.isResourceAvailable ? AppColors.successGreen.withOpacity(0.5) : AppColors.errorRed.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  provider.isCheckingAvailability
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyanAccent))
                      : Icon(
                          provider.isResourceAvailable ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded,
                          color: provider.isResourceAvailable ? AppColors.successGreen : AppColors.errorRed,
                          size: 18,
                        ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.availabilityStatusMessage ?? 'Available for instant booking confirmation',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: provider.isResourceAvailable ? AppColors.successGreen : AppColors.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ─── 7. Transparent Authoritative Fare Card ────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Authoritative Fare Breakdown',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'PHP Authoritative',
                        style: TextStyle(fontSize: 10.5, color: AppColors.cyanAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Divider(color: borderSubtle, height: 20),
                  _buildFareRow('Base Package Fare', '₹${(fare * 0.75).toInt()}', textPrimary, textSecondary),
                  _buildFareRow('Distance (${provider.routeDistanceKm.toStringAsFixed(1)} km) & Time', '₹${(fare * 0.15).toInt()}', textPrimary, textSecondary),
                  if (_selectedService == BookingType.outstation)
                    _buildFareRow('Inter-State Permit & Surcharge', '₹${_includeTolls ? 350 : 150}', textPrimary, textSecondary),
                  _buildFareRow('GST & Platform Commission (5%)', '₹${(fare * 0.10).toInt()}', textPrimary, textSecondary),
                  Divider(color: borderSubtle, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Total Estimated Fare',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: textPrimary),
                        ),
                      ),
                      Text(
                        '₹${fare.toInt()}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final authFare = await provider.calculateAuthoritativeFare(
                          serviceType: _selectedService == BookingType.hireDriver
                              ? 'hire_driver'
                              : (_selectedService == BookingType.rentCar
                                  ? 'rent_car'
                                  : (_selectedService == BookingType.rentCarAndDriver ? 'rent_car_driver' : 'outstation')),
                          hiringType: _selectedDuration == BookingDurationType.hourly
                              ? 'hourly'
                              : (_selectedDuration == BookingDurationType.halfDay
                                  ? 'half_day'
                                  : (_selectedDuration == BookingDurationType.fullDay
                                      ? 'full_day'
                                      : (_selectedDuration == BookingDurationType.daily ? 'daily' : 'one_way'))),
                          distanceKm: provider.routeDistanceKm > 0 ? provider.routeDistanceKm : 10.0,
                          durationMinutes: provider.routeDurationMins > 0 ? provider.routeDurationMins : 25,
                          hours: _selectedDuration == BookingDurationType.hourly ? _hourlyCount.toDouble() : 0.0,
                          days: _selectedDuration == BookingDurationType.daily ? 1 : 0,
                          tollCharges: _includeTolls ? 150.0 : 0.0,
                        );
                        if (context.mounted && authFare != null) {
                          SmartFareBreakdownSheet.show(
                            context,
                            fare: authFare,
                            onConfirmBooking: _confirmBooking,
                          );
                        }
                      },
                      icon: const Icon(Icons.receipt_long, color: AppColors.cyanAccent, size: 16),
                      label: const Text(
                        'View Transparent Breakdown & Coupons',
                        style: TextStyle(color: AppColors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.cyanAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 8. Confirm Booking Button ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: provider.isResourceAvailable ? _confirmBooking : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Confirm Booking & Generate ID',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceTab({
    required BookingType type,
    required String label,
    required IconData icon,
    required Color cardBg,
    required Color borderSubtle,
  }) {
    final isSelected = _selectedService == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedService = type);
          _checkAvailability();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryBlue.withOpacity(0.18) : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.cyanAccent : borderSubtle,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.cyanAccent : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected ? AppColors.cyanAccent : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(BookingDurationType duration, String label, Color cardBg, Color borderSubtle) {
    final isSelected = _selectedDuration == duration;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) {
            setState(() => _selectedDuration = duration);
            _checkAvailability();
          }
        },
        selectedColor: AppColors.primaryBlue,
        backgroundColor: cardBg,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? AppColors.primaryBlue : borderSubtle,
          ),
        ),
      ),
    );
  }

  Widget _buildFareRow(String title, String amount, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: textSecondary))),
          const SizedBox(width: 8),
          Text(amount, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSelectedDriverCard(
    DriveMateProvider provider,
    Color cardBg,
    Color inputFill,
    Color textPrimary,
    Color textSecondary,
    Color borderSubtle,
  ) {
    final driver = provider.selectedDriver;
    final availableCount = provider.eligibleDrivers.where((d) => d.isAvailable).length;
    final countLabel = availableCount > 0 ? '$availableCount available' : '4 available';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Driver',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  countLabel,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cyanAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              provider.fetchEligibleDrivers();
              provider.navigateTo(ActiveCustomerScreen.driverSelection);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: AppColors.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver != null ? driver.name : 'Tap to Select Verified Chauffeur',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          driver != null
                              ? '${driver.vehicleModel} • Rating ${driver.avgRating?.toStringAsFixed(1) ?? "5.0"}★'
                              : 'Browse and assign verified professional chauffeur',
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      provider.fetchEligibleDrivers();
                      provider.navigateTo(ActiveCustomerScreen.driverSelection);
                    },
                    child: Text(
                      driver != null ? 'Change' : 'Choose',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
