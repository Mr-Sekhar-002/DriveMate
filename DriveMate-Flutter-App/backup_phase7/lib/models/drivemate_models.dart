enum UserRole {
  customer('Customer'),
  driver('Driver'),
  owner('Car Owner'),
  admin('Admin');

  final String label;
  const UserRole(this.label);
}

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String status;
  final String avatarUrl;
  final String createdAt;
  final String preferredLanguage;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.status = 'active',
    this.avatarUrl = '',
    this.createdAt = '2026-10-01',
    this.preferredLanguage = 'en',
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? status,
    String? avatarUrl,
    String? createdAt,
    String? preferredLanguage,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}

class DriverProfile {
  final String id;
  final String userId;
  final String driverName;
  final String phone;
  final String licenseNumber;
  final int experienceYears;
  final String vehicleTypePreference;
  final double rating;
  final int totalTrips;
  final double earningsToday;
  final double totalEarnings;
  final bool isOnline;
  final String status;
  final String verifiedAt;

  DriverProfile({
    required this.id,
    required this.userId,
    required this.driverName,
    required this.phone,
    required this.licenseNumber,
    required this.experienceYears,
    this.vehicleTypePreference = 'All Vehicles (Sedan, SUV, Luxury)',
    this.rating = 0.0,
    this.totalTrips = 0,
    this.earningsToday = 0.0,
    this.totalEarnings = 0.0,
    this.isOnline = true,
    this.status = 'verified',
    this.verifiedAt = '2026-10-15',
  });

  DriverProfile copyWith({
    String? id,
    String? userId,
    String? driverName,
    String? phone,
    String? licenseNumber,
    int? experienceYears,
    String? vehicleTypePreference,
    double? rating,
    int? totalTrips,
    double? earningsToday,
    double? totalEarnings,
    bool? isOnline,
    String? status,
    String? verifiedAt,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      driverName: driverName ?? this.driverName,
      phone: phone ?? this.phone,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      experienceYears: experienceYears ?? this.experienceYears,
      vehicleTypePreference: vehicleTypePreference ?? this.vehicleTypePreference,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      earningsToday: earningsToday ?? this.earningsToday,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      isOnline: isOnline ?? this.isOnline,
      status: status ?? this.status,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }
}

class Vehicle {
  final String id;
  final String ownerId;
  final String ownerName;
  final String type; // Sedan, SUV, Luxury, Hatchback
  final String model;
  final String numberPlate;
  final String color;
  final int capacity;
  final String transmission; // Automatic, Manual
  final String fuelType;
  final String status;

  Vehicle({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.type,
    required this.model,
    required this.numberPlate,
    required this.color,
    required this.capacity,
    this.transmission = 'Automatic',
    this.fuelType = 'Petrol',
    this.status = 'active',
  });
}

enum RentalType {
  selfDrive('Self-Drive'),
  withDriver('With Driver'),
  both('Both (Self or With Driver)');

  final String label;
  const RentalType(this.label);
}

class CarListing {
  final String id;
  final String ownerId;
  final String vehicleId;
  final Vehicle vehicle;
  final RentalType rentalType;
  final double dailyRate;
  final double hourlyRate;
  final String description;
  final String availableFrom;
  final String availableTo;
  final bool isAvailable;
  final double securityDeposit;
  final String location;
  final String status;

  CarListing({
    required this.id,
    required this.ownerId,
    required this.vehicleId,
    required this.vehicle,
    required this.rentalType,
    required this.dailyRate,
    required this.hourlyRate,
    required this.description,
    required this.availableFrom,
    required this.availableTo,
    this.isAvailable = true,
    this.securityDeposit = 3000.0,
    this.location = 'Downtown Central Hub',
    this.status = 'available',
  });

  CarListing copyWith({
    String? id,
    String? ownerId,
    String? vehicleId,
    Vehicle? vehicle,
    RentalType? rentalType,
    double? dailyRate,
    double? hourlyRate,
    String? description,
    String? availableFrom,
    String? availableTo,
    bool? isAvailable,
    double? securityDeposit,
    String? location,
    String? status,
  }) {
    return CarListing(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicle: vehicle ?? this.vehicle,
      rentalType: rentalType ?? this.rentalType,
      dailyRate: dailyRate ?? this.dailyRate,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      description: description ?? this.description,
      availableFrom: availableFrom ?? this.availableFrom,
      availableTo: availableTo ?? this.availableTo,
      isAvailable: isAvailable ?? this.isAvailable,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      location: location ?? this.location,
      status: status ?? this.status,
    );
  }
}

enum DriverHiringType {
  oneWay('one_way', 'One-way Trip', 'Direct point-to-point chauffeur service'),
  roundTrip('round_trip', 'Round-trip', 'Return chauffeur journey with wait time'),
  hourly('hourly', 'Hourly Chauffeur', 'Flexible city travel billed per hour'),
  fullDay('full_day', 'Full-day Hiring', 'Full day (8-12 hrs) personal driver');

