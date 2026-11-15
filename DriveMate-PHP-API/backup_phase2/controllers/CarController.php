<?php
// controllers/CarController.php — Car listings, search & management

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class CarController {
    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // GET /cars/available (Public / Auth) — search cars for rent
    public function availableCars(): void {
        $type = $_GET['type'] ?? null; // self_drive | rent_with_driver | both

        $sql = "
            SELECT cl.*, v.model, v.type AS vehicle_type, v.number_plate, v.color, v.capacity, u.name AS owner_name, u.phone AS owner_phone
            FROM car_listings cl
            JOIN vehicles v ON cl.vehicle_id = v.id
            JOIN users u ON cl.owner_id = u.id
            WHERE cl.status = 'active'
        ";
        $params = [];

        if ($type) {
            $sql .= " AND (cl.type = ? OR cl.type = 'both')";
            $params[] = $type;
        }

        $sql .= " ORDER BY cl.created_at DESC";
        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);

        Response::success($stmt->fetchAll());
    }

    // POST /cars/add (Car Owner only)
    public function addCar(): void {
        $auth = AuthMiddleware::requireRole('owner');
        $data = Response::body();

        $type        = trim($data['vehicle_type'] ?? 'Sedan'); // Sedan, SUV, etc.
        $model       = trim($data['model'] ?? '');
        $plate       = trim($data['number_plate'] ?? '');
        $color       = trim($data['color'] ?? '');
        $capacity    = (int)($data['capacity'] ?? 4);
        $listingType = $data['listing_type'] ?? 'self_drive'; // self_drive | rent_with_driver | both
        $dailyRate   = (float)($data['daily_rate'] ?? 0);
        $hourlyRate  = (float)($data['hourly_rate'] ?? 0);
        $description = trim($data['description'] ?? '');

        if (!$model || !$plate || $dailyRate <= 0) {
            Response::error('Model, number plate, and valid daily rate are required');
        }

        // Insert Vehicle
        $stmt = $this->db->prepare("
            INSERT INTO vehicles (owner_id, type, model, number_plate, color, capacity, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, 'active', NOW())
        ");
        $stmt->execute([$auth['sub'], $type, $model, $plate, $color, $capacity]);
        $vehicleId = $this->db->lastInsertId();

        // Insert Car Listing
        $stmtListing = $this->db->prepare("
            INSERT INTO car_listings (owner_id, vehicle_id, type, daily_rate, hourly_rate, description, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, 'active', NOW())
        ");
        $stmtListing->execute([$auth['sub'], $vehicleId, $listingType, $dailyRate, $hourlyRate, $description]);
        $listingId = $this->db->lastInsertId();

        Response::success(['listing_id' => $listingId, 'vehicle_id' => $vehicleId], 'Car listed successfully', 201);
    }

    // GET /cars/my (Car Owner only)
    public function myCars(): void {
        $auth = AuthMiddleware::requireRole('owner');

        $stmt = $this->db->prepare("
            SELECT cl.*, v.model, v.type AS vehicle_type, v.number_plate, v.color, v.capacity
            FROM car_listings cl
            JOIN vehicles v ON cl.vehicle_id = v.id
            WHERE cl.owner_id = ?
            ORDER BY cl.created_at DESC
        ");
        $stmt->execute([$auth['sub']]);
        Response::success($stmt->fetchAll());
    }

    // GET /cars/requests (Car Owner only) — View rental requests for my vehicles
    public function rentalRequests(): void {
        $auth = AuthMiddleware::requireRole('owner');

        $stmt = $this->db->prepare("
            SELECT b.*, u.name AS customer_name, u.phone AS customer_phone, u.avatar AS customer_avatar,
                   v.model, v.number_plate, cl.daily_rate
            FROM bookings b
            JOIN car_listings cl ON b.car_listing_id = cl.id
            JOIN vehicles v ON cl.vehicle_id = v.id
            JOIN users u ON b.user_id = u.id
            WHERE cl.owner_id = ?
            ORDER BY b.created_at DESC
        ");
        $stmt->execute([$auth['sub']]);
        Response::success($stmt->fetchAll());
    }

    // PUT /cars/requests/respond (Car Owner only) — Accept or reject booking
    public function respondRequest(): void {
        $auth = AuthMiddleware::requireRole('owner');
        $data = Response::body();

        $bookingId = (int)($data['booking_id'] ?? 0);
        $decision  = $data['decision'] ?? 'accept'; // accept | reject

        if (!$bookingId) {
            Response::error('booking_id is required');
        }

        // Verify this booking belongs to owner's car listing
        $stmtCheck = $this->db->prepare("
            SELECT b.id FROM bookings b
            JOIN car_listings cl ON b.car_listing_id = cl.id
            WHERE b.id = ? AND cl.owner_id = ?
        ");
        $stmtCheck->execute([$bookingId, $auth['sub']]);
        if (!$stmtCheck->fetch()) {
            Response::error('Booking request not found for your vehicles', 404);
        }

        $newStatus = ($decision === 'accept') ? 'confirmed' : 'cancelled';
        $this->db->prepare("UPDATE bookings SET status = ? WHERE id = ?")->execute([$newStatus, $bookingId]);

        Response::success([], "Rental request has been {$newStatus}");
    }

    // GET /cars/earnings (Car Owner only) — Owner fleet revenue
    public function getEarnings(): void {
        $auth    = AuthMiddleware::requireRole('owner');
        $ownerId = $auth['sub'];

        $stmt = $this->db->prepare("
            SELECT 
                COUNT(b.id) as total_rentals,
                COALESCE(SUM(b.total_amount), 0) as gross_revenue,
                ROUND(COALESCE(SUM(b.total_amount), 0) * 0.85, 2) as net_payout
            FROM bookings b
            JOIN car_listings cl ON b.car_listing_id = cl.id
            WHERE cl.owner_id = ? AND b.status = 'completed'
        ");
        $stmt->execute([$ownerId]);
        $stats = $stmt->fetch();

        // Breakdown by vehicle
        $stmtFleet = $this->db->prepare("
            SELECT v.id, v.model, v.number_plate,
                   COUNT(b.id) as total_trips,
                   COALESCE(SUM(b.total_amount), 0) as vehicle_revenue
            FROM vehicles v
            LEFT JOIN car_listings cl ON cl.vehicle_id = v.id
            LEFT JOIN bookings b ON b.car_listing_id = cl.id AND b.status = 'completed'
            WHERE v.owner_id = ?
            GROUP BY v.id, v.model, v.number_plate
        ");
        $stmtFleet->execute([$ownerId]);

        Response::success([
            'total_rentals' => (int)($stats['total_rentals'] ?? 0),
            'gross_revenue' => (float)($stats['gross_revenue'] ?? 0),
            'net_payout'    => (float)($stats['net_payout'] ?? 0),
            'fleet_summary' => $stmtFleet->fetchAll(),
            'currency'      => 'INR'
        ]);
    }
}
