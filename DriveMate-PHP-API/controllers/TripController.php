<?php
// controllers/TripController.php — Start, update location, complete trip

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class TripController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // POST /trips/start (Assigned Driver Only)
    public function start(): void {
        $auth = AuthMiddleware::authenticate();
        if ($auth['role'] !== 'driver' && $auth['role'] !== 'admin') {
            Response::error('Forbidden: Only the assigned driver can start a trip', 403);
        }

        $data = Response::body();
        $bookingId = $data['booking_id']      ?? null;
        $startLat  = $data['start_latitude']  ?? null;
        $startLng  = $data['start_longitude'] ?? null;

        if (!$bookingId) Response::error('Booking ID required');

        // Verify booking exists
        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();
        if (!$booking) Response::error('Booking not found', 404);

        // RBAC: Verify authenticated driver is the assigned driver
        if ($auth['role'] !== 'admin' && (int)$booking['driver_id'] !== (int)$auth['sub']) {
            Response::error('Forbidden: You are not the assigned driver for this booking', 403);
        }

        // Strict Fare Agreement Check: Driver cannot start trip while negotiation is pending
        if (!empty($booking['negotiation_status']) && $booking['negotiation_status'] === 'PENDING') {
            Response::error("Cannot start trip: Fare negotiation is still pending agreement between customer and driver", 400);
        }

        // Strict lifecycle: Only confirmed or arrived bookings can transition to ongoing
        if ($booking['status'] !== 'confirmed' && $booking['status'] !== 'arrived') {
            Response::error("Invalid transition: Booking status is '{$booking['status']}', expected 'confirmed' or 'arrived'", 400);
        }

        // Strict Ride OTP Verification: Driver must enter the customer's 4-digit ride OTP
        // Or if previously verified via /trips/verify-otp, start_otp_verified_at will be set
        $enteredOtp = trim((string)($data['otp'] ?? $data['start_otp'] ?? ''));

        if (empty($booking['start_otp_verified_at'])) {
            if (empty($booking['start_otp'])) {
                Response::error("No active Ride OTP found for this booking. Please contact support or request a new OTP.", 400);
            }

            if ((int)$booking['start_otp_attempts'] >= 5) {
                Response::error("Maximum OTP verification attempts (5) exceeded. Ride is locked for security.", 429);
            }

            if (!empty($booking['start_otp_expires_at']) && strtotime($booking['start_otp_expires_at']) < time()) {
                Response::error("Ride OTP has expired. Please have customer refresh the ride to generate a new OTP.", 400);
            }

            if (empty($enteredOtp)) {
                Response::error("Ride OTP required: Driver must ask customer for the 4-digit ride OTP before starting", 400);
            }

            $expectedOtp = (string)$booking['start_otp'];
            if ($enteredOtp !== $expectedOtp) {
                $newAttempts = (int)$booking['start_otp_attempts'] + 1;
                $this->db->prepare("UPDATE bookings SET start_otp_attempts = ? WHERE id = ?")->execute([$newAttempts, $bookingId]);
                $remaining = max(0, 5 - $newAttempts);
                Response::error("Invalid Ride OTP '$enteredOtp'. {$remaining} attempts remaining.", 400);
            }

            // OTP is valid: mark verified and consume (one-time use)
            $this->db->prepare("
                UPDATE bookings 
                SET start_otp_verified_at = NOW(), start_otp = NULL, start_otp_attempts = 0 
                WHERE id = ?
            ")->execute([$bookingId]);
        }

        $this->db->beginTransaction();
        try {
            $stmt = $this->db->prepare("
                INSERT INTO trips (booking_id, driver_id, vehicle_id, start_location, start_lat, start_lng, start_time, status)
                VALUES (?, ?, ?, ?, ?, ?, NOW(), 'ongoing')
            ");
            $stmt->execute([
                $bookingId, $booking['driver_id'], $booking['vehicle_id'],
                $booking['pickup_location'], $startLat, $startLng
            ]);
            $tripId = (int)$this->db->lastInsertId();

            // Update booking status to ongoing
            $this->db->prepare("UPDATE bookings SET status = 'ongoing' WHERE id = ?")->execute([$bookingId]);

            // Record status history audit
            $this->db->prepare("
                INSERT INTO trip_status_history (trip_id, status, changed_by_user_id, notes, created_at)
                VALUES (?, 'ongoing', ?, 'Trip started by assigned driver', NOW())
            ")->execute([$tripId, $auth['sub']]);

            $this->db->commit();

            // Notify customer that trip has started
            try {
                require_once __DIR__ . '/NotificationController.php';
                NotificationController::notifyTripStarted((int)$booking['user_id'], $bookingId);
            } catch (Exception $e) {
                error_log('[TripNotification Error] ' . $e->getMessage());
            }

            Response::success(['trip_id' => $tripId, 'status' => 'ongoing'], 'Trip started successfully', 201);
        } catch (Exception $e) {
            $this->db->rollBack();
            Response::error('Failed to start trip: ' . $e->getMessage(), 500);
        }
    }

    // PUT /trips/update-location  (Assigned Driver sends GPS live updates)
    public function updateLocation(): void {
        $auth = AuthMiddleware::authenticate();
        if ($auth['role'] !== 'driver' && $auth['role'] !== 'admin') {
            Response::error('Forbidden: Only the assigned driver can update trip location', 403);
        }

        $data    = Response::body();
        $tripId  = $data['trip_id']   ?? null;
        $lat     = $data['latitude']  ?? null;
        $lng     = $data['longitude'] ?? null;
        $bearing = isset($data['bearing']) ? (float)$data['bearing'] : 0.0;

        if (!$tripId || !$lat || !$lng) Response::error('trip_id, latitude, longitude required');

        $tStmt = $this->db->prepare("SELECT driver_id, status FROM trips WHERE id = ?");
        $tStmt->execute([$tripId]);
        $trip = $tStmt->fetch();
        if (!$trip) Response::error('Trip not found', 404);

        if ($auth['role'] !== 'admin' && (int)$trip['driver_id'] !== (int)$auth['sub']) {
            Response::error('Forbidden: You are not the assigned driver for this trip', 403);
        }

        if ($trip['status'] !== 'ongoing') {
            Response::error("Cannot update location for a trip that is not ongoing (current status: {$trip['status']})", 400);
        }

        $stmt = $this->db->prepare(
            "UPDATE trips SET current_lat = ?, current_lng = ?, bearing = ?, updated_at = NOW() WHERE id = ?"
        );
        $stmt->execute([$lat, $lng, $bearing, $tripId]);

        Response::success(['bearing' => $bearing], 'Location updated');
    }

    // GET /trips/live-location  (Customer/Driver/Admin tracks driver live)
    public function getLiveLocation(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $role   = $auth['role'];
        $tripId = (int)($_GET['trip_id'] ?? 0);
        if ($tripId <= 0) Response::error('Valid trip_id required', 400);

        $stmt = $this->db->prepare("
            SELECT t.current_lat, t.current_lng, t.bearing, t.updated_at, t.status, t.driver_id,
                   b.user_id AS customer_id
            FROM trips t
            JOIN bookings b ON t.booking_id = b.id
            WHERE t.id = ?
        ");
        $stmt->execute([$tripId]);
        $location = $stmt->fetch();

        if (!$location) Response::error('Trip not found', 404);

        $isCustomer = ((int)$location['customer_id'] === $userId);
        $isDriver   = (!empty($location['driver_id']) && (int)$location['driver_id'] === $userId);
        $isAdmin    = ($role === 'admin');

        if (!$isCustomer && !$isDriver && !$isAdmin) {
            Response::error('Forbidden: You are not authorized to track this trip', 403);
        }

        unset($location['customer_id'], $location['driver_id']);
        Response::success($location);
    }

    // PUT /trips/complete (Driver-Controlled Trip Completion Only)
    public function complete(): void {
        $auth = AuthMiddleware::authenticate();
        // Strict RBAC: Customers cannot complete trips
        if ($auth['role'] !== 'driver' && $auth['role'] !== 'admin') {
            Response::error('Forbidden: Trip completion is strictly driver-controlled. Customers cannot complete trips.', 403);
        }

        $data      = Response::body();
        $tripId    = $data['trip_id']       ?? null;
        $endLat    = $data['end_latitude']  ?? null;
        $endLng    = $data['end_longitude'] ?? null;
        $distanceKm= (float)($data['distance_km'] ?? 0);
        $fare      = (float)($data['fare'] ?? 0);

        if (!$tripId) Response::error('trip_id required');

        $stmt = $this->db->prepare("SELECT * FROM trips WHERE id = ?");
        $stmt->execute([$tripId]);
        $trip = $stmt->fetch();
        if (!$trip) Response::error('Trip not found', 404);

        // RBAC: Verify authenticated driver is the assigned driver
        if ($auth['role'] !== 'admin' && (int)$trip['driver_id'] !== (int)$auth['sub']) {
            Response::error('Forbidden: Only the assigned driver can mark this trip as completed', 403);
        }

        // Strict lifecycle: Only ongoing trips can transition to completed
        if ($trip['status'] !== 'ongoing') {
            Response::error("Invalid transition: Trip status is '{$trip['status']}', expected 'ongoing'", 400);
        }

        // Fetch booking and participants
        $bStmt = $this->db->prepare("
            SELECT b.*, 
                   cu.name AS customer_name, cu.email AS customer_email, cu.phone AS customer_phone,
                   du.name AS driver_name, du.phone AS driver_phone,
                   dp.avg_rating AS driver_rating,
                   v.model AS vehicle_model, v.number_plate
            FROM bookings b
            JOIN users cu ON b.user_id = cu.id
            LEFT JOIN users du ON b.driver_id = du.id
            LEFT JOIN driver_profile dp ON b.driver_id = dp.user_id
            LEFT JOIN vehicles v ON b.vehicle_id = v.id
            WHERE b.id = ?
        ");
        $bStmt->execute([$trip['booking_id']]);
        $booking = $bStmt->fetch();
        if (!$booking) Response::error('Associated booking not found', 404);

        // Step 3: Retrieve the actual mutually accepted final fare
        $finalFare = 0.0;
        if (!empty($booking['negotiation_status']) && $booking['negotiation_status'] === 'AGREED' && (float)$booking['negotiated_fare'] > 0) {
            $finalFare = (float)$booking['negotiated_fare'];
        } elseif ((float)$booking['total_amount'] > 0) {
            $finalFare = (float)$booking['total_amount'];
        } elseif ($fare > 0) {
            $finalFare = $fare;
        } else {
            $baseFare = 150.0;
            $ratePerKm = 18.0;
            try {
                $settingBase = $this->db->query("SELECT setting_value FROM system_settings WHERE setting_key = 'base_fare'")->fetchColumn();
                $settingKm   = $this->db->query("SELECT setting_value FROM system_settings WHERE setting_key = 'rate_per_km'")->fetchColumn();
                if ($settingBase) $baseFare = (float)$settingBase;
                if ($settingKm)   $ratePerKm = (float)$settingKm;
            } catch (Exception $e) {}

            $finalFare = round($baseFare + ($distanceKm * $ratePerKm), 2);
        }

        $this->db->beginTransaction();
        try {
            // Step 4: Mark trip as completed
            $endLocation = $data['end_location'] ?? $booking['destination'] ?? '';
            $this->db->prepare("
                UPDATE trips
                SET end_location = ?, end_lat = ?, end_lng = ?,
                    end_time = NOW(), distance_km = ?, fare = ?, status = 'completed'
                WHERE id = ?
            ")->execute([$endLocation, $endLat, $endLng, $distanceKm, $finalFare, $tripId]);

            // Update booking status and total amount to actual mutually accepted final fare
            $this->db->prepare("UPDATE bookings SET status = 'completed', total_amount = ? WHERE id = ?")
                     ->execute([$finalFare, $trip['booking_id']]);

            // Record status history audit
            $this->db->prepare("
                INSERT INTO trip_status_history (trip_id, status, changed_by_user_id, notes, created_at)
                VALUES (?, 'completed', ?, ?, NOW())
            ")->execute([$tripId, $auth['sub'], "Trip completed by assigned driver with mutually accepted fare ₹{$finalFare}"]);

            // Step 5 & 6: Prevent duplicate invoice/payment generation & generate Payment QR Code
            $pStmt = $this->db->prepare("
                SELECT * FROM payments 
                WHERE booking_id = ? 
                ORDER BY id DESC LIMIT 1
            ");
            $pStmt->execute([$trip['booking_id']]);
            $existingPayment = $pStmt->fetch();

            $txnId = null;
            $paymentStatus = 'unpaid';
            $paidAt = null;
            $paymentMethod = 'upi';

            if ($existingPayment) {
                $paymentStatus = $existingPayment['status'] === 'paid' ? 'paid' : 'unpaid';
                $paidAt = $existingPayment['paid_at'] ?? null;
                $paymentMethod = $existingPayment['payment_method'];
                $txnId = $existingPayment['transaction_id'];

                if ($existingPayment['status'] !== 'paid') {
                    // Update amount to match final agreed fare
                    $this->db->prepare("UPDATE payments SET amount = ? WHERE id = ?")->execute([$finalFare, $existingPayment['id']]);
                }
            } else {
                // Generate a genuine transaction reference and create a single pending payment record
                $txnId = 'DM_TXN_' . $booking['id'] . '_' . time() . '_' . strtoupper(bin2hex(random_bytes(3)));
                $this->db->prepare("
                    INSERT INTO payments (booking_id, user_id, amount, payment_method, transaction_id, status, notes, created_at)
                    VALUES (?, ?, ?, 'upi', ?, 'pending', 'Pending payment generated upon trip completion', NOW())
                ")->execute([$booking['id'], $booking['user_id'], $finalFare, $txnId]);
            }

            $this->db->commit();

            // Notify customer that trip is completed and invoice is available
            try {
                require_once __DIR__ . '/NotificationController.php';
                NotificationController::notifyTripCompleted((int)$booking['user_id'], (int)$booking['id'], (float)$finalFare);
            } catch (Exception $e) {
                error_log('[TripNotification Error] ' . $e->getMessage());
            }

            // Gateway QR generation logic
            $upiVpa = !empty($_ENV['UPI_VPA']) ? trim($_ENV['UPI_VPA']) : null;
            $payeeName = !empty($_ENV['UPI_PAYEE_NAME']) ? trim($_ENV['UPI_PAYEE_NAME']) : 'DriveMate Mobility';
            
            $qrAvailable = false;
            $qrCodeUrl = null;
            $upiIntentUrl = null;
            $qrMessage = '';

            if ($paymentStatus === 'paid') {
                $qrAvailable = false;
                $qrMessage = 'Payment already verified and paid in full.';
            } elseif (!empty($upiVpa) && $upiVpa !== 'not_configured') {
                // Configured gateway available: Generate genuine UPI payment link & QR Code
                $note = rawurlencode("DriveMate Trip #{$tripId} Fare");
                $encodedPayee = rawurlencode($payeeName);
                $upiIntentUrl = "upi://pay?pa={$upiVpa}&pn={$encodedPayee}&am={$finalFare}&cu=INR&tn={$note}&tr={$txnId}";
                $qrCodeUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" . urlencode($upiIntentUrl);
                $qrAvailable = true;
                $qrMessage = "Scan with any UPI app (Google Pay, PhonePe, Paytm, BHIM) to pay.";
            } else {
                // Gateway configuration unavailable: DO NOT generate fake QR code
                $qrAvailable = false;
                $qrMessage = "Online payment gateway is not configured on the server. Please pay cash directly to the driver.";
            }

            // Generate tax invoice structure (5% GST for passenger transport in India)
            $gstRate       = 0.05;
            $subtotal      = round($finalFare / (1 + $gstRate), 2);
            $gstAmount     = round($finalFare - $subtotal, 2);
            $cgst          = round($gstAmount / 2, 2);
            $sgst          = round($gstAmount / 2, 2);
            $platformFee   = 25.00;

            $invoiceData = [
                'invoice_number'   => 'INV-DM-' . str_pad($booking['id'], 6, '0', STR_PAD_LEFT),
                'invoice_date'     => date('Y-m-d H:i:s'),
                'booking_id'       => (int)$booking['id'],
                'booking_type'     => $booking['type'],
                'customer' => [
                    'name'  => $booking['customer_name'],
                    'phone' => $booking['customer_phone'],
                    'email' => $booking['customer_email'],
                ],
                'driver' => [
                    'name'         => $booking['driver_name'] ?? 'Assigned Driver',
                    'phone'        => $booking['driver_phone'] ?? 'N/A',
                    'rating'       => ($booking['driver_rating'] !== null) ? number_format((float)$booking['driver_rating'], 1) : '0.0',
                    'vehicle'      => ($booking['vehicle_model'] ?? 'Chauffeur Service') . ($booking['number_plate'] ? " ({$booking['number_plate']})" : ''),
                ],
                'trip_details' => [
                    'pickup'       => $booking['pickup_location'],
                    'destination'  => $endLocation,
                    'distance_km'  => $distanceKm > 0 ? $distanceKm : (float)($booking['distance_km'] ?? 0),
                    'trip_status'  => 'completed',
                ],
                'fare_breakdown' => [
                    'subtotal'     => $subtotal,
                    'platform_fee' => $platformFee,
                    'cgst_2_5'     => $cgst,
                    'sgst_2_5'     => $sgst,
                    'gst_total'    => $gstAmount,
                    'total_amount' => $finalFare,
                    'currency'     => 'INR',
                ],
                'payment' => [
                    'method'         => strtoupper($paymentMethod),
                    'status'         => $paymentStatus === 'paid' ? 'PAID' : 'DUE',
                    'transaction_id' => $txnId,
                    'paid_at'        => $paidAt,
                ],
                'payment_qr' => [
                    'available'      => $qrAvailable,
                    'qr_code_url'    => $qrCodeUrl,
                    'upi_intent_url' => $upiIntentUrl,
                    'upi_vpa'        => $upiVpa,
                    'transaction_id' => $txnId,
                    'amount'         => $finalFare,
                    'message'        => $qrMessage,
                ]
            ];

            Response::success([
                'trip_id'        => (int)$tripId,
                'booking_id'     => (int)$booking['id'],
                'fare'           => $finalFare,
                'currency'       => 'INR',
                'currency_symbol'=> '₹',
                'status'         => 'completed',
                'payment_status' => $paymentStatus,
                'invoice'        => $invoiceData,
                'payment_qr'     => $invoiceData['payment_qr'],
                'invoice_url'    => "http://localhost/drivemate-api/public/index.php/api/payments/invoice?booking_id={$booking['id']}"
            ], 'Trip completed successfully. Invoice and payment QR generated.');
        } catch (Exception $e) {
            $this->db->rollBack();
            Response::error('Failed to complete trip: ' . $e->getMessage(), 500);
        }
    }

    // GET /trips/status-history (Audit trail for trip transitions)
    public function statusHistory(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $role   = $auth['role'];
        $tripId = (int)($_GET['trip_id'] ?? 0);
        if ($tripId <= 0) Response::error('Valid trip_id required', 400);

        // Verify participant ownership
        $tCheck = $this->db->prepare("
            SELECT t.driver_id, b.user_id AS customer_id
            FROM trips t
            JOIN bookings b ON t.booking_id = b.id
            WHERE t.id = ?
        ");
        $tCheck->execute([$tripId]);
        $part = $tCheck->fetch();

        if (!$part) Response::error('Trip not found', 404);

        $isCustomer = ((int)$part['customer_id'] === $userId);
        $isDriver   = (!empty($part['driver_id']) && (int)$part['driver_id'] === $userId);
        $isAdmin    = ($role === 'admin');

        if (!$isCustomer && !$isDriver && !$isAdmin) {
            Response::error('Forbidden: You are not authorized to view status history for this trip', 403);
        }

        $stmt = $this->db->prepare("
            SELECT h.*, u.name AS changed_by_name, u.role AS changed_by_role
            FROM trip_status_history h
            JOIN users u ON h.changed_by_user_id = u.id
            WHERE h.trip_id = ?
            ORDER BY h.created_at ASC
        ");
        $stmt->execute([$tripId]);
        Response::success($stmt->fetchAll());
    }

    // GET /trips/history  (auth user's trip history)
    public function history(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];

        $stmt = $this->db->prepare("
            SELECT t.*, b.type, b.pickup_location, b.destination
            FROM trips t
            JOIN bookings b ON t.booking_id = b.id
            WHERE b.user_id = ? OR t.driver_id = ?
            ORDER BY t.start_time DESC
        ");
        $stmt->execute([$userId, $userId]);
        Response::success($stmt->fetchAll());
    }

    // POST /trips/verify-otp (Verify customer-provided 4-digit Ride OTP)
    public function verifyOtp(): void {
        $auth = AuthMiddleware::authenticate();
        if ($auth['role'] !== 'driver' && $auth['role'] !== 'admin') {
            Response::error('Forbidden: Only the assigned driver can verify OTP', 403);
        }

        $data = Response::body();
        $bookingId  = (int)($data['booking_id'] ?? 0);
        $enteredOtp = trim((string)($data['otp'] ?? $data['start_otp'] ?? ''));

        if ($bookingId <= 0 || empty($enteredOtp)) {
            Response::error('Booking ID and 4-digit Ride OTP required', 400);
        }

        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();
        if (!$booking) Response::error('Booking not found', 404);

        if ($auth['role'] !== 'admin' && (int)$booking['driver_id'] !== (int)$auth['sub']) {
            Response::error('Forbidden: You are not the assigned driver for this booking', 403);
        }

        if (!empty($booking['negotiation_status']) && $booking['negotiation_status'] === 'PENDING') {
            Response::error('Cannot verify OTP: Fare negotiation is still pending agreement', 400);
        }

        // If already verified, return confirmation
        if (!empty($booking['start_otp_verified_at'])) {
            Response::success([
                'verified'   => true,
                'booking_id' => $bookingId,
                'status'     => $booking['status'],
                'message'    => 'Ride OTP was already verified. Driver is authorized to start the trip.'
            ], 'OTP already verified');
            return;
        }

        if (empty($booking['start_otp'])) {
            Response::error('No active Ride OTP found for this booking.', 400);
        }

        if ((int)$booking['start_otp_attempts'] >= 5) {
            Response::error('Maximum OTP verification attempts (5) exceeded. Ride is locked for security.', 429);
        }

        if (!empty($booking['start_otp_expires_at']) && strtotime($booking['start_otp_expires_at']) < time()) {
            Response::error('Ride OTP has expired. Please have customer request a new OTP.', 400);
        }

        $expectedOtp = (string)$booking['start_otp'];
        if ($enteredOtp !== $expectedOtp) {
            $newAttempts = (int)$booking['start_otp_attempts'] + 1;
            $this->db->prepare("UPDATE bookings SET start_otp_attempts = ? WHERE id = ?")->execute([$newAttempts, $bookingId]);
            $remaining = max(0, 5 - $newAttempts);
            Response::error("Invalid Ride OTP. {$remaining} attempts remaining.", 400);
        }

        // OTP matches: mark verified and consume (one-time use)
        $this->db->prepare("
            UPDATE bookings 
            SET start_otp_verified_at = NOW(), start_otp = NULL, start_otp_attempts = 0 
            WHERE id = ?
        ")->execute([$bookingId]);

        Response::success([
            'verified'   => true,
            'booking_id' => $bookingId,
            'status'     => $booking['status'],
            'message'    => 'Ride OTP verified successfully. Driver is authorized to start the trip.'
        ], 'OTP verified successfully');
    }

    // POST /trips/arrived (Driver arrived at pickup location)
    public function arrived(): void {
        $auth = AuthMiddleware::authenticate();
        if ($auth['role'] !== 'driver' && $auth['role'] !== 'admin') {
            Response::error('Forbidden: Only the assigned driver can mark arrival', 403);
        }

        $data = Response::body();
        $bookingId = (int)($data['booking_id'] ?? 0);
        if ($bookingId <= 0) Response::error('Valid Booking ID required', 400);

        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();
        if (!$booking) Response::error('Booking not found', 404);

        if ($auth['role'] !== 'admin' && (int)$booking['driver_id'] !== (int)$auth['sub']) {
            Response::error('Forbidden: You are not the assigned driver for this booking', 403);
        }

        $this->db->prepare("UPDATE bookings SET status = 'arrived' WHERE id = ?")->execute([$bookingId]);

        // Notify Customer that driver has arrived at pickup location
        try {
            require_once __DIR__ . '/NotificationController.php';
            $dName = $auth['name'] ?? 'Your Chauffeur';
            NotificationController::notifyDriverArrived((int)$booking['user_id'], $bookingId, $dName);
        } catch (Exception $e) {
            error_log('[TripNotification Error] ' . $e->getMessage());
        }

        Response::success([
            'booking_id' => $bookingId,
            'status'     => 'arrived',
            'message'    => 'Driver marked as arrived at pickup location'
        ], 'Arrival confirmed');
    }

    // GET /trips/share-info?booking_ref=... OR ?trip_id=... (Live snapshot for family & sharing)
    public function getShareInfo(): void {
        $tripId = (int)($_GET['trip_id'] ?? 0);
        $bookingRef = trim($_GET['booking_ref'] ?? '');

        if ($tripId <= 0 && empty($bookingRef)) {
            Response::error('trip_id or booking_ref is required', 400);
        }

        $query = "
            SELECT t.id AS trip_id, t.booking_id, t.status AS trip_status,
                   t.start_location, t.start_lat, t.start_lng,
                   t.end_location, t.end_lat, t.end_lng,
                   t.current_lat, t.current_lng, t.bearing, t.updated_at,
                   b.booking_reference, b.status AS booking_status, b.distance_km, b.total_amount,
                   u.name AS driver_name, u.phone AS driver_phone,
                   v.model AS vehicle_model, v.number_plate AS vehicle_number,
                   c.name AS customer_name
            FROM trips t
            JOIN bookings b ON t.booking_id = b.id
            LEFT JOIN users u ON t.driver_id = u.id
            LEFT JOIN vehicles v ON t.vehicle_id = v.id
            LEFT JOIN users c ON b.user_id = c.id
            WHERE " . ($tripId > 0 ? "t.id = ?" : "b.booking_reference = ?") . "
            LIMIT 1
        ";

        $stmt = $this->db->prepare($query);
        $stmt->execute([$tripId > 0 ? $tripId : $bookingRef]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$row) {
            Response::error('Live trip tracking not found', 404);
        }

        $rawPhone = $row['driver_phone'] ?? '';
        $maskedPhone = (strlen($rawPhone) >= 10)
            ? substr($rawPhone, 0, 4) . '******' . substr($rawPhone, -2)
            : $rawPhone;

        $hotlineStmt = $this->db->query("SELECT setting_value FROM system_settings WHERE setting_key = 'emergency_hotline' LIMIT 1");
        $hotline = $hotlineStmt ? ($hotlineStmt->fetchColumn() ?: '+91 99999 99999') : '+91 99999 99999';

        Response::success([
            'trip_id'           => (int)$row['trip_id'],
            'booking_id'        => (int)$row['booking_id'],
            'booking_reference' => $row['booking_reference'] ?? ('DM-BK-' . $row['booking_id']),
            'status'            => $row['trip_status'],
            'start_location'    => $row['start_location'],
            'end_location'      => $row['end_location'],
            'current_lat'       => $row['current_lat'] ? (float)$row['current_lat'] : null,
            'current_lng'       => $row['current_lng'] ? (float)$row['current_lng'] : null,
            'bearing'           => (float)($row['bearing'] ?? 0.0),
            'updated_at'        => $row['updated_at'],
            'driver_name'       => $row['driver_name'] ?? 'Assigned Chauffeur',
            'driver_phone'      => $maskedPhone,
            'vehicle_model'     => $row['vehicle_model'] ?? 'DriveMate Fleet Car',
            'vehicle_number'    => $row['vehicle_number'] ?? 'WB 02 AM 4421',
            'customer_name'     => $row['customer_name'] ?? 'Passenger',
            'emergency_hotline' => $hotline,
            'share_url'         => 'https://drivemate.app/track/' . ($row['booking_reference'] ?? $row['trip_id']),
        ], 'Live trip telemetry snapshot');
    }

    // POST /trips/share-trip  (Customer creates or logs share trip event)
    public function shareTrip(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data   = Response::body();
        $tripId = (int)($data['trip_id'] ?? 0);

        if ($tripId <= 0) {
            Response::error('trip_id is required', 400);
        }

        $stmt = $this->db->prepare("
            SELECT t.id, t.booking_id, b.user_id, b.booking_reference,
                   u.name AS driver_name, v.model AS vehicle_model, v.number_plate AS license_plate
            FROM trips t
            JOIN bookings b ON t.booking_id = b.id
            LEFT JOIN users u ON t.driver_id = u.id
            LEFT JOIN vehicles v ON t.vehicle_id = v.id
            WHERE t.id = ?
        ");
        $stmt->execute([$tripId]);
        $trip = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$trip) {
            Response::error('Trip not found', 404);
        }
        if ((int)$trip['user_id'] !== $userId && $auth['role'] !== 'admin') {
            Response::error('Forbidden: You can only share your own active trips', 403);
        }

        $bookingRef = $trip['booking_reference'] ?? ('DM-BK-' . $trip['booking_id']);
        $shareText = "I am riding with DriveMate! Driver: {$trip['driver_name']}, Vehicle: {$trip['vehicle_model']} ({$trip['license_plate']}). Booking Ref: {$bookingRef}. Track live: https://drivemate.app/track/{$bookingRef}";

        Response::success([
            'trip_id'           => $tripId,
            'booking_reference' => $bookingRef,
            'share_text'        => $shareText,
            'share_url'         => "https://drivemate.app/track/{$bookingRef}",
        ], 'Trip share link generated');
    }
}
