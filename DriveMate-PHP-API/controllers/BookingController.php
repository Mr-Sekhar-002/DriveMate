<?php
// controllers/BookingController.php — Create, cancel, list bookings

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';
require_once __DIR__ . '/PricingController.php';

class BookingController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // POST /bookings/create
    public function create(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];
        $data   = Response::body();

        $rawType     = strtolower(trim($data['type'] ?? ''));
        // Normalize camelCase / snake_case formats
        if ($rawType === 'hiredriver') $type = 'hire_driver';
        elseif ($rawType === 'rentcar') $type = 'rent_car';
        elseif ($rawType === 'rentcaranddriver' || $rawType === 'rent_car_and_driver') $type = 'rent_car_driver';
        elseif ($rawType === 'outstation') $type = 'outstation';
        else $type = $rawType;

        $rawHiringType = strtolower(trim($data['hiring_type'] ?? 'one_way'));
        if (in_array($rawHiringType, ['one_way', 'round_trip', 'hourly', 'half_day', 'full_day', 'daily', 'outstation'])) {
            $hiringType = $rawHiringType;
        } else {
            $hiringType = 'one_way';
        }

        $driverId    = !empty($data['driver_id']) ? (int)$data['driver_id'] : null;
        $vehicleId   = !empty($data['vehicle_id']) ? (int)$data['vehicle_id'] : null;
        $carListingId= !empty($data['car_listing_id']) ? (int)$data['car_listing_id'] : null;
        $startDate   = !empty($data['start_date']) ? $data['start_date'] : date('Y-m-d H:i:s');
        $endDate     = !empty($data['end_date']) ? $data['end_date'] : null;
        $pickupLoc   = $data['pickup_location'] ?? '';
        $pickupLat   = isset($data['pickup_lat']) ? (float)$data['pickup_lat'] : null;
        $pickupLng   = isset($data['pickup_lng']) ? (float)$data['pickup_lng'] : null;
        $destination = $data['destination']  ?? '';
        $destLat     = isset($data['dest_lat']) ? (float)$data['dest_lat'] : null;
        $destLng     = isset($data['dest_lng']) ? (float)$data['dest_lng'] : null;
        $distanceKm  = isset($data['distance_km']) ? (float)$data['distance_km'] : null;
        $durationMin = isset($data['duration_minutes']) ? (int)$data['duration_minutes'] : null;
        $totalAmount = (float)($data['total_amount'] ?? 0);
        $negotiatedFare = isset($data['negotiated_fare']) && (float)$data['negotiated_fare'] > 0 ? (float)$data['negotiated_fare'] : null;
        $negStatus   = !empty($data['negotiation_status']) ? $data['negotiation_status'] : ($negotiatedFare ? 'PENDING' : 'NONE');

        if (!$type) {
            Response::error('Booking type is required');
        }

        if (!in_array($type, ['hire_driver', 'rent_car', 'rent_car_driver', 'outstation'])) {
            Response::error('Invalid booking type');
        }

        // Server-side authoritative fare calculation (Feature 4: Smart Fare Calculator)
        $pricingCtrl = new PricingController();
        $authoritative = $pricingCtrl->computeAuthoritativeFare([
            'service_type'     => $type,
            'hiring_type'      => $hiringType,
            'distance_km'      => $distanceKm ?? 10.0,
            'duration_minutes' => $durationMin ?? 25,
            'hours'            => (float)($data['hours'] ?? 0.0),
            'days'             => (int)($data['days'] ?? 0),
            'waiting_minutes'  => (int)($data['waiting_minutes'] ?? 0),
            'toll_charges'     => (float)($data['toll_charges'] ?? 0.0),
            'parking_charges'  => (float)($data['parking_charges'] ?? 0.0),
            'promo_code'       => $data['promo_code'] ?? null,
            'start_time'       => $startDate,
            'is_final'         => false
        ]);
        $authoritativeFare = (float)$authoritative['breakdown']['total_fare'];

        // Enforce server-authoritative pricing (never trust untrusted client fare manipulation)
        if ($negotiatedFare !== null && $negotiatedFare >= 50.0) {
            $totalAmount = $negotiatedFare;
        } elseif ($totalAmount <= 0) {
            $totalAmount = $authoritativeFare;
        } else {
            // Disallow client fare under-reporting
            if ($totalAmount < 50.00) {
                $totalAmount = $authoritativeFare;
            }
        }
        $estimatedFare = $authoritativeFare;
        $fareBreakdownJson = json_encode($authoritative);

        // Server-side fare validation
        if ($totalAmount <= 0) {
            Response::error('Total booking amount must be greater than 0', 400);
        }
        if ($totalAmount < 50.00) {
            Response::error('Total booking amount cannot be below minimum threshold of ₹50.00', 400);
        }
        if ($totalAmount > 100000.00) {
            Response::error('Total booking amount exceeds allowed platform maximum', 400);
        }
        if ($negotiatedFare !== null) {
            if ($negotiatedFare < 50.00) {
                Response::error('Negotiated fare cannot be below minimum threshold of ₹50.00', 400);
            }
            if ($negotiatedFare > 100000.00) {
                Response::error('Negotiated fare exceeds allowed platform maximum', 400);
            }
        }

        // Computed effective end date for overlap checking (defaults to start_date + 3 hours for one-way/immediate rides)
        $effectiveEndDate = $endDate ?: date('Y-m-d H:i:s', strtotime($startDate . ' + 3 hours'));

        // If booking requires a driver but no driver is pre-assigned, or negotiation is pending, status must be pending
        if ($negStatus === 'PENDING' || ($type !== 'rent_car' && empty($driverId))) {
            $bookingStatus = 'pending';
        } else {
            $bookingStatus = 'confirmed';
        }

        // For self-drive rent_car, driverId must be null
        if ($type === 'rent_car') {
            $driverId = null;
        }

        // Validate selected driver: role, KYC status, online status, and prevent double booking
        if ($driverId !== null) {
            $dCheck = $this->db->prepare("
                SELECT u.id, u.status AS user_status, dp.status AS profile_status, dp.is_online,
                       (SELECT COUNT(*) FROM trips WHERE driver_id = u.id AND status = 'ongoing') +
                       (SELECT COUNT(*) FROM bookings WHERE driver_id = u.id AND status IN ('arrived', 'ongoing')) +
                       (SELECT COUNT(*) FROM bookings WHERE driver_id = u.id AND status = 'confirmed' AND (
                           start_date <= ? AND COALESCE(NULLIF(end_date, '0000-00-00 00:00:00'), DATE_ADD(start_date, INTERVAL 3 HOUR)) >= ?
                       )) AS active_engagements
                FROM users u
                LEFT JOIN driver_profile dp ON dp.user_id = u.id
                WHERE u.id = ? AND u.role = 'driver'
            ");
            $dCheck->execute([$effectiveEndDate, $startDate, $driverId]);
            $driverRow = $dCheck->fetch(PDO::FETCH_ASSOC);

            if (!$driverRow || $driverRow['user_status'] !== 'active') {
                Response::error('Selected driver does not exist or account is inactive', 400);
            }
            if (($driverRow['profile_status'] ?? '') !== 'verified') {
                Response::error('Selected driver KYC is not verified yet', 400);
            }
            if ((int)($driverRow['is_online'] ?? 0) !== 1) {
                Response::error('Selected driver is currently offline and unavailable', 409);
            }
            if ((int)($driverRow['active_engagements'] ?? 0) > 0) {
                Response::error('Selected driver is currently engaged in another trip/booking. Double booking is not permitted.', 409);
            }
        }

        // Validate selected vehicle: status and prevent double booking
        if ($vehicleId !== null) {
            $vCheck = $this->db->prepare("
                SELECT v.id, v.status,
                       (SELECT COUNT(*) FROM bookings WHERE vehicle_id = v.id AND status IN ('confirmed', 'arrived', 'ongoing') AND (start_date <= ? AND COALESCE(NULLIF(end_date, '0000-00-00 00:00:00'), DATE_ADD(start_date, INTERVAL 3 HOUR)) >= ?)) AS active_bookings
                FROM vehicles v
                WHERE v.id = ?
            ");
            $vCheck->execute([$effectiveEndDate, $startDate, $vehicleId]);
            $vehicleRow = $vCheck->fetch(PDO::FETCH_ASSOC);

            if (!$vehicleRow || $vehicleRow['status'] !== 'active') {
                Response::error('Selected vehicle does not exist or is inactive', 400);
            }
            if ((int)($vehicleRow['active_bookings'] ?? 0) > 0) {
                Response::error('Selected vehicle is already booked for the specified timeframe. Double booking is not permitted.', 409);
            }
        }

        // Cryptographically secure, booking-specific 4-digit ride OTP (exclusively generated server-side)
        $startOtp = sprintf('%04d', random_int(1000, 9999));

        // Dynamic OTP Expiry:
        // Immediate rides: 30 minutes from creation
        // Scheduled rides: 30 minutes after scheduled pickup time
        $pickupTimestamp    = !empty($startDate) ? strtotime($startDate) : time();
        $otpExpiryTimestamp = ($pickupTimestamp > time())
            ? $pickupTimestamp + (30 * 60)
            : time() + (30 * 60);
        $otpExpiresAt = date('Y-m-d H:i:s', $otpExpiryTimestamp);

        $stmt = $this->db->prepare("
            INSERT INTO bookings
              (user_id, type, hiring_type, driver_id, vehicle_id, car_listing_id,
               start_date, end_date, pickup_location, pickup_lat, pickup_lng,
               destination, dest_lat, dest_lng, distance_km, duration_minutes,
               estimated_fare, total_amount, fare_breakdown, is_fare_final,
               negotiated_fare, negotiation_status, start_otp, start_otp_expires_at, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ");
        $stmt->execute([
            $userId, $type, $hiringType, $driverId, $vehicleId, $carListingId,
            $startDate, $endDate, $pickupLoc, $pickupLat, $pickupLng,
            $destination, $destLat, $destLng, $distanceKm, $durationMin,
            $estimatedFare, $totalAmount, $fareBreakdownJson, 0,
            $negotiatedFare, $negStatus, $startOtp, $otpExpiresAt, $bookingStatus
        ]);
        $bookingId = (int)$this->db->lastInsertId();

        // Authoritative server-side booking reference code
        $bookingRef = 'DM-BK-' . date('Ymd') . '-' . str_pad((string)$bookingId, 4, '0', STR_PAD_LEFT);
        $this->db->prepare("UPDATE bookings SET booking_reference = ? WHERE id = ?")->execute([$bookingRef, $bookingId]);

        $negotiationId = null;
        if ($negotiatedFare && $negStatus === 'PENDING') {
            $notes = trim($data['notes'] ?? 'Customer proposed initial fare offer');
            $nStmt = $this->db->prepare("
                INSERT INTO fare_negotiations (booking_id, sender_id, sender_role, offered_fare, status, notes, created_at)
                VALUES (?, ?, 'customer', ?, 'PENDING', ?, NOW())
            ");
            $nStmt->execute([$bookingId, $userId, $negotiatedFare, $notes]);
            $negotiationId = (int)$this->db->lastInsertId();
        }

        // Phase 17: Trigger Real-Time Driver Booking Push Notification
        try {
            require_once __DIR__ . '/NotificationController.php';
            $custName = !empty($auth['name']) ? $auth['name'] : null;
            if (!$custName) {
                $uStmt = $this->db->prepare("SELECT name FROM users WHERE id = ?");
                $uStmt->execute([$userId]);
                $custName = $uStmt->fetchColumn() ?: 'Valued Customer';
            }
            $finalFare = (float)($negotiatedFare ?: $totalAmount);

            if ($driverId) {
                NotificationController::sendBookingNotification(
                    bookingId: $bookingId,
                    driverId: (int)$driverId,
                    customerName: $custName,
                    pickup: (string)($pickupLoc ?? 'Pickup point'),
                    destination: (string)($destination ?? 'Destination'),
                    fare: $finalFare
                );
            } else {
                NotificationController::broadcastBookingNotification(
                    bookingId: $bookingId,
                    customerName: $custName,
                    pickup: (string)($pickupLoc ?? 'Pickup point'),
                    destination: (string)($destination ?? 'Destination'),
                    fare: $finalFare
                );
            }
        } catch (Exception $e) {
            error_log('[NotificationError] ' . $e->getMessage());
        }

        Response::success([
            'booking_id'         => $bookingId,
            'booking_reference'  => $bookingRef,
            'type'               => $type,
            'hiring_type'        => $hiringType,
            'status'             => $bookingStatus,
            'total_amount'       => $totalAmount,
            'estimated_fare'     => $estimatedFare,
            'fare_breakdown'     => $authoritative,
            'is_fare_final'      => false,
            'negotiation_status' => $negStatus,
            'negotiated_fare'    => $negotiatedFare,
            'negotiation_id'     => $negotiationId,
            'start_otp'          => $startOtp
        ], 'Booking created successfully with authoritative fare computation', 201);
    }

    // POST /bookings/check-availability
    public function checkAvailability(): void {
        $data      = Response::body();
        $vehicleId = !empty($data['vehicle_id']) ? (int)$data['vehicle_id'] : null;
        $driverId  = !empty($data['driver_id']) ? (int)$data['driver_id'] : null;
        $startDate = !empty($data['start_date']) ? $data['start_date'] : date('Y-m-d H:i:s');
        $endDate   = !empty($data['end_date']) ? $data['end_date'] : date('Y-m-d H:i:s', strtotime($startDate . ' +4 hours'));

        $isVehicleAvailable = true;
        $isDriverAvailable  = true;
        $conflictDetails    = [];

        if ($vehicleId !== null) {
            $stmt = $this->db->prepare("
                SELECT id, booking_reference, start_date, end_date, status 
                FROM bookings 
                WHERE vehicle_id = ? AND status IN ('confirmed', 'arrived', 'ongoing')
                  AND (start_date <= ? AND (end_date >= ? OR end_date IS NULL))
                LIMIT 1
            ");
            $stmt->execute([$vehicleId, $endDate, $startDate]);
            $conflict = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($conflict) {
                $isVehicleAvailable = false;
                $conflictDetails['vehicle_conflict'] = $conflict['booking_reference'] ?? ('BK-' . $conflict['id']);
            }
        }

        if ($driverId !== null) {
            $stmt = $this->db->prepare("
                SELECT id, booking_reference, start_date, end_date, status 
                FROM bookings 
                WHERE driver_id = ? AND status IN ('confirmed', 'arrived', 'ongoing')
                  AND (start_date <= ? AND (end_date >= ? OR end_date IS NULL))
                LIMIT 1
            ");
            $stmt->execute([$driverId, $endDate, $startDate]);
            $conflict = $stmt->fetch(PDO::FETCH_ASSOC);
            if ($conflict) {
                $isDriverAvailable = false;
                $conflictDetails['driver_conflict'] = $conflict['booking_reference'] ?? ('BK-' . $conflict['id']);
            }
        }

        $available = $isVehicleAvailable && $isDriverAvailable;

        Response::success([
            'available'          => $available,
            'vehicle_available'  => $isVehicleAvailable,
            'driver_available'   => $isDriverAvailable,
            'start_date'         => $startDate,
            'end_date'           => $endDate,
            'conflicts'          => $conflictDetails,
            'message'            => $available 
                ? 'Selected resources are available for this timeframe.' 
                : 'Selected vehicle or driver is reserved during the chosen timeframe. Please select another slot.'
        ]);
    }

    // GET /bookings/my
    public function myBookings(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];
        $role   = $auth['role'] ?? 'customer';

        $whereClause = ($role === 'driver') ? "b.driver_id = ?" : "b.user_id = ?";

        $stmt = $this->db->prepare("
            SELECT b.*, 
                   u.name AS driver_name, u.phone AS driver_phone,
                   cu.name AS customer_name, cu.phone AS customer_phone,
                   v.model AS vehicle_model, v.number_plate
            FROM bookings b
            LEFT JOIN users u ON b.driver_id = u.id
            LEFT JOIN users cu ON b.user_id = cu.id
            LEFT JOIN vehicles v ON b.vehicle_id = v.id
            WHERE {$whereClause}
            ORDER BY b.created_at DESC
        ");
        $stmt->execute([$userId]);
        $bookings = $stmt->fetchAll();

        // Drivers must never see customer Ride OTPs in booking lists
        if ($role === 'driver') {
            foreach ($bookings as &$b) {
                unset($b['start_otp'], $b['start_otp_attempts'], $b['start_otp_verified_at'], $b['start_otp_expires_at']);
            }
            unset($b);
        }

        Response::success($bookings);
    }

    // GET /bookings/:id (RBAC & BOLA / IDOR protection)
    public function getById(): void {
        $auth      = AuthMiddleware::authenticate();
        $bookingId = (int)($_GET['id'] ?? 0);

        if ($bookingId <= 0) Response::error('Valid Booking ID required', 400);

        $stmt = $this->db->prepare("
            SELECT b.*, 
                   u.name AS driver_name, u.phone AS driver_phone,
                   cu.name AS customer_name, cu.phone AS customer_phone,
                   v.model AS vehicle_model, v.number_plate
            FROM bookings b
            LEFT JOIN users u ON b.driver_id = u.id
            LEFT JOIN users cu ON b.user_id = cu.id
            LEFT JOIN vehicles v ON b.vehicle_id = v.id
            WHERE b.id = ?
        ");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();

        if (!$booking) Response::error('Booking not found', 404);

        $userId = (int)$auth['sub'];
        $role   = $auth['role'];
        $isCustomer = ((int)$booking['user_id'] === $userId);
        $isDriver   = (!empty($booking['driver_id']) && (int)$booking['driver_id'] === $userId);
        $isAdmin    = ($role === 'admin');
        $isAvailableToDriver = ($role === 'driver' && empty($booking['driver_id']) && $booking['status'] === 'pending');

        if (!$isCustomer && !$isDriver && !$isAdmin && !$isAvailableToDriver) {
            Response::error('Forbidden: You are not authorized to view this booking', 403);
        }

        // Shield sensitive Ride OTP from driver: passenger must verbally read OTP at pickup
        if ($role === 'driver' && !$isAdmin) {
            unset($booking['start_otp']);
            unset($booking['start_otp_attempts']);
            unset($booking['start_otp_verified_at']);
            unset($booking['start_otp_expires_at']);
        }

        Response::success($booking);
    }

    // PUT /bookings/cancel
    public function cancel(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $role   = $auth['role'];
        $data   = Response::body();

        $bookingId = (int)($data['booking_id'] ?? 0);
        if ($bookingId <= 0) Response::error('Valid Booking ID required', 400);

        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();

        if (!$booking) Response::error('Booking not found', 404);

        $isCustomer = ((int)$booking['user_id'] === $userId);
        $isDriver   = (!empty($booking['driver_id']) && (int)$booking['driver_id'] === $userId);
        if (!$isCustomer && !$isDriver && $role !== 'admin') {
            Response::error('Forbidden: You are not authorized to cancel this booking', 403);
        }

        if (in_array($booking['status'], ['ongoing', 'completed', 'cancelled'])) {
            Response::error("Cannot cancel a booking with status '{$booking['status']}'", 400);
        }

        $this->db->prepare("UPDATE bookings SET status = 'cancelled' WHERE id = ?")->execute([$bookingId]);

        // Notify counterparty of booking cancellation
        try {
            require_once __DIR__ . '/NotificationController.php';
            $canceller = ($role === 'driver') ? 'Driver' : 'Customer';
            $recipientId = ($role === 'driver') ? (int)$booking['user_id'] : (int)($booking['driver_id'] ?? 0);
            if ($recipientId > 0) {
                NotificationController::notifyBookingCancelled($recipientId, $bookingId, $canceller, $data['reason'] ?? 'Booking cancelled');
            }
        } catch (Exception $e) {
            error_log('[NotificationError] ' . $e->getMessage());
        }

        Response::success(['booking_id' => $bookingId, 'status' => 'cancelled'], 'Booking cancelled successfully');
    }

    // PUT /bookings/accept  (driver accepts with transactional locking)
    public function accept(): void {
        $auth = AuthMiddleware::requireRole('driver');
        $data = Response::body();
        $bookingId = (int)($data['booking_id'] ?? 0);

        if ($bookingId <= 0) Response::error('Valid booking_id required');

        $this->db->beginTransaction();
        try {
            // Strict row-level lock: ensure only one driver can accept this booking
            $bStmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ? FOR UPDATE");
            $bStmt->execute([$bookingId]);
            $booking = $bStmt->fetch();

            if (!$booking) {
                $this->db->rollBack();
                Response::error('Booking not found', 404);
            }

            if ($booking['status'] !== 'pending') {
                $this->db->rollBack();
                Response::error("Booking is no longer available. Status: '{$booking['status']}'", 400);
            }

            if (!empty($booking['driver_id']) && (int)$booking['driver_id'] !== (int)$auth['sub'] && $auth['role'] !== 'admin') {
                $this->db->rollBack();
                Response::error('Forbidden: This booking is assigned to another driver', 403);
            }

            // Double booking prevention: Check if accepting driver already has an active trip or booking
            $busyCheck = $this->db->prepare("
                SELECT 
                    (SELECT COUNT(*) FROM trips WHERE driver_id = ? AND status = 'ongoing') +
                    (SELECT COUNT(*) FROM bookings WHERE driver_id = ? AND id != ? AND status IN ('confirmed', 'arrived', 'ongoing')) AS active_engagements
            ");
            $busyCheck->execute([$auth['sub'], $auth['sub'], $bookingId]);
            if ((int)$busyCheck->fetchColumn() > 0) {
                $this->db->rollBack();
                Response::error('You already have an active trip/booking. Complete your active trip before accepting a new one.', 409);
            }

            $agreedFare = (float)($booking['negotiated_fare'] ?? $booking['total_amount']);

            // If negotiation is in PENDING state, finalize with latest offer
            if ($booking['negotiation_status'] === 'PENDING') {
                $nStmt = $this->db->prepare("
                    SELECT * FROM fare_negotiations 
                    WHERE booking_id = ? AND status = 'PENDING' 
                    ORDER BY id DESC LIMIT 1 FOR UPDATE
                ");
                $nStmt->execute([$bookingId]);
                $neg = $nStmt->fetch();
                if ($neg) {
                    $agreedFare = (float)$neg['offered_fare'];
                    $this->db->prepare("UPDATE fare_negotiations SET status = 'ACCEPTED' WHERE id = ?")->execute([$neg['id']]);
                }
            }

            $stmt = $this->db->prepare(
                "UPDATE bookings SET status = 'confirmed', driver_id = ?, total_amount = ?, negotiated_fare = ?, negotiation_status = 'AGREED' WHERE id = ?"
            );
            $stmt->execute([$auth['sub'], $agreedFare, $agreedFare, $bookingId]);
            $this->db->commit();

            // Notify Customer that Driver accepted booking
            try {
                require_once __DIR__ . '/NotificationController.php';
                $dName = $auth['name'] ?? 'Your Chauffeur';
                NotificationController::notifyCustomerBookingAccepted((int)$booking['user_id'], $bookingId, $dName);
            } catch (Exception $e) {
                error_log('[NotificationError] ' . $e->getMessage());
            }

            Response::success(['booking_id' => $bookingId, 'fare' => $agreedFare, 'status' => 'confirmed'], 'Booking accepted and locked to your driver account');
        } catch (Exception $e) {
            $this->db->rollBack();
            Response::error('Failed to accept booking: ' . $e->getMessage(), 500);
        }
    }

    // PUT /bookings/reject or POST /bookings/reject (Driver rejects request)
    public function reject(): void {
        $auth = AuthMiddleware::requireRole('driver');
        $data = Response::body();
        $bookingId = (int)($data['booking_id'] ?? 0);
        $reason = trim($data['reason'] ?? 'Driver declined request');

        if ($bookingId <= 0) Response::error('Valid booking_id required');

        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();
        if (!$booking) Response::error('Booking not found', 404);

        if ((int)$booking['driver_id'] !== (int)$auth['sub'] && $auth['role'] !== 'admin') {
            Response::error('Forbidden: You are not the assigned driver', 403);
        }

        $this->db->prepare("UPDATE bookings SET status = 'cancelled', negotiation_status = 'REJECTED' WHERE id = ?")->execute([$bookingId]);
        $this->db->prepare("UPDATE fare_negotiations SET status = 'REJECTED' WHERE booking_id = ? AND status = 'PENDING'")->execute([$bookingId]);

        // Notify Customer of Driver rejection
        try {
            require_once __DIR__ . '/NotificationController.php';
            NotificationController::sendPushToUser(
                (int)$booking['user_id'],
                'Booking Request Declined',
                "Chauffeur was unable to accept Booking #{$bookingId}. Tap to select another driver or auto-match.",
                ['booking_id' => (string)$bookingId],
                $bookingId,
                'booking_rejected'
            );
        } catch (Exception $e) {
            error_log('[NotificationError] ' . $e->getMessage());
        }

        Response::success(['booking_id' => $bookingId, 'status' => 'cancelled', 'reason' => $reason], 'Booking declined by driver');
    }

    // GET /bookings/driver-requests  (driver sees pending requests)
    public function driverRequests(): void {
        $auth     = AuthMiddleware::authenticate();
        $driverId = $auth['sub'];

        $stmt = $this->db->prepare("
            SELECT b.*, u.name AS customer_name, u.phone AS customer_phone
            FROM bookings b
            JOIN users u ON b.user_id = u.id
            WHERE b.driver_id = ? AND b.status = 'pending'
            ORDER BY b.created_at DESC
        ");
        $stmt->execute([$driverId]);
        $requests = $stmt->fetchAll();
        foreach ($requests as &$r) {
            unset($r['start_otp'], $r['start_otp_attempts'], $r['start_otp_verified_at'], $r['start_otp_expires_at']);
        }
        unset($r);
        Response::success($requests);
    }

    // GET /bookings/all  (admin)
    public function allBookings(): void {
        AuthMiddleware::requireRole('admin');

        $status = $_GET['status'] ?? null;
        $sql    = "SELECT b.*, cu.name AS customer_name FROM bookings b JOIN users cu ON b.user_id = cu.id";
        $params = [];
        if ($status) { $sql .= " WHERE b.status = ?"; $params[] = $status; }
        $sql .= " ORDER BY b.created_at DESC";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        Response::success($stmt->fetchAll());
    }

    // POST /bookings/refresh-otp (Customer can refresh an expired or delayed OTP)
    public function refreshOtp(): void {
        $auth      = AuthMiddleware::authenticate();
        $data      = Response::body();
        $bookingId = (int)($data['booking_id'] ?? 0);

        if ($bookingId <= 0) Response::error('Valid booking_id required', 400);

        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();

        if (!$booking) Response::error('Booking not found', 404);

        // Strict ownership check: only the customer who booked can refresh OTP
        if ((int)$booking['user_id'] !== (int)$auth['sub'] && $auth['role'] !== 'admin') {
            Response::error('Forbidden: Only the booking customer can request an OTP refresh', 403);
        }

        if (in_array($booking['status'], ['ongoing', 'completed', 'cancelled'])) {
            Response::error("Cannot refresh OTP for a booking in '{$booking['status']}' state", 400);
        }

        $newOtp = sprintf('%04d', random_int(1000, 9999));
        $newExpiry = date('Y-m-d H:i:s', time() + (30 * 60));

        $this->db->prepare("
            UPDATE bookings 
            SET start_otp = ?, start_otp_attempts = 0, start_otp_expires_at = ?, start_otp_verified_at = NULL 
            WHERE id = ?
        ")->execute([$newOtp, $newExpiry, $bookingId]);

        Response::success([
            'booking_id'   => $bookingId,
            'start_otp'    => $newOtp,
            'expires_at'   => $newExpiry,
            'message'      => 'A fresh Ride OTP has been generated for your trip.'
        ], 'Ride OTP refreshed successfully');
    }
}