  final String code;
  final String label;
  final String description;
  const DriverHiringType(this.code, this.label, this.description);

  static DriverHiringType fromCode(String? code) {
    if (code == null) return DriverHiringType.oneWay;
    return DriverHiringType.values.firstWhere(
      (e) => e.code == code.toLowerCase().trim(),
      orElse: () => DriverHiringType.oneWay,
    );
  }
}

class DriverHiringFareEstimate {
  final String hiringType;
  final double distanceKm;
  final int durationMinutes;
  final double baseCharge;
  final double distanceFare;
  final double timeFare;
  final double allowances;
  final double estimatedFare;
  final double minSuggestedOffer;
  final double maxSuggestedOffer;
  final String currency;
  final String currencySymbol;

  DriverHiringFareEstimate({
    required this.hiringType,
    required this.distanceKm,
    required this.durationMinutes,
    required this.baseCharge,
    required this.distanceFare,
    required this.timeFare,
    required this.allowances,
    required this.estimatedFare,
    required this.minSuggestedOffer,
    required this.maxSuggestedOffer,
    this.currency = 'INR',
    this.currencySymbol = '₹',
  });

  factory DriverHiringFareEstimate.fromJson(Map<String, dynamic> json) {
    return DriverHiringFareEstimate(
      hiringType: json['hiring_type']?.toString() ?? 'one_way',
      distanceKm: (json['distance_km'] is num) ? (json['distance_km'] as num).toDouble() : double.tryParse(json['distance_km'].toString()) ?? 0.0,
      durationMinutes: (json['duration_minutes'] is num) ? (json['duration_minutes'] as num).toInt() : int.tryParse(json['duration_minutes'].toString()) ?? 0,
      baseCharge: (json['base_charge'] is num) ? (json['base_charge'] as num).toDouble() : double.tryParse(json['base_charge'].toString()) ?? 0.0,
      distanceFare: (json['distance_fare'] is num) ? (json['distance_fare'] as num).toDouble() : double.tryParse(json['distance_fare'].toString()) ?? 0.0,
      timeFare: (json['time_fare'] is num) ? (json['time_fare'] as num).toDouble() : double.tryParse(json['time_fare'].toString()) ?? 0.0,
      allowances: (json['allowances'] is num) ? (json['allowances'] as num).toDouble() : double.tryParse(json['allowances'].toString()) ?? 0.0,
      estimatedFare: (json['estimated_fare'] is num) ? (json['estimated_fare'] as num).toDouble() : double.tryParse(json['estimated_fare'].toString()) ?? 0.0,
      minSuggestedOffer: (json['min_suggested_offer'] is num) ? (json['min_suggested_offer'] as num).toDouble() : double.tryParse(json['min_suggested_offer'].toString()) ?? 0.0,
      maxSuggestedOffer: (json['max_suggested_offer'] is num) ? (json['max_suggested_offer'] as num).toDouble() : double.tryParse(json['max_suggested_offer'].toString()) ?? 0.0,
      currency: json['currency']?.toString() ?? 'INR',
      currencySymbol: json['currency_symbol']?.toString() ?? '₹',
    );
  }
}

enum BookingType {
  hireDriver('Hire a Driver', 'Customer owns the car'),
  rentCar('Rent a Car', 'Self-Drive'),
  rentCarAndDriver('Rent Car + Driver', 'Chauffeur Driven Rental');

  final String title;
  final String subtitle;
  const BookingType(this.title, this.subtitle);
}

enum BookingStatus {
  pending('Pending Confirmation'),
  confirmed('Confirmed'),
  inProgress('In Progress'),
  completed('Completed'),
  cancelled('Cancelled');

