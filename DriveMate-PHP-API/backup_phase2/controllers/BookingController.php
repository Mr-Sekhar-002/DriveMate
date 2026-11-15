<?php
// controllers/BookingController.php — Create, cancel, list bookings

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

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

        $type        = $data['type']        ?? '';   // hire_driver | rent_car | rent_car_driver
        $driverId    = !empty($data['driver_id']) ? (int)$data['driver_id'] : ($type === 'rent_car' ? null : 3);
        $vehicleId   = $data['vehicle_id']   ?? null;
        $carListingId= $data['car_listing_id']?? null;
        $startDate   = !empty($data['start_date']) ? $data['start_date'] : date('Y-m-d H:i:s');
        $endDate     = $data['end_date']     ?? '';
        $pickupLoc   = $data['pickup_location'] ?? '';
        $pickupLat   = isset($data['pickup_lat']) ? (float)$data['pickup_lat'] : null;
        $pickupLng   = isset($data['pickup_lng']) ? (float)$data['pickup_lng'] : null;
        $destination = $data['destination']  ?? '';
        $destLat     = isset($data['dest_lat']) ? (float)$data['dest_lat'] : null;
        $destLng     = isset($data['dest_lng']) ? (float)$data['dest_lng'] : null;
        $totalAmount = (float)($data['total_amount'] ?? 0);
        $negotiatedFare = isset($data['negotiated_fare']) && (float)$data['negotiated_fare'] > 0 ? (float)$data['negotiated_fare'] : null;
        $negStatus   = !empty($data['negotiation_status']) ? $data['negotiation_status'] : ($negotiatedFare ? 'PENDING' : 'NONE');
        $bookingStatus = ($negStatus === 'PENDING') ? 'pending' : 'confirmed';

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

        if (!$type) {
            Response::error('Booking type is required');
        }

        if (!in_array($type, ['hire_driver', 'rent_car', 'rent_car_driver'])) {
            Response::error('Invalid booking type');
        }

        $stmt = $this->db->prepare("
            INSERT INTO bookings
              (user_id, type, driver_id, vehicle_id, car_listing_id,
               start_date, end_date, pickup_location, pickup_lat, pickup_lng,
               destination, dest_lat, dest_lng,
               total_amount, negotiated_fare, negotiation_status, start_otp, start_otp_expires_at, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ");
        $stmt->execute([
            $userId, $type, $driverId, $vehicleId, $carListingId,
            $startDate, $endDate, $pickupLoc, $pickupLat, $pickupLng,
            $destination, $destLat, $destLng, $totalAmount,
            $negotiatedFare, $negStatus, $startOtp, $otpExpiresAt, $bookingStatus
        ]);
        $bookingId = (int)$this->db->lastInsertId();

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
            $custName = $auth['name'] ?? 'Rajesh Das';
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
            'status'             => $bookingStatus,
            'negotiation_status' => $negStatus,
            'negotiated_fare'    => $negotiatedFare,
            'negotiation_id'     => $negotiationId,
            'start_otp'          => $startOtp
        ], 'Booking created successfully', 201);
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
        $userId = $auth['sub'];
        $data   = Response::body();

        $bookingId = $data['booking_id'] ?? null;
        if (!$bookingId) Response::error('Booking ID required');

        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ? AND user_id = ?");
        $stmt->execute([$bookingId, $userId]);
        $booking = $stmt->fetch();

        if (!$booking) Response::error('Booking not found', 404);
        if (in_array($booking['status'], ['completed', 'cancelled'])) {
            Response::error("Cannot cancel a {$booking['status']} booking");
        }

        $this->db->prepare("UPDATE bookings SET status = 'cancelled' WHERE id = ?")->execute([$bookingId]);

        // TODO: Refund logic via payment controller

        Response::success([], 'Booking cancelled');
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
