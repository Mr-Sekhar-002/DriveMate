<?php
// controllers/NegotiationController.php — Two-Way Negotiable Fare Engine (Customer <-> Driver)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class NegotiationController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // POST /negotiation/offer
    // Body: { "booking_id": 1, "offered_fare": 450.00, "notes": "Kakdwip station pickup" }
    public function submitOffer(): void {
        $auth = AuthMiddleware::requireAnyRole(['customer', 'driver']);
        $data = Response::body();

        $bookingId   = (int)($data['booking_id'] ?? 0);
        $offeredFare = (float)($data['offered_fare'] ?? 0);
        $notes       = trim($data['notes'] ?? '');

        if ($bookingId <= 0 || $offeredFare <= 0) {
            Response::error('Valid booking_id and offered_fare (> 0) are required', 400);
        }

        // Fetch booking
        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();

        if (!$booking) {
            Response::error('Booking not found', 404);
        }

        // Server-side fare bounds validation
        $minBaseFare = (float)($this->db->query("SELECT setting_value FROM system_settings WHERE setting_key = 'base_fare'")->fetchColumn() ?: 150.00);
        $floorFare = max(50.00, $minBaseFare * 0.40);
        if ($offeredFare < $floorFare) {
            Response::error("Offered fare cannot be below minimum threshold of ₹" . number_format($floorFare, 2), 400);
        }
        if ($offeredFare > 50000.00) {
            Response::error('Offered fare exceeds maximum allowed platform limit of ₹50,000.00', 400);
        }
        $estFare = (float)($booking['estimated_fare'] ?: $booking['total_amount']);
        if ($estFare > 0 && $offeredFare < ($estFare * 0.40)) {
            Response::error('Offered fare is too low compared to trip estimate. Minimum 40% of estimated fare required.', 400);
        }

        // Verify authorization: Strictly customer who booked, assigned driver, or admin
        $userId   = (int)$auth['sub'];
        $userRole = $auth['role'];
        $isCustomer = ((int)$booking['user_id'] === $userId);
        $isDriver   = (!empty($booking['driver_id']) && (int)$booking['driver_id'] === $userId);

        if (!$isCustomer && !$isDriver && $userRole !== 'admin') {
            Response::error('Forbidden: You are not authorized to negotiate fare on this booking', 403);
        }

        if (in_array($booking['status'], ['completed', 'cancelled'])) {
            Response::error("Cannot negotiate fare on a {$booking['status']} booking", 400);
        }

        $senderRole = $isCustomer ? 'customer' : ($isDriver ? 'driver' : 'admin');

        $this->db->beginTransaction();
        try {
            // Expire any existing pending offers
            $this->db->prepare("
                UPDATE fare_negotiations 
                SET status = 'EXPIRED' 
                WHERE booking_id = ? AND status = 'PENDING'
            ")->execute([$bookingId]);

            // Insert new negotiation offer
            $stmt = $this->db->prepare("
                INSERT INTO fare_negotiations (booking_id, sender_id, sender_role, offered_fare, status, notes, created_at)
                VALUES (?, ?, ?, ?, 'PENDING', ?, NOW())
            ");
            $stmt->execute([$bookingId, $userId, $senderRole, $offeredFare, $notes]);
            $negotiationId = (int)$this->db->lastInsertId();

            // Update booking negotiated fare & status
            if ($senderRole === 'customer') {
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

            // Notify counterparty of new fare offer
            try {
                require_once __DIR__ . '/NotificationController.php';
                $recipientId = ($senderRole === 'customer') ? (int)($booking['driver_id'] ?? 0) : (int)$booking['user_id'];
                if ($recipientId > 0) {
                    NotificationController::notifyFareOffer($recipientId, $bookingId, $senderRole, (float)$offeredFare);
                }
            } catch (Exception $e) {
                error_log('[NegotiationNotification Error] ' . $e->getMessage());
            }

            Response::success([
                'negotiation_id'     => $negotiationId,
                'booking_id'         => $bookingId,
                'offered_fare'       => $offeredFare,
                'currency'           => 'INR',
                'currency_symbol'    => '₹',
                'sender_role'        => $senderRole,
                'negotiation_status' => 'PENDING',
                'message'            => 'Fare offer submitted successfully'
            ], 'Offer submitted', 201);
        } catch (Exception $e) {
            $this->db->rollBack();
            Response::error('Failed to submit offer: ' . $e->getMessage(), 500);
        }
    }

    // POST /negotiation/respond
    // Body: { "booking_id": 1, "action": "accept"|"reject"|"counter", "counter_fare": 500.00, "notes": "..." }
    public function respondOffer(): void {
        $auth = AuthMiddleware::requireAnyRole(['customer', 'driver']);
        $data = Response::body();

        $bookingId   = (int)($data['booking_id'] ?? 0);
        $action      = strtolower(trim($data['action'] ?? ''));
        $counterFare = (float)($data['counter_fare'] ?? 0);
        $notes       = trim($data['notes'] ?? '');

        if ($bookingId <= 0 || !in_array($action, ['accept', 'reject', 'counter'])) {
            Response::error('booking_id and valid action (accept, reject, counter) required');
        }

        // Fetch latest active negotiation for this booking
        $stmt = $this->db->prepare("
            SELECT * FROM fare_negotiations 
            WHERE booking_id = ? 
            ORDER BY id DESC LIMIT 1
        ");
        $stmt->execute([$bookingId]);
        $activeNeg = $stmt->fetch();

        if (!$activeNeg || $activeNeg['status'] !== 'PENDING') {
            Response::error('No pending negotiation offer to respond to', 400);
        }

        // Fetch booking
        $bStmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $bStmt->execute([$bookingId]);
        $booking = $bStmt->fetch();

        $userId   = (int)$auth['sub'];
        $userRole = $auth['role'];
        $isCustomer = ((int)$booking['user_id'] === $userId);
        $isDriver   = (!empty($booking['driver_id']) && (int)$booking['driver_id'] === $userId);

        if (!$isCustomer && !$isDriver && $userRole !== 'admin') {
            Response::error('Forbidden: You are not authorized to respond to negotiations on this booking', 403);
        }

        // Enforce two-way rule: The counterparty must respond, not the sender responding to their own offer
        if ($userRole !== 'admin' && (int)$activeNeg['sender_id'] === $userId) {
            Response::error('Cannot respond to your own offer. Awaiting response from other party.', 400);
        }

        $responderRole = $isCustomer ? 'customer' : ($isDriver ? 'driver' : 'admin');

        $this->db->beginTransaction();
        try {
            if ($action === 'accept') {
                $agreedFare = (float)$activeNeg['offered_fare'];

                // Mark negotiation accepted
                $this->db->prepare("
                    UPDATE fare_negotiations 
                    SET status = 'ACCEPTED', notes = CONCAT(IFNULL(notes,''), ' | Accepted by ', ?), updated_at = NOW() 
                    WHERE id = ?
                ")->execute([$responderRole, $activeNeg['id']]);

                // Update booking total_amount, negotiated_fare, negotiation_status, and confirm booking
                if ($isDriver && empty($booking['driver_id'])) {
                    $this->db->prepare("
                        UPDATE bookings 
                        SET total_amount = ?, negotiated_fare = ?, negotiation_status = 'AGREED', status = 'confirmed', driver_id = ? 
                        WHERE id = ?
                    ")->execute([$agreedFare, $agreedFare, $userId, $bookingId]);
                } else {
                    $this->db->prepare("
                        UPDATE bookings 
                        SET total_amount = ?, negotiated_fare = ?, negotiation_status = 'AGREED', status = 'confirmed' 
                        WHERE id = ?
                    ")->execute([$agreedFare, $agreedFare, $bookingId]);
                }

                $this->db->commit();

                // Notify parties that booking is confirmed at agreed fare
                try {
                    require_once __DIR__ . '/NotificationController.php';
                    NotificationController::notifyBookingConfirmed((int)$booking['user_id'], $bookingId, $agreedFare);
                    if (!empty($booking['driver_id'])) {
                        NotificationController::notifyBookingConfirmed((int)$booking['driver_id'], $bookingId, $agreedFare);
                    }
                } catch (Exception $e) {
                    error_log('[NegotiationNotification Error] ' . $e->getMessage());
                }

                Response::success([
                    'booking_id'         => $bookingId,
                    'agreed_fare'        => $agreedFare,
                    'currency'           => 'INR',
                    'currency_symbol'    => '₹',
                    'negotiation_status' => 'AGREED',
                    'booking_status'     => 'confirmed'
                ], 'Fare offer accepted and booking confirmed at agreed fare');
                return;
            }

            if ($action === 'counter') {
                if ($counterFare <= 0) {
                    $this->db->rollBack();
                    Response::error('Counter fare must be greater than 0', 400);
                }

                // Server-side counter fare bounds validation
                $minBaseFare = (float)($this->db->query("SELECT setting_value FROM system_settings WHERE setting_key = 'base_fare'")->fetchColumn() ?: 150.00);
                $floorFare = max(50.00, $minBaseFare * 0.40);
                if ($counterFare < $floorFare) {
                    $this->db->rollBack();
                    Response::error("Counter fare cannot be below minimum threshold of ₹" . number_format($floorFare, 2), 400);
                }
                if ($counterFare > 50000.00) {
                    $this->db->rollBack();
                    Response::error('Counter fare exceeds maximum allowed platform limit of ₹50,000.00', 400);
                }
                $estFare = (float)($booking['estimated_fare'] ?: $booking['total_amount']);
                if ($estFare > 0 && $counterFare < ($estFare * 0.40)) {
                    $this->db->rollBack();
                    Response::error('Counter fare is too low compared to trip estimate. Minimum 40% of estimated fare required.', 400);
                }

                // Update previous offer as counter-offered
                $this->db->prepare("
                    UPDATE fare_negotiations 
                    SET status = 'COUNTER_OFFERED', counter_fare = ?, updated_at = NOW() 
                    WHERE id = ?
                ")->execute([$counterFare, $activeNeg['id']]);

                // Insert new offer from current responder
                $this->db->prepare("
                    INSERT INTO fare_negotiations (booking_id, sender_id, sender_role, offered_fare, status, notes, created_at)
                    VALUES (?, ?, ?, ?, 'PENDING', ?, NOW())
                ")->execute([$bookingId, $userId, $responderRole, $counterFare, $notes]);
                $newNegId = (int)$this->db->lastInsertId();

                // Update booking
                if ($responderRole === 'driver') {
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

                // Notify counterparty of counter offer
                try {
                    require_once __DIR__ . '/NotificationController.php';
                    $recipientId = ($responderRole === 'driver') ? (int)$booking['user_id'] : (int)($booking['driver_id'] ?? 0);
                    if ($recipientId > 0) {
                        NotificationController::notifyFareOffer($recipientId, $bookingId, $responderRole, (float)$counterFare);
                    }
                } catch (Exception $e) {
                    error_log('[NegotiationNotification Error] ' . $e->getMessage());
                }

                Response::success([
                    'negotiation_id'     => $newNegId,
                    'booking_id'         => $bookingId,
                    'counter_fare'       => $counterFare,
                    'currency'           => 'INR',
                    'currency_symbol'    => '₹',
                    'sender_role'        => $responderRole,
                    'negotiation_status' => 'PENDING'
                ], 'Counter offer submitted successfully');
                return;
            }

            if ($action === 'reject') {
                $this->db->prepare("
                    UPDATE fare_negotiations 
                    SET status = 'REJECTED', notes = CONCAT(IFNULL(notes,''), ' | Rejected by ', ?), updated_at = NOW() 
                    WHERE id = ?
                ")->execute([$responderRole, $activeNeg['id']]);

                $this->db->prepare("
                    UPDATE bookings 
                    SET negotiation_status = 'REJECTED' 
                    WHERE id = ?
                ")->execute([$bookingId]);

                $this->db->commit();

                // Notify counterparty of rejection
                try {
                    require_once __DIR__ . '/NotificationController.php';
                    $recipientId = ($responderRole === 'driver') ? (int)$booking['user_id'] : (int)($booking['driver_id'] ?? 0);
                    if ($recipientId > 0) {
                        NotificationController::sendPushToUser($recipientId, 'Fare Offer Declined', "The proposed fare offer for Booking #{$bookingId} was declined.", ['booking_id' => (string)$bookingId], $bookingId, 'fare_offer_rejected');
                    }
                } catch (Exception $e) {
                    error_log('[NegotiationNotification Error] ' . $e->getMessage());
                }

                Response::success([
                    'booking_id'         => $bookingId,
                    'negotiation_status' => 'REJECTED'
                ], 'Fare offer rejected');
                return;
            }
        } catch (Exception $e) {
            $this->db->rollBack();
            Response::error('Failed to process response: ' . $e->getMessage(), 500);
        }
    }

    // GET /negotiation/history?booking_id=1
    public function getHistory(): void {
        $auth      = AuthMiddleware::authenticate();
        $bookingId = (int)($_GET['booking_id'] ?? 0);

        if ($bookingId <= 0) Response::error('booking_id required');

        // Check permissions
        $bStmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $bStmt->execute([$bookingId]);
        $booking = $bStmt->fetch();

        if (!$booking) Response::error('Booking not found', 404);

        $userId = (int)$auth['sub'];
        $role   = $auth['role'];
        if ((int)$booking['user_id'] !== $userId && (int)($booking['driver_id'] ?? 0) !== $userId && $role !== 'admin') {
            Response::error('Forbidden: Not authorized to view this negotiation history', 403);
        }

        $stmt = $this->db->prepare("
            SELECT n.*, u.name AS sender_name, u.phone AS sender_phone
            FROM fare_negotiations n
            JOIN users u ON n.sender_id = u.id
            WHERE n.booking_id = ?
            ORDER BY n.created_at ASC
        ");
        $stmt->execute([$bookingId]);
        $rounds = $stmt->fetchAll();

        Response::success([
            'booking_id'         => $bookingId,
            'initial_amount'     => (float)$booking['total_amount'],
            'negotiated_fare'    => (float)($booking['negotiated_fare'] ?? $booking['total_amount']),
            'negotiation_status' => $booking['negotiation_status'] ?? 'NONE',
            'currency'           => 'INR',
            'currency_symbol'    => '₹',
            'history'            => $rounds
        ], 'Negotiation history retrieved');
    }

    // GET /negotiation/status?booking_id=1
    public function getStatus(): void {
        $auth      = AuthMiddleware::authenticate();
        $bookingId = (int)($_GET['booking_id'] ?? 0);

        if ($bookingId <= 0) Response::error('booking_id required');

        $bStmt = $this->db->prepare("
            SELECT b.*, u.name AS customer_name, d.name AS driver_name
            FROM bookings b
            LEFT JOIN users u ON b.user_id = u.id
            LEFT JOIN users d ON b.driver_id = d.id
            WHERE b.id = ?
        ");
        $bStmt->execute([$bookingId]);
        $booking = $bStmt->fetch();

        if (!$booking) Response::error('Booking not found', 404);

        $userId = (int)$auth['sub'];
        $role   = $auth['role'];
        if ((int)$booking['user_id'] !== $userId && (int)($booking['driver_id'] ?? 0) !== $userId && $role !== 'admin') {
            Response::error('Forbidden: Not authorized on this booking', 403);
        }

        $stmt = $this->db->prepare("
            SELECT * FROM fare_negotiations 
            WHERE booking_id = ? 
            ORDER BY id DESC LIMIT 1
        ");
        $stmt->execute([$bookingId]);
        $latest = $stmt->fetch();

        $userId = (int)$auth['sub'];
        $canRespond = false;
        if ($latest && $latest['status'] === 'PENDING' && (int)$latest['sender_id'] !== $userId) {
            $canRespond = true;
        }

        Response::success([
            'booking_id'         => $bookingId,
            'current_fare'       => (float)($booking['negotiated_fare'] ?: $booking['total_amount']),
            'negotiation_status' => $booking['negotiation_status'] ?: 'NONE',
            'currency'           => 'INR',
            'currency_symbol'    => '₹',
            'can_respond'        => $canRespond,
            'latest_offer'       => $latest ?: null
        ]);
    }
}
