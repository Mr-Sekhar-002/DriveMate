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
            Response::error('Valid booking_id and offered_fare (> 0) are required');
        }

        // Fetch booking
        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();

        if (!$booking) {
            Response::error('Booking not found', 404);
        }

        // Verify authorization: Must be the customer who booked, or the assigned driver
        $userId   = (int)$auth['sub'];
        $userRole = $auth['role'];
        $isCustomer = ($booking['user_id'] == $userId);
        $isDriver   = ($booking['driver_id'] == $userId);

        if (!$isCustomer && !$isDriver && $userRole !== 'admin') {
            if ($userRole === 'driver') {
                $isDriver = true;
            } else if ($userRole === 'customer') {
                $isCustomer = true;
            } else {
                Response::error('Forbidden: You are not authorized to negotiate fare on this booking', 403);
            }
        }

        if (in_array($booking['status'], ['completed', 'cancelled'])) {
            Response::error("Cannot negotiate fare on a {$booking['status']} booking", 400);
        }

        $senderRole = $isCustomer ? 'customer' : 'driver';

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
            $this->db->prepare("
                UPDATE bookings 
                SET negotiated_fare = ?, negotiation_status = 'PENDING' 
                WHERE id = ?
            ")->execute([$offeredFare, $bookingId]);

            $this->db->commit();

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
        $isCustomer = ($booking['user_id'] == $userId);
        $isDriver   = ($booking['driver_id'] == $userId);

        if (!$isCustomer && !$isDriver && $userRole !== 'admin') {
            if ($userRole === 'driver') {
                $isDriver = true;
            } else if ($userRole === 'customer') {
                $isCustomer = true;
            } else {
                Response::error('Forbidden: Not authorized on this booking', 403);
            }
        }

        // Enforce two-way rule: The counterparty must respond, not the sender responding to their own offer
        if ($userRole !== 'admin' && (int)$activeNeg['sender_id'] === $userId && $activeNeg['sender_role'] === $userRole) {
            Response::error('Cannot respond to your own offer. Awaiting response from other party.', 400);
        }

        $responderRole = $isCustomer ? 'customer' : 'driver';

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
                $this->db->prepare("
                    UPDATE bookings 
                    SET total_amount = ?, negotiated_fare = ?, negotiation_status = 'AGREED', status = 'confirmed' 
                    WHERE id = ?
                ")->execute([$agreedFare, $agreedFare, $bookingId]);

                $this->db->commit();
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
                    Response::error('Counter fare must be greater than 0');
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
                $this->db->prepare("
                    UPDATE bookings 
                    SET negotiated_fare = ?, negotiation_status = 'PENDING' 
                    WHERE id = ?
                ")->execute([$counterFare, $bookingId]);

                $this->db->commit();
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
        if ($booking['user_id'] != $userId && $booking['driver_id'] != $userId && $auth['role'] !== 'admin') {
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
