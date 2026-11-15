<?php
// controllers/DriverHiringController.php — Dedicated Driver-Only Hiring & Location-Based Negotiation Engine

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';
require_once __DIR__ . '/NotificationController.php';

class DriverHiringController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    /**
     * Reads a pricing setting from system_settings with a fallback.
     */
    private function getSetting(string $key, float $default): float {
        try {
            $stmt = $this->db->prepare("SELECT setting_value FROM system_settings WHERE setting_key = ?");
            $stmt->execute([$key]);
            $val = $stmt->fetchColumn();
            return ($val !== false && is_numeric($val)) ? (float)$val : $default;
        } catch (Exception $e) {
            return $default;
        }
    }

    /**
     * Helper to compute estimated driver-only fare using server pricing rules.
     */
    private function computeEstimatedFare(
        string $hiringType,
        float $distanceKm,
        int $durationMinutes,
        int $hours = 4
    ): array {
        $distanceKm = max(0.1, $distanceKm);
        $durationMinutes = max(1, $durationMinutes);
        $durationHours = max(1, (int)ceil($durationMinutes / 60));

        $baseCharge = 150.00;
        $distanceFare = 0.00;
        $timeFare = 0.00;
        $allowances = $this->getSetting('driver_allowance', 50.00);

        switch ($hiringType) {
            case 'round_trip':
                $baseCharge = $this->getSetting('driver_roundtrip_base', 250.00);
                $kmRate = $this->getSetting('driver_roundtrip_km_rate', 12.00);
                $hrRate = $this->getSetting('driver_roundtrip_hr_rate', 80.00);
                
                $totalKm = round($distanceKm * 2, 2);
                $totalHours = max(2, (int)ceil(($durationMinutes * 2) / 60) + 1); // +1 hour wait time
                $distanceFare = round($totalKm * $kmRate, 2);
                $timeFare = round($totalHours * $hrRate, 2);
                $allowances = 100.00;
                $totalFare = round($baseCharge + $distanceFare + $timeFare + $allowances, 2);
                break;

            case 'hourly':
                $hourlyBase = $this->getSetting('driver_hourly_base', 100.00);
                $hourlyRate = $this->getSetting('driver_hourly_rate', 150.00);
                $h = max(2, $hours);
                
                $baseCharge = $hourlyBase;
                $timeFare = round($h * $hourlyRate, 2);
                // Included km = 10 km per hour. Extra distance charged at 12/km
                $includedKm = $h * 10;
                if ($distanceKm > $includedKm) {
                    $extraKm = $distanceKm - $includedKm;
                    $distanceFare = round($extraKm * 12.00, 2);
                } else {
                    $distanceFare = 0.00;
                }
                $totalFare = round($baseCharge + $distanceFare + $timeFare + $allowances, 2);
                break;

            case 'full_day':
                $dailyBase = $this->getSetting('driver_fullday_base', 1200.00);
                $baseCharge = $dailyBase;
                $allowances = 150.00; // Meal & convenience allowance
                // Included 80 km per full-day package
                if ($distanceKm > 80.0) {
                    $distanceFare = round(($distanceKm - 80.0) * 12.00, 2);
                } else {
                    $distanceFare = 0.00;
                }
                $timeFare = 0.00;
                $totalFare = round($baseCharge + $distanceFare + $allowances, 2);
                break;

            case 'one_way':
            default:
                $hiringType = 'one_way';
                $baseCharge = $this->getSetting('driver_oneway_base', 150.00);
                $kmRate = $this->getSetting('driver_oneway_km_rate', 14.00);
                $hrRate = $this->getSetting('driver_oneway_hr_rate', 60.00);

                $distanceFare = round($distanceKm * $kmRate, 2);
                $timeFare = round($durationHours * $hrRate, 2);
                $totalFare = round($baseCharge + $distanceFare + $timeFare + $allowances, 2);
                break;
        }

        // Suggested negotiation range: -15% to +15% rounded to nearest ₹10
        $minSuggested = max(100.00, round(($totalFare * 0.85) / 10) * 10);
        $maxSuggested = round(($totalFare * 1.15) / 10) * 10;

        return [
            'hiring_type'         => $hiringType,
            'distance_km'         => $distanceKm,
            'duration_minutes'    => $durationMinutes,
            'base_charge'         => $baseCharge,
            'distance_fare'       => $distanceFare,
            'time_fare'           => $timeFare,
            'allowances'          => $allowances,
            'estimated_fare'      => $totalFare,
            'min_suggested_offer' => $minSuggested,
            'max_suggested_offer' => $maxSuggested,
            'currency'            => 'INR',
            'currency_symbol'     => '₹'
        ];
    }

    /**
     * POST /api/driver-hiring/estimate
     * Body: {
     *   "pickup": "Kakdwip Railway Station",
     *   "pickup_lat": 21.8767,
     *   "pickup_lng": 88.1912,
     *   "destination": "Lot 8 Ferry Ghat",
     *   "dest_lat": 21.8712,
     *   "dest_lng": 88.1824,
     *   "hiring_type": "one_way" | "round_trip" | "hourly" | "full_day",
     *   "hours": 4,
     *   "distance_km": 14.8,
     *   "duration_minutes": 28
     * }
     */
    public function estimate(): void {
        AuthMiddleware::optionalAuthenticate();
        $data = Response::body();

        $pickup      = trim($data['pickup'] ?? '');
        $destination = trim($data['destination'] ?? '');
        $pickupLat   = isset($data['pickup_lat']) ? (float)$data['pickup_lat'] : null;
        $pickupLng   = isset($data['pickup_lng']) ? (float)$data['pickup_lng'] : null;
        $destLat     = isset($data['dest_lat']) ? (float)$data['dest_lat'] : null;
        $destLng     = isset($data['dest_lng']) ? (float)$data['dest_lng'] : null;
        $hiringType  = strtolower(trim($data['hiring_type'] ?? 'one_way'));
        $hours       = max(1, (int)($data['hours'] ?? 4));

        if (!$pickup || !$destination) {
            Response::error('Pickup and destination addresses are required');
        }

        if (!in_array($hiringType, ['one_way', 'round_trip', 'hourly', 'full_day'])) {
            $hiringType = 'one_way';
        }

        $distanceKm  = isset($data['distance_km']) ? (float)$data['distance_km'] : 0.0;
        $durationMin = isset($data['duration_minutes']) ? (int)$data['duration_minutes'] : 0;

        // If distance not provided or invalid, query OSRM or calculate Haversine with road multiplier
        if ($distanceKm <= 0 && $pickupLat && $pickupLng && $destLat && $destLng) {
            $osrmUrl = "https://router.project-osrm.org/route/v1/driving/{$pickupLng},{$pickupLat};{$destLng},{$destLat}?overview=false";
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $osrmUrl);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_USERAGENT, 'DriveMate-App/2.0');
            curl_setopt($ch, CURLOPT_TIMEOUT, 3);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            $res = curl_exec($ch);
            curl_close($ch);

            if ($res) {
                $json = json_decode($res, true);
                if (($json['code'] ?? '') === 'Ok' && !empty($json['routes'][0])) {
                    $distanceKm = round($json['routes'][0]['distance'] / 1000.0, 2);
                    $durationMin = (int)round($json['routes'][0]['duration'] / 60.0);
                }
            }

            if ($distanceKm <= 0) {
                // Haversine fallback * 1.3 road curvature
                $theta = $pickupLng - $destLng;
                $dist = sin(deg2rad($pickupLat)) * sin(deg2rad($destLat)) +
                        cos(deg2rad($pickupLat)) * cos(deg2rad($destLat)) * cos(deg2rad($theta));
                $dist = acos(min(1.0, max(-1.0, $dist)));
                $dist = rad2deg($dist);
                $miles = $dist * 60 * 1.1515;
                $distanceKm = round(($miles * 1.609344) * 1.3, 2);
                $durationMin = max(10, (int)round($distanceKm * 2.2));
            }
        }

        $breakdown = $this->computeEstimatedFare($hiringType, $distanceKm, $durationMin, $hours);
        $breakdown['pickup'] = $pickup;
        $breakdown['destination'] = $destination;
        $breakdown['hours'] = $hours;

        Response::success($breakdown, 'Location-based driver hiring fare estimated successfully');
    }

    /**
     * POST /api/driver-hiring/booking
     * Body: {
     *   "pickup_location": "...",
     *   "pickup_lat": 21.8767,
     *   "pickup_lng": 88.1912,
     *   "destination": "...",
     *   "dest_lat": 21.8712,
     *   "dest_lng": 88.1824,
     *   "hiring_type": "one_way" | "round_trip" | "hourly" | "full_day",
     *   "hours": 4,
     *   "customer_car_model": "Honda City (Automatic)",
     *   "distance_km": 14.8,
     *   "duration_minutes": 28,
     *   "initial_offer": 450.00, // Optional: if provided, initiates two-way negotiation
     *   "notes": "..."
     * }
     */
    public function createBooking(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data   = Response::body();

        $pickupLoc   = trim($data['pickup_location'] ?? '');
        $destination = trim($data['destination'] ?? '');
        $pickupLat   = isset($data['pickup_lat']) ? (float)$data['pickup_lat'] : null;
        $pickupLng   = isset($data['pickup_lng']) ? (float)$data['pickup_lng'] : null;
        $destLat     = isset($data['dest_lat']) ? (float)$data['dest_lat'] : null;
        $destLng     = isset($data['dest_lng']) ? (float)$data['dest_lng'] : null;
        $hiringType  = strtolower(trim($data['hiring_type'] ?? 'one_way'));
        $hours       = max(1, (int)($data['hours'] ?? 4));
        $carModel    = trim($data['customer_car_model'] ?? 'Customer Owned Vehicle');
        $notes       = trim($data['notes'] ?? '');

        if (!$pickupLoc || !$destination) {
            Response::error('Pickup and destination are required');
        }

        if (!in_array($hiringType, ['one_way', 'round_trip', 'hourly', 'full_day'])) {
            $hiringType = 'one_way';
        }

        $distanceKm  = max(0.5, (float)($data['distance_km'] ?? 10.0));
        $durationMin = max(5, (int)($data['duration_minutes'] ?? 20));

        // Calculate authoritative server estimated fare
        $estimation = $this->computeEstimatedFare($hiringType, $distanceKm, $durationMin, $hours);
        $serverEstimatedFare = $estimation['estimated_fare'];

        $initialOffer = isset($data['initial_offer']) && (float)$data['initial_offer'] > 0
            ? (float)$data['initial_offer']
            : null;

        $hasNegotiation = ($initialOffer !== null);

        // Security check: validate reasonable offer floor (> ₹50)
        if ($hasNegotiation && $initialOffer < 50.00) {
            Response::error('Initial offer must be at least ₹50.00');
        }

        // Selected driver
        $driverId = !empty($data['driver_id']) ? (int)$data['driver_id'] : 3;

        // Revalidate driver availability & verify no ongoing trip conflict exists
        $dCheck = $this->db->prepare("
            SELECT dp.status, dp.is_online,
                   CASE WHEN EXISTS (SELECT 1 FROM trips tr WHERE tr.driver_id = dp.user_id AND tr.status = 'ongoing') THEN 1 ELSE 0 END as is_busy
            FROM driver_profile dp
            WHERE dp.user_id = ?
        ");
        $dCheck->execute([$driverId]);
        $driverState = $dCheck->fetch(PDO::FETCH_ASSOC);

        if (!$driverState || $driverState['status'] !== 'verified') {
            Response::error('The selected driver is not active or verified.', 400);
        }

        if ((int)$driverState['is_busy'] === 1) {
            Response::error('The selected driver is currently engaged in an active trip. Please select another driver or use Smart Auto Match.', 409);
        }

        $startDate     = date('Y-m-d H:i:s');
        $startOtp      = sprintf('%04d', rand(1000, 9999));
        $negStatus     = $hasNegotiation ? 'PENDING' : 'NONE';
        $bookingStatus = $hasNegotiation ? 'pending' : 'confirmed';
        $totalAmount   = $hasNegotiation ? $serverEstimatedFare : $serverEstimatedFare;
        $negotiatedFare= $hasNegotiation ? $initialOffer : null;

        $this->db->beginTransaction();
        try {
            $stmt = $this->db->prepare("
                INSERT INTO bookings
                  (user_id, type, hiring_type, driver_id, start_date,
                   pickup_location, pickup_lat, pickup_lng,
                   destination, dest_lat, dest_lng,
                   distance_km, duration_minutes, estimated_fare,
                   customer_offer, customer_car_model, notes,
                   total_amount, negotiated_fare, negotiation_status,
                   start_otp, payment_status, status, created_at)
                VALUES
                  (?, 'hire_driver', ?, ?, ?,
                   ?, ?, ?,
                   ?, ?, ?,
                   ?, ?, ?,
                   ?, ?, ?,
                   ?, ?, ?,
                   ?, 'unpaid', ?, NOW())
            ");

            $stmt->execute([
                $userId, $hiringType, $driverId, $startDate,
                $pickupLoc, $pickupLat, $pickupLng,
                $destination, $destLat, $destLng,
                $distanceKm, $durationMin, $serverEstimatedFare,
                $initialOffer, $carModel, $notes,
                $totalAmount, $negotiatedFare, $negStatus,
                $startOtp, $bookingStatus
            ]);

            $bookingId = (int)$this->db->lastInsertId();
            $negotiationId = null;

            if ($hasNegotiation) {
                $nStmt = $this->db->prepare("
                    INSERT INTO fare_negotiations 
                      (booking_id, sender_id, sender_role, offered_fare, status, notes, created_at)
                    VALUES 
                      (?, ?, 'customer', ?, 'PENDING', ?, NOW())
                ");
                $nStmt->execute([
                    $bookingId,
                    $userId,
                    $initialOffer,
                    $notes ?: 'Customer proposed initial fare for driver hiring'
                ]);
                $negotiationId = (int)$this->db->lastInsertId();
            }

            $this->db->commit();

            // Trigger Real-Time Driver Booking Push Notification with Sound (Phase 17)
            try {
                $custName = $auth['name'] ?? 'DriveMate Customer';
                $fareToNotify = $hasNegotiation ? $initialOffer : $serverEstimatedFare;

                NotificationController::sendBookingNotification(
                    bookingId: $bookingId,
                    driverId: $driverId,
                    customerName: $custName,
                    pickup: $pickupLoc,
                    destination: $destination,
                    fare: (float)$fareToNotify
                );
            } catch (Exception $e) {
                error_log('[DriverHiring Notification Error] ' . $e->getMessage());
            }

            Response::success([
                'booking_id'          => $bookingId,
                'negotiation_id'      => $negotiationId,
                'type'                => 'hire_driver',
                'hiring_type'         => $hiringType,
                'driver_id'           => $driverId,
                'pickup_location'     => $pickupLoc,
                'destination'         => $destination,
                'distance_km'         => $distanceKm,
                'duration_minutes'    => $durationMin,
                'estimated_fare'      => $serverEstimatedFare,
                'customer_offer'      => $initialOffer,
                'final_agreed_fare'   => $hasNegotiation ? null : $serverEstimatedFare,
                'negotiation_status'  => $negStatus,
                'booking_status'      => $bookingStatus,
                'start_otp'           => $startOtp,
                'currency'            => 'INR',
                'currency_symbol'     => '₹'
            ], 'Driver hiring booking created successfully', 201);

        } catch (Exception $e) {
            $this->db->rollBack();
            Response::error('Failed to create driver hiring booking: ' . $e->getMessage(), 500);
        }
    }

    /**
     * POST /api/driver-hiring/offer
     * Body: { "booking_id": 1, "offered_fare": 480.00, "notes": "..." }
     */
    public function submitOffer(): void {
        $auth = AuthMiddleware::requireAnyRole(['customer', 'driver']);
        $userId   = (int)$auth['sub'];
        $userRole = $auth['role'];
        $data = Response::body();

        $bookingId   = (int)($data['booking_id'] ?? 0);
        $offeredFare = (float)($data['offered_fare'] ?? 0);
        $notes       = trim($data['notes'] ?? '');

        if ($bookingId <= 0 || $offeredFare <= 0) {
            Response::error('Valid booking_id and offered_fare (> 0) required');
        }

        // Fetch booking
        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();

        if (!$booking) {
            Response::error('Booking not found', 404);
        }

        if ($booking['type'] !== 'hire_driver') {
            Response::error('This endpoint is dedicated to driver hiring bookings', 400);
        }

        // Authorization check
        $isCustomer = ($booking['user_id'] == $userId);
        $isDriver   = ($booking['driver_id'] == $userId);

        if (!$isCustomer && !$isDriver && $userRole !== 'admin') {
            if ($userRole === 'driver') $isDriver = true;
            else if ($userRole === 'customer') $isCustomer = true;
            else Response::error('Forbidden: Not authorized on this booking', 403);
        }

        $senderRole = $isCustomer ? 'customer' : 'driver';

        $this->db->beginTransaction();
        try {
            // Expire previous pending offers
            $this->db->prepare("
                UPDATE fare_negotiations 
                SET status = 'EXPIRED' 
                WHERE booking_id = ? AND status = 'PENDING'
            ")->execute([$bookingId]);

            // Insert new offer
            $stmt = $this->db->prepare("
                INSERT INTO fare_negotiations 
                  (booking_id, sender_id, sender_role, offered_fare, status, notes, created_at)
                VALUES 
                  (?, ?, ?, ?, 'PENDING', ?, NOW())
            ");
            $stmt->execute([$bookingId, $userId, $senderRole, $offeredFare, $notes]);
            $negotiationId = (int)$this->db->lastInsertId();

            // Update booking tracking fields
            if ($isCustomer) {
                $this->db->prepare("
                    UPDATE bookings 
                    SET customer_offer = ?, negotiated_fare = ?, negotiation_status = 'PENDING'
                    WHERE id = ?
                ")->execute([$offeredFare, $offeredFare, $bookingId]);
            } else {
                $this->db->prepare("
                    UPDATE bookings 
                    SET driver_counter_offer = ?, negotiated_fare = ?, negotiation_status = 'PENDING'
                    WHERE id = ?
                ")->execute([$offeredFare, $offeredFare, $bookingId]);
            }

            $this->db->commit();

            Response::success([
                'negotiation_id'     => $negotiationId,
                'booking_id'         => $bookingId,
                'offered_fare'       => $offeredFare,
                'sender_role'        => $senderRole,
                'negotiation_status' => 'PENDING',
                'currency'           => 'INR',
                'currency_symbol'    => '₹'
            ], 'Fare offer submitted to counterparty');
        } catch (Exception $e) {
            $this->db->rollBack();
            Response::error('Failed to submit offer: ' . $e->getMessage(), 500);
        }
    }

    /**
     * POST /api/driver-hiring/counter-offer
     * Body: { "booking_id": 1, "counter_fare": 520.00, "notes": "..." }
     */
    public function counterOffer(): void {
        $auth = AuthMiddleware::requireAnyRole(['customer', 'driver']);
        $userId   = (int)$auth['sub'];
        $userRole = $auth['role'];
        $data = Response::body();

        $bookingId   = (int)($data['booking_id'] ?? 0);
        $counterFare = (float)($data['counter_fare'] ?? 0);
        $notes       = trim($data['notes'] ?? '');

        if ($bookingId <= 0 || $counterFare <= 0) {
            Response::error('booking_id and counter_fare (> 0) required');
        }

        // Fetch latest offer
        $stmt = $this->db->prepare("
            SELECT * FROM fare_negotiations 
            WHERE booking_id = ? 
            ORDER BY id DESC LIMIT 1
        ");
        $stmt->execute([$bookingId]);
        $latest = $stmt->fetch();

        if (!$latest || $latest['status'] !== 'PENDING') {
            Response::error('No active pending offer to counter', 400);
        }

        // Two-way rule: Cannot counter your own offer
        if ($userRole !== 'admin' && (int)$latest['sender_id'] === $userId) {
            Response::error('Cannot counter your own offer. Awaiting counterparty response.', 400);
        }

        $senderRole = ($userRole === 'driver') ? 'driver' : 'customer';

        $this->db->beginTransaction();
        try {
            // Mark previous as COUNTER_OFFERED
            $this->db->prepare("
                UPDATE fare_negotiations 
                SET status = 'COUNTER_OFFERED', counter_fare = ?, updated_at = NOW() 
                WHERE id = ?
            ")->execute([$counterFare, $latest['id']]);

            // Insert new pending offer
            $stmt = $this->db->prepare("
                INSERT INTO fare_negotiations 
                  (booking_id, sender_id, sender_role, offered_fare, status, notes, created_at)
                VALUES 
                  (?, ?, ?, ?, 'PENDING', ?, NOW())
            ");
            $stmt->execute([$bookingId, $userId, $senderRole, $counterFare, $notes]);
            $newNegId = (int)$this->db->lastInsertId();

            if ($senderRole === 'driver') {
                $this->db->prepare("
                    UPDATE bookings 
                    SET driver_counter_offer = ?, negotiated_fare = ?, negotiation_status = 'PENDING'
                    WHERE id = ?
                ")->execute([$counterFare, $counterFare, $bookingId]);
            } else {
                $this->db->prepare("
                    UPDATE bookings 
                    SET customer_offer = ?, negotiated_fare = ?, negotiation_status = 'PENDING'
                    WHERE id = ?
                ")->execute([$counterFare, $counterFare, $bookingId]);
            }

            $this->db->commit();

            Response::success([
                'negotiation_id'     => $newNegId,
                'booking_id'         => $bookingId,
                'counter_fare'       => $counterFare,
                'sender_role'        => $senderRole,
                'negotiation_status' => 'PENDING',
                'currency'           => 'INR',
                'currency_symbol'    => '₹'
            ], 'Counter offer submitted successfully');
        } catch (Exception $e) {
            $this->db->rollBack();
            Response::error('Failed to submit counter offer: ' . $e->getMessage(), 500);
        }
    }

    /**
     * POST /api/driver-hiring/accept-offer
     * Body: { "booking_id": 1 }
     */
    public function acceptOffer(): void {
        $auth = AuthMiddleware::requireAnyRole(['customer', 'driver']);
        $userId   = (int)$auth['sub'];
        $userRole = $auth['role'];
        $data = Response::body();

        $bookingId = (int)($data['booking_id'] ?? 0);
        if ($bookingId <= 0) {
            Response::error('booking_id is required');
        }

        $stmt = $this->db->prepare("
            SELECT * FROM fare_negotiations 
            WHERE booking_id = ? 
            ORDER BY id DESC LIMIT 1
        ");
        $stmt->execute([$bookingId]);
        $latest = $stmt->fetch();

        if (!$latest || $latest['status'] !== 'PENDING') {
            Response::error('No pending fare offer found to accept', 400);
        }

        // Two-way rule: You cannot accept your own offer; only the other party can accept
        if ($userRole !== 'admin' && (int)$latest['sender_id'] === $userId) {
            Response::error('Cannot accept your own offer. Awaiting counterparty acceptance.', 400);
        }

        $agreedFare = (float)$latest['offered_fare'];
        $acceptorRole = ($userRole === 'driver') ? 'driver' : 'customer';

        $this->db->beginTransaction();
        try {
            // Update negotiation to ACCEPTED
            $this->db->prepare("
                UPDATE fare_negotiations 
                SET status = 'ACCEPTED', notes = CONCAT(IFNULL(notes,''), ' | Accepted by ', ?), updated_at = NOW() 
                WHERE id = ?
            ")->execute([$acceptorRole, $latest['id']]);

            // Finalize booking mutually agreed fare and confirm booking
            $this->db->prepare("
                UPDATE bookings 
                SET total_amount = ?, negotiated_fare = ?, negotiation_status = 'AGREED', status = 'confirmed' 
                WHERE id = ?
            ")->execute([$agreedFare, $agreedFare, $bookingId]);

            $this->db->commit();

            Response::success([
                'booking_id'         => $bookingId,
                'final_agreed_fare'  => $agreedFare,
                'negotiation_status' => 'AGREED',
                'booking_status'     => 'confirmed',
                'currency'           => 'INR',
                'currency_symbol'    => '₹',
                'message'            => "Mutual fare agreement reached at ₹{$agreedFare}. Booking is confirmed."
            ], 'Fare offer accepted and booking confirmed');
        } catch (Exception $e) {
            $this->db->rollBack();
            Response::error('Failed to accept offer: ' . $e->getMessage(), 500);
        }
    }

    /**
     * GET /api/driver-hiring/negotiation/{booking_id}
     * or GET /api/driver-hiring/negotiation?booking_id=1
     */
    public function getNegotiation(?int $bookingId = null): void {
        $auth = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];

        if ($bookingId === null || $bookingId <= 0) {
            $bookingId = (int)($_GET['booking_id'] ?? 0);
        }

        if ($bookingId <= 0) {
            Response::error('booking_id is required');
        }

        $bStmt = $this->db->prepare("
            SELECT b.*, u.name AS customer_name, u.phone AS customer_phone,
                   d.name AS driver_name, d.phone AS driver_phone
            FROM bookings b
            LEFT JOIN users u ON b.user_id = u.id
            LEFT JOIN users d ON b.driver_id = d.id
            WHERE b.id = ?
        ");
        $bStmt->execute([$bookingId]);
        $booking = $bStmt->fetch();

        if (!$booking) {
            Response::error('Booking not found', 404);
        }

        // History of all negotiation rounds
        $hStmt = $this->db->prepare("
            SELECT n.*, u.name AS sender_name, u.role AS user_role
            FROM fare_negotiations n
            LEFT JOIN users u ON n.sender_id = u.id
            WHERE n.booking_id = ?
            ORDER BY n.created_at ASC
        ");
        $hStmt->execute([$bookingId]);
        $history = $hStmt->fetchAll();

        $latestOffer = !empty($history) ? end($history) : null;
        $canRespond = false;
        if ($latestOffer && $latestOffer['status'] === 'PENDING' && (int)$latestOffer['sender_id'] !== $userId) {
            $canRespond = true;
        }

        Response::success([
            'booking_id'          => $bookingId,
            'hiring_type'         => $booking['hiring_type'] ?? 'one_way',
            'pickup_location'     => $booking['pickup_location'],
            'destination'         => $booking['destination'],
            'distance_km'         => (float)($booking['distance_km'] ?? 0),
            'duration_minutes'    => (int)($booking['duration_minutes'] ?? 0),
            'estimated_fare'      => (float)($booking['estimated_fare'] ?? $booking['total_amount']),
            'final_agreed_fare'   => ($booking['negotiation_status'] === 'AGREED') ? (float)$booking['negotiated_fare'] : null,
            'current_fare'        => (float)($booking['negotiated_fare'] ?: $booking['total_amount']),
            'negotiation_status'  => $booking['negotiation_status'] ?? 'NONE',
            'booking_status'      => $booking['status'],
            'can_respond'         => $canRespond,
            'latest_offer'        => $latestOffer,
            'negotiation_history' => $history,
            'currency'            => 'INR',
            'currency_symbol'     => '₹'
        ], 'Negotiation details retrieved');
    }
}