  final String label;
  const BookingStatus(this.label);
}

class Booking {
  final String id;
  final String userId;
  final String userName;
  final String? driverId;
  final String? driverName;
  final String? vehicleId;
  final String? vehicleModel;
  final String? carListingId;
  final BookingType bookingType;
  final DriverHiringType? hiringType;
  final String startDate;
  final String endDate;
  final String pickupLocation;
  final double? pickupLat;
  final double? pickupLng;
  final String destination;
  final double? destLat;
  final double? destLng;
  final double? distanceKm;
  final int? durationMinutes;
  final double? estimatedFare;
  final double? customerOffer;
  final double? driverCounterOffer;
  final double totalAmount;
  final BookingStatus status;
  final String? customerCarModel;
  final String hoursOrDaysText;
  final String createdAt;
  final double? negotiatedFare;
  final String negotiationStatus;
  final String startOtp;
  final String? customerPhone;
  final String? notes;

  Booking({
    required this.id,
    required this.userId,
    required this.userName,
    this.driverId,
    this.driverName,
    this.vehicleId,
    this.vehicleModel,
    this.carListingId,
    required this.bookingType,
    this.hiringType,
    required this.startDate,
    required this.endDate,
    required this.pickupLocation,
    this.pickupLat,
    this.pickupLng,
    required this.destination,
    this.destLat,
    this.destLng,
    this.distanceKm,
    this.durationMinutes,
    this.estimatedFare,
    this.customerOffer,
    this.driverCounterOffer,
    required this.totalAmount,
    required this.status,
    this.customerCarModel,
    this.hoursOrDaysText = '4 Hours',
    this.createdAt = '2026-10-27',
    this.negotiatedFare,
    this.negotiationStatus = 'NONE',
    this.startOtp = '',
    this.customerPhone,
    this.notes,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? 'hire_driver').toString();
    final bookingType = rawType.contains('rent_car_driver')
        ? BookingType.rentCarAndDriver
        : (rawType.contains('rent_car') ? BookingType.rentCar : BookingType.hireDriver);

    final rawHiringType = json['hiring_type']?.toString();
    DriverHiringType? hiringType;
    if (rawHiringType != null) {
      if (rawHiringType == 'round_trip') {
        hiringType = DriverHiringType.roundTrip;
      } else if (rawHiringType == 'hourly') {
        hiringType = DriverHiringType.hourly;
      } else if (rawHiringType == 'full_day') {
        hiringType = DriverHiringType.fullDay;
      } else {
        hiringType = DriverHiringType.oneWay;
      }
    }

    final rawStatus = (json['status'] ?? 'pending').toString().toLowerCase();
    BookingStatus status;
    switch (rawStatus) {
      case 'confirmed':
        status = BookingStatus.confirmed;
        break;
      case 'arrived':
      case 'ongoing':
        status = BookingStatus.inProgress;
        break;
      case 'completed':
        status = BookingStatus.completed;
        break;
      case 'cancelled':
        status = BookingStatus.cancelled;
        break;
      default:
        status = BookingStatus.pending;
    }

    final idStr = json['id'] != null
        ? (json['id'].toString().startsWith('BK-') ? json['id'].toString() : 'BK-${json['id']}')
        : 'BK-1';

    return Booking(
      id: idStr,
      userId: json['user_id']?.toString() ?? '1',
      userName: json['customer_name']?.toString() ?? json['user_name']?.toString() ?? 'Customer',
      driverId: json['driver_id']?.toString(),
      driverName: json['driver_name']?.toString(),
      vehicleId: json['vehicle_id']?.toString(),
      vehicleModel: json['vehicle_model']?.toString() ?? json['customer_car_model']?.toString(),
      carListingId: json['car_listing_id']?.toString(),
      bookingType: bookingType,
      hiringType: hiringType,
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      pickupLocation: json['pickup_location']?.toString() ?? '',
      pickupLat: json['pickup_lat'] != null ? double.tryParse(json['pickup_lat'].toString()) : null,
      pickupLng: json['pickup_lng'] != null ? double.tryParse(json['pickup_lng'].toString()) : null,
      destination: json['destination']?.toString() ?? '',
      destLat: json['dest_lat'] != null ? double.tryParse(json['dest_lat'].toString()) : null,
      destLng: json['dest_lng'] != null ? double.tryParse(json['dest_lng'].toString()) : null,
      distanceKm: json['distance_km'] != null ? double.tryParse(json['distance_km'].toString()) : null,
      durationMinutes: json['duration_minutes'] != null ? int.tryParse(json['duration_minutes'].toString()) : null,
      estimatedFare: json['estimated_fare'] != null ? double.tryParse(json['estimated_fare'].toString()) : null,
      customerOffer: json['customer_offer'] != null ? double.tryParse(json['customer_offer'].toString()) : null,
      driverCounterOffer: json['driver_counter_offer'] != null ? double.tryParse(json['driver_counter_offer'].toString()) : null,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      status: status,
      customerCarModel: json['customer_car_model']?.toString(),
      hoursOrDaysText: json['hours_or_days_text']?.toString() ?? 'Service',
      createdAt: json['created_at']?.toString() ?? '',
      negotiatedFare: json['negotiated_fare'] != null ? double.tryParse(json['negotiated_fare'].toString()) : null,
      negotiationStatus: json['negotiation_status']?.toString() ?? 'NONE',
      startOtp: json['start_otp']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? json['phone']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Booking copyWith({
    String? id,
    String? userId,
    String? userName,
    String? driverId,
    String? driverName,
    String? vehicleId,
    String? vehicleModel,
    String? carListingId,
    BookingType? bookingType,
    DriverHiringType? hiringType,
    String? startDate,
    String? endDate,
    String? pickupLocation,
    double? pickupLat,
    double? pickupLng,
    String? destination,
    double? destLat,
    double? destLng,
    double? distanceKm,
    int? durationMinutes,
    double? estimatedFare,
    double? customerOffer,
    double? driverCounterOffer,
    double? totalAmount,
    BookingStatus? status,
    String? customerCarModel,
    String? hoursOrDaysText,
    String? createdAt,
    double? negotiatedFare,
    String? negotiationStatus,
    String? startOtp,
    String? customerPhone,
    String? notes,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      carListingId: carListingId ?? this.carListingId,
      bookingType: bookingType ?? this.bookingType,
      hiringType: hiringType ?? this.hiringType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destination: destination ?? this.destination,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      customerOffer: customerOffer ?? this.customerOffer,
      driverCounterOffer: driverCounterOffer ?? this.driverCounterOffer,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      customerCarModel: customerCarModel ?? this.customerCarModel,
      hoursOrDaysText: hoursOrDaysText ?? this.hoursOrDaysText,
      createdAt: createdAt ?? this.createdAt,
      negotiatedFare: negotiatedFare ?? this.negotiatedFare,
      negotiationStatus: negotiationStatus ?? this.negotiationStatus,
      startOtp: startOtp ?? this.startOtp,
      customerPhone: customerPhone ?? this.customerPhone,
      notes: notes ?? this.notes,
    );
  }
}

enum TripStatus {
  assigned('Driver Assigned'),
  driverArrived('Driver Arrived'),
  onTrip('On Trip'),
  completed('Trip Completed');

  final String label;
  const TripStatus(this.label);
}

class Trip {
  final String id;
  final String bookingId;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String? customerName;
  final String? customerPhone;
  final String? vehicleId;
  final String vehicleModel;
  final String startLocation;
  final double? startLat;
  final double? startLng;
  final String endLocation;
  final double? endLat;
  final double? endLng;
  final double? currentLat;
  final double? currentLng;
  final double bearing;
  final String startTime;
  final String? endTime;
  final double distanceKm;
  final double fare;
  final TripStatus status;
  final double currentProgress; // 0.0 to 1.0
  final String otp;
  final String createdAt;

  Trip({
    required this.id,
    required this.bookingId,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    this.customerName,
    this.customerPhone,
    this.vehicleId,
    required this.vehicleModel,
    required this.startLocation,
    this.startLat,
    this.startLng,
    required this.endLocation,
    this.endLat,
    this.endLng,
    this.currentLat,
    this.currentLng,
    this.bearing = 0.0,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    required this.fare,
    required this.status,
    this.currentProgress = 0.0,
    this.otp = '',
    this.createdAt = '',
  });

  factory Trip.fromDbJson(Map<String, dynamic> json, {Booking? booking}) {
    final statusStr = json['status']?.toString().toLowerCase() ?? '';
    TripStatus tripStatus;
    if (statusStr == 'ongoing' || statusStr == 'in_progress' || statusStr == 'started') {
      tripStatus = TripStatus.onTrip;
    } else if (statusStr == 'arrived') {
      tripStatus = TripStatus.driverArrived;
    } else if (statusStr == 'completed') {
      tripStatus = TripStatus.completed;
    } else {
      tripStatus = TripStatus.assigned;
    }

    final startLat = double.tryParse(json['start_lat']?.toString() ?? '') ?? booking?.pickupLat;
    final startLng = double.tryParse(json['start_lng']?.toString() ?? '') ?? booking?.pickupLng;
    final endLat = double.tryParse(json['end_lat']?.toString() ?? '') ?? booking?.destLat;
    final endLng = double.tryParse(json['end_lng']?.toString() ?? '') ?? booking?.destLng;
    final currentLat = double.tryParse(json['current_lat']?.toString() ?? '');
    final currentLng = double.tryParse(json['current_lng']?.toString() ?? '');

    return Trip(
      id: 'TRP-${json['id'] ?? ''}',
      bookingId: 'BK-${json['booking_id'] ?? booking?.id ?? ''}',
      driverId: json['driver_id']?.toString() ?? booking?.driverId ?? '',
      driverName: json['driver_name']?.toString() ?? booking?.driverName ?? '',
      driverPhone: json['driver_phone']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? booking?.userName,
      customerPhone: json['customer_phone']?.toString() ?? booking?.customerPhone,
      vehicleId: json['vehicle_id']?.toString() ?? booking?.vehicleId,
      vehicleModel: json['vehicle_model']?.toString() ?? booking?.customerCarModel ?? booking?.vehicleModel ?? 'Vehicle',
      startLocation: json['start_location']?.toString() ?? booking?.pickupLocation ?? '',
      startLat: startLat,
      startLng: startLng,
      endLocation: json['end_location']?.toString() ?? booking?.destination ?? '',
      endLat: endLat,
      endLng: endLng,
      currentLat: currentLat,
      currentLng: currentLng,
      bearing: double.tryParse(json['bearing']?.toString() ?? '') ?? 0.0,
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString(),
      distanceKm: double.tryParse(json['distance_km']?.toString() ?? '') ?? booking?.distanceKm ?? 0.0,
      fare: double.tryParse(json['fare']?.toString() ?? '') ?? booking?.totalAmount ?? 0.0,
      status: tripStatus,
      currentProgress: tripStatus == TripStatus.completed ? 1.0 : (tripStatus == TripStatus.onTrip ? 0.5 : 0.0),
      otp: json['otp']?.toString() ?? booking?.startOtp ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Trip copyWith({
    String? id,
    String? bookingId,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? customerName,
    String? customerPhone,
    String? vehicleId,
    String? vehicleModel,
    String? startLocation,
    double? startLat,
    double? startLng,
    String? endLocation,
    double? endLat,
    double? endLng,
    double? currentLat,
    double? currentLng,
    double? bearing,
    String? startTime,
    String? endTime,
    double? distanceKm,
    double? fare,
    TripStatus? status,
    double? currentProgress,
    String? otp,
    String? createdAt,
  }) {
    return Trip(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      startLocation: startLocation ?? this.startLocation,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLocation: endLocation ?? this.endLocation,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      bearing: bearing ?? this.bearing,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceKm: distanceKm ?? this.distanceKm,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      currentProgress: currentProgress ?? this.currentProgress,
      otp: otp ?? this.otp,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum PaymentMethod {
  razorpay('Razorpay Gateway'),
  cashfree('Cashfree Payments'),
  upi('Instant UPI'),
  creditCard('Credit/Debit Card');

  final String displayName;
  const PaymentMethod(this.displayName);
}

class Payment {
  final String id;
  final String bookingId;
  final double amount;
  final PaymentMethod paymentMethod;
  final String transactionId;
  final String status;
  final String paidAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
    required this.transactionId,
    this.status = 'PAID',
    this.paidAt = '2026-10-27 10:30',
  });
}

class TripInvoice {
  final String invoiceNumber;
  final String invoiceDate;
  final String bookingId;
  final String bookingType;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String driverName;
  final String driverPhone;
  final String driverRating;
  final String vehicleInfo;
  final String pickupLocation;
  final String destination;
  final String distanceKm;
  final double subtotal;
  final double cgst;
  final double sgst;
  final double gstTotal;
  final double platformFee;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus; // PAID, DUE
  final String transactionId;
  final String? paidAt;
  final bool qrAvailable;
  final String? qrCodeUrl;
  final String? upiIntentUrl;
  final String? upiVpa;
  final String? qrMessage;

  TripInvoice({
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.bookingId,
    required this.bookingType,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.driverName,
    required this.driverPhone,
    required this.driverRating,
    required this.vehicleInfo,
    required this.pickupLocation,
    required this.destination,
    required this.distanceKm,
    required this.subtotal,
    required this.cgst,
    required this.sgst,
    required this.gstTotal,
    required this.platformFee,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.transactionId,
    this.paidAt,
    this.qrAvailable = false,
    this.qrCodeUrl,
    this.upiIntentUrl,
    this.upiVpa,
    this.qrMessage,
  });

  factory TripInvoice.fromJson(Map<String, dynamic> json) {
    final cust = json['customer'] as Map<String, dynamic>? ?? {};
    final drv = json['driver'] as Map<String, dynamic>? ?? {};
    final trip = json['trip_details'] as Map<String, dynamic>? ?? {};
    final fare = json['fare_breakdown'] as Map<String, dynamic>? ?? {};
    final pay = json['payment'] as Map<String, dynamic>? ?? {};
    final qr = json['payment_qr'] as Map<String, dynamic>? ?? {};

    return TripInvoice(
      invoiceNumber: json['invoice_number']?.toString() ?? 'INV-DM-000000',
      invoiceDate: json['invoice_date']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      bookingType: json['booking_type']?.toString() ?? 'hire_driver',
      customerName: cust['name']?.toString() ?? 'Customer',
      customerPhone: cust['phone']?.toString() ?? '',
      customerEmail: cust['email']?.toString() ?? '',
      driverName: drv['name']?.toString() ?? 'Assigned Driver',
      driverPhone: drv['phone']?.toString() ?? '',
      driverRating: drv['rating']?.toString() ?? '0.0',
      vehicleInfo: drv['vehicle']?.toString() ?? 'Chauffeur Vehicle',
      pickupLocation: trip['pickup']?.toString() ?? '',
      destination: trip['destination']?.toString() ?? '',
      distanceKm: trip['distance_km']?.toString() ?? '0.0',
      subtotal: (fare['subtotal'] as num?)?.toDouble() ?? 0.0,
      cgst: (fare['cgst_2_5'] as num?)?.toDouble() ?? 0.0,
      sgst: (fare['sgst_2_5'] as num?)?.toDouble() ?? 0.0,
      gstTotal: (fare['gst_total'] as num?)?.toDouble() ?? 0.0,
      platformFee: (fare['platform_fee'] as num?)?.toDouble() ?? 25.0,
      totalAmount: (fare['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: pay['method']?.toString() ?? 'UPI',
      paymentStatus: pay['status']?.toString() ?? 'DUE',
      transactionId: pay['transaction_id']?.toString() ?? '',
      paidAt: pay['paid_at']?.toString(),
      qrAvailable: qr['available'] == true,
      qrCodeUrl: qr['qr_code_url']?.toString(),
      upiIntentUrl: qr['upi_intent_url']?.toString(),
      upiVpa: qr['upi_vpa']?.toString(),
      qrMessage: qr['message']?.toString(),
    );
  }
}

class Review {
  final String id;
  final String userId;
  final String userName;
  final String driverId;
  final String bookingId;
  final double rating;
  final String comment;
  final String createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.driverId,
    required this.bookingId,
    required this.rating,
    required this.comment,
    this.createdAt = '2026-10-27',
  });
}

enum DocumentType {
  drivingLicense('Driving License (DL)'),
  rcBook('Registration Certificate (RC)'),
  vehicleInsurance('Vehicle Insurance'),
  kycAadhaar('Identity / KYC Document');

  final String label;
  const DocumentType(this.label);
}

class Document {
  final String id;
  final String userId;
  final String userName;
  final DocumentType type;
  final String documentNumber;
  final String fileUrl;
  final String status; // pending, verified, rejected
  final String? verifiedAt;
  final String createdAt;

  Document({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.documentNumber,
    required this.fileUrl,
    this.status = 'pending',
    this.verifiedAt,
    this.createdAt = '2026-10-26',
  });

  Document copyWith({
    String? id,
    String? userId,
    String? userName,
    DocumentType? type,
    String? documentNumber,
    String? fileUrl,
    String? status,
    String? verifiedAt,
    String? createdAt,
  }) {
    return Document(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      type: type ?? this.type,
      documentNumber: documentNumber ?? this.documentNumber,
      fileUrl: fileUrl ?? this.fileUrl,
      status: status ?? this.status,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NotificationItem {
  final String id;
  final String userId;
  final String type; // booking, payment, system, trip
  final String title;
  final String message;
  final bool isRead;
  final String timestamp;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    this.timestamp = 'Just now',
  });

  NotificationItem copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    bool? isRead,
    String? timestamp,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

enum NegotiationStatus {
  pending('PENDING', 'Pending Review'),
  counterOffered('COUNTER_OFFERED', 'Counter Offered'),
  accepted('ACCEPTED', 'Accepted'),
  rejected('REJECTED', 'Rejected'),
  expired('EXPIRED', 'Expired');

  final String code;
  final String label;
  const NegotiationStatus(this.code, this.label);

  static NegotiationStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'COUNTER_OFFERED':
        return NegotiationStatus.counterOffered;
      case 'ACCEPTED':
        return NegotiationStatus.accepted;
      case 'REJECTED':
        return NegotiationStatus.rejected;
      case 'EXPIRED':
        return NegotiationStatus.expired;
      case 'PENDING':
      default:
        return NegotiationStatus.pending;
    }
  }
}

class FareNegotiation {
  final int id;
  final int bookingId;
  final int senderId;
  final String senderName;
  final String senderRole;
  final double offeredFare;
  final double? counterFare;
  final NegotiationStatus status;
  final String? notes;
  final String createdAt;

  FareNegotiation({
    required this.id,
    required this.bookingId,
    required this.senderId,
    this.senderName = '',
    required this.senderRole,
    required this.offeredFare,
    this.counterFare,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory FareNegotiation.fromJson(Map<String, dynamic> json) {
    return FareNegotiation(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      bookingId: json['booking_id'] is int ? json['booking_id'] : int.tryParse(json['booking_id'].toString()) ?? 0,
      senderId: json['sender_id'] is int ? json['sender_id'] : int.tryParse(json['sender_id'].toString()) ?? 0,
      senderName: json['sender_name']?.toString() ?? '',
      senderRole: json['sender_role']?.toString() ?? 'customer',
      offeredFare: (json['offered_fare'] is num) ? (json['offered_fare'] as num).toDouble() : double.tryParse(json['offered_fare'].toString()) ?? 0.0,
      counterFare: (json['counter_fare'] != null) ? ((json['counter_fare'] is num) ? (json['counter_fare'] as num).toDouble() : double.tryParse(json['counter_fare'].toString())) : null,
      status: NegotiationStatus.fromString(json['status']?.toString() ?? 'PENDING'),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class SupportContact {
  final String helpline;
  final String tollFree;
  final String emergency;
  final String email;
  final String office;
  final String hours;

  SupportContact({
    required this.helpline,
    required this.tollFree,
    required this.emergency,
    required this.email,
    required this.office,
    required this.hours,
  });

  factory SupportContact.fromJson(Map<String, dynamic> json) {
    return SupportContact(
      helpline: json['helpline']?.toString() ?? '+91 98000 11223',
      tollFree: json['toll_free']?.toString() ?? '1800-DRIVEMATE',
      emergency: json['emergency']?.toString() ?? '112',
      email: json['email']?.toString() ?? 'support@drivemate.com',
      office: json['office']?.toString() ?? 'Station Road, Kakdwip Central, WB 743347',
      hours: json['hours']?.toString() ?? '24x7 Customer Support & Emergency Dispatch',
    );
  }
}

class SupportFaq {
  final int id;
  final String category;
  final String question;
  final String answer;

  SupportFaq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  factory SupportFaq.fromJson(Map<String, dynamic> json) {
    return SupportFaq(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      category: json['category']?.toString() ?? 'general',
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
    );
  }
}

class SupportTicket {
  final int id;
  final int userId;
  final int? bookingId;
  final String subject;
  final String category;
  final String message;
  final String? adminReply;
  final String status;
  final String createdAt;
  final String? resolvedAt;
  final String? bookingType;
  final String? pickupLocation;
  final String? destination;
  final double? totalAmount;
  final String? bookingStatus;

  SupportTicket({
    required this.id,
    required this.userId,
    this.bookingId,
    required this.subject,
    required this.category,
    required this.message,
    this.adminReply,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.bookingType,
    this.pickupLocation,
    this.destination,
    this.totalAmount,
    this.bookingStatus,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id'].toString()) ?? 0,
      bookingId: json['booking_id'] != null ? int.tryParse(json['booking_id'].toString()) : null,
      subject: json['subject']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      message: json['message']?.toString() ?? '',
      adminReply: json['admin_reply']?.toString(),
      status: json['status']?.toString() ?? 'open',
      createdAt: json['created_at']?.toString() ?? '',
      resolvedAt: json['resolved_at']?.toString(),
      bookingType: json['booking_type']?.toString(),
      pickupLocation: json['pickup_location']?.toString(),
      destination: json['destination']?.toString(),
      totalAmount: (json['total_amount'] != null)
          ? ((json['total_amount'] is num) ? (json['total_amount'] as num).toDouble() : double.tryParse(json['total_amount'].toString()))
          : null,
      bookingStatus: json['booking_status']?.toString(),
    );
  }
}

class EligibleDriver {
  final int id;
  final String name;
  final String? avatar;
  final String? licenseNumber;
  final String vehicleType;
  final String vehicleModel;
  final String? vehicleNumber;
  final double? avgRating;
  final int totalTrips;
  final int? experienceYears;
  final double hourlyRate;
  final double estimatedFare;
  final bool isOnline;
  final bool isBusy;
  final bool isAvailable;
  final String verificationStatus;
  final double? currentLat;
  final double? currentLng;
  final double? distanceKm;
  final int? etaMinutes;
  final double? matchScore;
  final Map<String, dynamic>? scoreBreakdown;

  EligibleDriver({
    required this.id,
    required this.name,
    this.avatar,
    this.licenseNumber,
    this.vehicleType = 'Sedan',
    this.vehicleModel = 'Standard Car',
    this.vehicleNumber,
    this.avgRating,
    this.totalTrips = 0,
    this.experienceYears,
    this.hourlyRate = 150.0,
    this.estimatedFare = 290.0,
    this.isOnline = true,
    this.isBusy = false,
    this.isAvailable = true,
    this.verificationStatus = 'verified',
    this.currentLat,
    this.currentLng,
    this.distanceKm,
    this.etaMinutes,
    this.matchScore,
    this.scoreBreakdown,
  });

  factory EligibleDriver.fromJson(Map<String, dynamic> json) {
    return EligibleDriver(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['driver_name']?.toString() ?? json['name']?.toString() ?? 'Verified Driver',
      avatar: json['avatar']?.toString(),
      licenseNumber: json['license_number']?.toString(),
      vehicleType: json['vehicle_type']?.toString() ?? 'Sedan',
      vehicleModel: json['vehicle_model']?.toString() ?? 'Standard Car',
      vehicleNumber: json['vehicle_number']?.toString(),
      avgRating: json['avg_rating'] != null ? double.tryParse(json['avg_rating'].toString()) : null,
      totalTrips: json['total_trips'] is int ? json['total_trips'] : int.tryParse(json['total_trips']?.toString() ?? '0') ?? 0,
      experienceYears: json['experience_years'] != null ? int.tryParse(json['experience_years'].toString()) : null,
      hourlyRate: double.tryParse(json['hourly_rate']?.toString() ?? '150.0') ?? 150.0,
      estimatedFare: double.tryParse(json['estimated_fare']?.toString() ?? '290.0') ?? 290.0,
      isOnline: json['is_online'] == true || json['is_online'] == 1 || json['is_online'] == '1',
      isBusy: json['is_busy'] == true || json['is_busy'] == 1 || json['is_busy'] == '1',
      isAvailable: json['is_available'] == true || json['is_available'] == 1 || json['is_available'] == '1',
      verificationStatus: json['verification_status']?.toString() ?? json['status']?.toString() ?? 'verified',
      currentLat: json['current_lat'] != null ? double.tryParse(json['current_lat'].toString()) : null,
      currentLng: json['current_lng'] != null ? double.tryParse(json['current_lng'].toString()) : null,
      distanceKm: json['distance_km'] != null ? double.tryParse(json['distance_km'].toString()) : null,
      etaMinutes: json['eta_minutes'] != null ? int.tryParse(json['eta_minutes'].toString()) : null,
      matchScore: json['total_match_score'] != null ? double.tryParse(json['total_match_score'].toString()) : null,
      scoreBreakdown: json['score_breakdown'] is Map<String, dynamic> ? json['score_breakdown'] : null,
    );
  }

  double? get latitude => currentLat;
  double? get longitude => currentLng;
  String? get profilePhoto => avatar;
}

class DriverReviewItem {
  final int id;
  final double rating;
  final String comment;
  final String reviewerName;
  final String? reviewerAvatar;
  final String createdAt;

  DriverReviewItem({
    required this.id,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    this.reviewerAvatar,
    required this.createdAt,
  });

  factory DriverReviewItem.fromJson(Map<String, dynamic> json) {
    return DriverReviewItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      rating: double.tryParse(json['rating']?.toString() ?? '0.0') ?? 0.0,
      comment: json['comment']?.toString() ?? '',
      reviewerName: json['reviewer_name']?.toString() ?? 'Customer',
      reviewerAvatar: json['reviewer_avatar']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
