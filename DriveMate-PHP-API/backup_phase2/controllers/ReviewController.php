<?php
// controllers/ReviewController.php — Add & get ratings/reviews

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class ReviewController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // POST /reviews/add (Strict Role-Based Rating Permissions)
    public function add(): void {
        $auth     = AuthMiddleware::authenticate();
        $userId   = (int)$auth['sub'];
        $userRole = strtolower($auth['role'] ?? 'customer');
        $data     = Response::body();

        $bookingId = (int)($data['booking_id'] ?? 0);
        $rating    = (int)($data['rating']   ?? 0);
        $comment   = trim($data['comment'] ?? '');

        if (!$bookingId || !$rating) {
            Response::error('booking_id and rating are required', 400);
        }
        if ($rating < 1 || $rating > 5) {
            Response::error('Rating must be between 1 and 5', 400);
        }

        // 1. Fetch booking and trip status from database (Never trust client)
        $stmt = $this->db->prepare("
            SELECT b.*, t.id AS trip_id, t.status AS trip_status, t.driver_id AS trip_driver_id
            FROM bookings b
            LEFT JOIN trips t ON b.id = t.booking_id
            WHERE b.id = ?
        ");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();

        if (!$booking) {
            Response::error('Booking not found', 404);
        }

        // 2. Validate trip status: Must be completed
        $isCompleted = ($booking['status'] === 'completed') || (!empty($booking['trip_status']) && $booking['trip_status'] === 'completed');
        if (!$isCompleted) {
            Response::error('Forbidden: Ratings are only permitted after a trip has been completed', 403);
        }

        // 3. Extract genuine participants from database
        $customerUserId = (int)$booking['user_id'];
        $driverUserId   = (int)($booking['driver_id'] ?: $booking['trip_driver_id']);

        if (!$driverUserId) {
            Response::error('Cannot rate: No assigned driver was recorded for this booking', 400);
        }

        // Explicit check: Driver must NEVER rate themselves
        if (!empty($data['driver_id']) && (int)$data['driver_id'] === $userId) {
            Response::error('Forbidden: Driver is not allowed to rate themselves', 403);
        }

        // 4. Strict Role & Participant Ownership Validation
        $targetDriverId = null;
        if ($userId === $customerUserId) {
            // Case 1: Customer rating assigned driver
            if ($userId === $driverUserId) {
                Response::error('Forbidden: Driver cannot rate themselves', 403);
            }
            $targetDriverId = $driverUserId;
        } elseif ($userId === $driverUserId) {
            // Case 2: Driver rating customer (Driver must NEVER rate themselves)
            if ($userId === $customerUserId) {
                Response::error('Forbidden: Driver must never be allowed to rate themselves', 403);
            }
            // For driver-to-customer ratings, driver_id must be null so it does not inflate driver's own rating
            $targetDriverId = null;
        } else {
            // Unrelated user
            Response::error('Forbidden: You are not a participant in this completed trip', 403);
        }

        // 5. Prevent duplicate ratings: One rating per eligible user per trip
        $checkStmt = $this->db->prepare("SELECT id FROM reviews WHERE booking_id = ? AND user_id = ?");
        $checkStmt->execute([$bookingId, $userId]);
        if ($checkStmt->fetch()) {
            Response::error('Conflict: You have already submitted a rating for this completed trip', 409);
        }

        // 6. Insert review using verified database target (Never trust client driver_id)
        $stmt = $this->db->prepare("
            INSERT INTO reviews (user_id, driver_id, booking_id, rating, comment, created_at)
            VALUES (?, ?, ?, ?, ?, NOW())
        ");
        $stmt->execute([$userId, $targetDriverId, $bookingId, $rating, $comment]);
        $reviewId = (int)$this->db->lastInsertId();

        // 7. If customer rated driver, recalculate & update driver's genuine average rating in MySQL
        $avgRating = 0.0;
        if ($targetDriverId !== null) {
            $this->db->prepare("
                UPDATE driver_profile
                SET avg_rating = (
                    SELECT ROUND(AVG(rating), 2) FROM reviews WHERE driver_id = ? AND user_id != driver_id
                )
                WHERE user_id = ?
            ")->execute([$targetDriverId, $targetDriverId]);

            // Fetch actual updated average rating from MySQL
            $avgStmt = $this->db->prepare("SELECT avg_rating, total_trips FROM driver_profile WHERE user_id = ?");
            $avgStmt->execute([$targetDriverId]);
            $dp = $avgStmt->fetch();
            $avgRating = $dp && $dp['avg_rating'] !== null ? (float)$dp['avg_rating'] : (float)$rating;
        } else {
            // For driver-to-customer rating, fetch driver's existing rating
            $avgStmt = $this->db->prepare("SELECT avg_rating FROM driver_profile WHERE user_id = ?");
            $avgStmt->execute([$driverUserId]);
            $dp = $avgStmt->fetch();
            $avgRating = $dp && $dp['avg_rating'] !== null ? (float)$dp['avg_rating'] : 5.0;
        }

        Response::success([
            'review_id'         => $reviewId,
            'booking_id'        => $bookingId,
            'reviewer_id'       => $userId,
            'target_driver_id'  => $targetDriverId,
            'rating'            => $rating,
            'driver_avg_rating' => $avgRating,
            'comment'           => $comment
        ], 'Rating submitted successfully', 201);
    }

    // GET /reviews/driver?driver_id=X
    public function byDriver(): void {
        AuthMiddleware::authenticate();
        $driverId = (int)($_GET['driver_id'] ?? 0);
        if (!$driverId) Response::error('driver_id required');

        $stmt = $this->db->prepare("
            SELECT r.*, u.name AS reviewer_name, u.avatar AS reviewer_avatar
            FROM reviews r
            JOIN users u ON r.user_id = u.id
            WHERE r.driver_id = ?
            ORDER BY r.created_at DESC
        ");
        $stmt->execute([$driverId]);
        $reviews = $stmt->fetchAll();

        // Fetch actual average rating from MySQL driver_profile
        $dpStmt = $this->db->prepare("SELECT avg_rating, total_trips FROM driver_profile WHERE user_id = ?");
        $dpStmt->execute([$driverId]);
        $profile = $dpStmt->fetch();

        $avg = $profile && $profile['avg_rating'] !== null
            ? (float)$profile['avg_rating']
            : (count($reviews) ? round(array_sum(array_column($reviews, 'rating')) / count($reviews), 2) : 0.0);

        Response::success([
            'average'     => $avg,
            'total_trips' => (int)($profile['total_trips'] ?? 0),
            'reviews'     => $reviews
        ]);
    }

    // GET /reviews/my  (reviews I wrote)
    public function myReviews(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];

        $stmt = $this->db->prepare("
            SELECT r.*, u.name AS driver_name
            FROM reviews r
            LEFT JOIN users u ON r.driver_id = u.id
            WHERE r.user_id = ?
            ORDER BY r.created_at DESC
        ");
        $stmt->execute([$userId]);
        Response::success($stmt->fetchAll());
    }
}
