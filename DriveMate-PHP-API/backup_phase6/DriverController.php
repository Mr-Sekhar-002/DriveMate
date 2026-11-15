<?php
// controllers/DriverController.php — Driver profile, verification & status

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class DriverController {
    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // GET /drivers/available (Public / Auth) — Find available drivers
    public function availableDrivers(): void {
        $stmt = $this->db->prepare("
            SELECT u.id, u.name, u.phone, u.avatar, dp.license_number, dp.vehicle_type, dp.vehicle_model, dp.avg_rating, dp.status
            FROM driver_profile dp
            JOIN users u ON dp.user_id = u.id
            WHERE dp.status = 'verified' AND u.status = 'active'
        ");
        $stmt->execute();
        Response::success($stmt->fetchAll());
    }

    // POST /drivers/profile (Driver only) — Create or update driver profile
    public function updateProfile(): void {
        $auth = AuthMiddleware::requireRole('driver');
        $data = Response::body();

        $license = trim($data['license_number'] ?? '');
        $vType   = trim($data['vehicle_type'] ?? '');
        $vModel  = trim($data['vehicle_model'] ?? '');
        $vNumber = trim($data['vehicle_number'] ?? '');

        if (!$license) {
            Response::error('Driving License number is required');
        }

        $stmt = $this->db->prepare("
            INSERT INTO driver_profile (user_id, license_number, vehicle_type, vehicle_model, vehicle_number, status, created_at)
            VALUES (?, ?, ?, ?, ?, 'pending', NOW())
            ON DUPLICATE KEY UPDATE 
                license_number = VALUES(license_number),
                vehicle_type   = VALUES(vehicle_type),
                vehicle_model  = VALUES(vehicle_model),
                vehicle_number = VALUES(vehicle_number)
        ");
        $stmt->execute([$auth['sub'], $license, $vType, $vModel, $vNumber]);

        Response::success([], 'Driver profile updated and submitted for verification');
    }

    // GET /drivers/profile (Driver only) — Get driver profile & status
    public function getProfile(): void {
        $auth = AuthMiddleware::requireRole('driver');

        $stmt = $this->db->prepare("
            SELECT dp.*, u.name, u.email, u.phone, u.avatar
            FROM driver_profile dp
            JOIN users u ON dp.user_id = u.id
            WHERE dp.user_id = ?
        ");
        $stmt->execute([$auth['sub']]);
        $driver = $stmt->fetch();

        if (!$driver) {
            Response::error('Driver profile not created yet', 404);
        }

        Response::success($driver);
    }

    // POST /drivers/toggle-online (Driver only)
    public function toggleOnline(): void {
        $auth = AuthMiddleware::requireRole('driver');
        $data = Response::body();
        $lat  = $data['latitude'] ?? null;
        $lng  = $data['longitude'] ?? null;

        if (isset($data['is_online'])) {
            $online = (int)$data['is_online'];
        } else {
            // Auto toggle: flip current status
            $chk = $this->db->prepare("SELECT is_online FROM driver_profile WHERE user_id = ?");
            $chk->execute([$auth['sub']]);
            $current = $chk->fetchColumn();
            $online = ($current == 1) ? 0 : 1;
        }

        $stmt = $this->db->prepare("
            UPDATE driver_profile 
            SET is_online = ?, current_lat = ?, current_lng = ?, last_active_at = NOW() 
            WHERE user_id = ?
        ");
        $stmt->execute([$online, $lat, $lng, $auth['sub']]);

        Response::success([
            'is_online' => (bool)$online,
            'status_label' => $online ? 'ONLINE' : 'OFFLINE',
            'latitude'  => $lat,
            'longitude' => $lng
        ], $online ? 'Driver is now ONLINE (Duty ON - Ready to accept trips)' : 'Driver is now OFFLINE (Duty OFF)');
    }

    // GET /drivers/nearby?lat=19.0760&lng=72.8777&radius=15
    public function nearbyDrivers(): void {
        AuthMiddleware::authenticate();
        $lat    = (float)($_GET['lat'] ?? 19.0760);
        $lng    = (float)($_GET['lng'] ?? 72.8777);
        $radius = (float)($_GET['radius'] ?? 15); // in km

        // Haversine formula query
        $sql = "
            SELECT u.id, u.name, u.phone, u.avatar, dp.vehicle_type, dp.vehicle_model, dp.vehicle_number, dp.avg_rating,
                   dp.current_lat, dp.current_lng,
                   (6371 * acos(cos(radians(?)) * cos(radians(dp.current_lat)) * cos(radians(dp.current_lng) - radians(?)) + sin(radians(?)) * sin(radians(dp.current_lat)))) AS distance_km
            FROM driver_profile dp
            JOIN users u ON dp.user_id = u.id
            WHERE dp.status = 'verified' AND dp.is_online = 1 AND u.status = 'active'
              AND dp.current_lat IS NOT NULL AND dp.current_lng IS NOT NULL
            HAVING distance_km <= ?
            ORDER BY distance_km ASC
            LIMIT 20
        ";
        $stmt = $this->db->prepare($sql);
        $stmt->execute([$lat, $lng, $lat, $radius]);

        Response::success($stmt->fetchAll());
    }

    // GET /drivers/earnings (Driver only) — Earnings dashboard
    public function getEarnings(): void {
        $auth     = AuthMiddleware::requireRole('driver');
        $driverId = $auth['sub'];

        // Total Completed Trips
        $stmtTrips = $this->db->prepare("
            SELECT COUNT(*) FROM trips WHERE driver_id = ? AND status = 'completed'
        ");
        $stmtTrips->execute([$driverId]);
        $completedTrips = (int)$stmtTrips->fetchColumn();

        // Total Lifetime Earnings
        $stmtTotal = $this->db->prepare("
            SELECT COALESCE(SUM(fare), 0) FROM trips WHERE driver_id = ? AND status = 'completed'
        ");
        $stmtTotal->execute([$driverId]);
        $lifetimeGross = (float)$stmtTotal->fetchColumn();

        // Today Earnings
        $stmtToday = $this->db->prepare("
            SELECT COALESCE(SUM(fare), 0) FROM trips 
            WHERE driver_id = ? AND status = 'completed' AND DATE(end_time) = CURDATE()
        ");
        $stmtToday->execute([$driverId]);
        $todayGross = (float)$stmtToday->fetchColumn();

        // Platform Commission deduction (e.g. 15%)
        $commPercent = 15;
        $driverNetTotal = round($lifetimeGross * ((100 - $commPercent) / 100), 2);
        $driverNetToday = round($todayGross * ((100 - $commPercent) / 100), 2);

        // Recent 5 completed trips
        $stmtRecent = $this->db->prepare("
            SELECT t.id, t.start_location, t.end_location, t.distance_km, t.fare, t.start_time, t.end_time,
                   round(t.fare * 0.85, 2) as net_payout
            FROM trips t
            WHERE t.driver_id = ? AND t.status = 'completed'
            ORDER BY t.end_time DESC LIMIT 5
        ");
        $stmtRecent->execute([$driverId]);

        Response::success([
            'completed_trips' => $completedTrips,
            'today_gross'     => $todayGross,
            'today_net'       => $driverNetToday,
            'lifetime_gross'  => $lifetimeGross,
            'lifetime_net'    => $driverNetTotal,
            'commission_rate' => "$commPercent%",
            'recent_trips'    => $stmtRecent->fetchAll(),
            'currency'        => 'INR'
        ]);
    }

    /**
     * GET /drivers/eligible
     * Customer Driver Selection with filters and real sorting
     */
    public function eligibleDrivers(): void {
        AuthMiddleware::authenticate();

        $lat        = isset($_GET['lat']) && is_numeric($_GET['lat']) ? (float)$_GET['lat'] : null;
        $lng        = isset($_GET['lng']) && is_numeric($_GET['lng']) ? (float)$_GET['lng'] : null;
        $sort       = trim($_GET['sort'] ?? 'top_rated');
        $search     = trim($_GET['search'] ?? '');
        $hiringType = trim($_GET['hiring_type'] ?? 'one_way');
        $roadDistKm = max(1.0, (float)($_GET['distance_km'] ?? 10.0));

        $sql = "
            SELECT u.id, u.name, u.avatar,
                   dp.license_number, dp.vehicle_type, dp.vehicle_model, dp.vehicle_number,
                   dp.avg_rating, dp.total_trips, dp.experience_years, dp.hourly_rate,
                   dp.is_online, dp.status, dp.current_lat, dp.current_lng,
                   CASE 
                     WHEN EXISTS (SELECT 1 FROM trips tr WHERE tr.driver_id = u.id AND tr.status = 'ongoing') THEN 1 
                     WHEN EXISTS (SELECT 1 FROM bookings b WHERE b.driver_id = u.id AND b.status IN ('confirmed', 'arrived', 'ongoing')) THEN 1
                     ELSE 0 
                   END AS is_busy
            FROM driver_profile dp
            JOIN users u ON dp.user_id = u.id
            WHERE dp.status = 'verified' AND u.status = 'active'
        ";

        $params = [];
        if (!empty($search)) {
            $sql .= " AND (u.name LIKE ? OR dp.vehicle_model LIKE ? OR dp.vehicle_type LIKE ?)";
            $term = "%$search%";
            $params[] = $term;
            $params[] = $term;
            $params[] = $term;
        }

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        $rawDrivers = $stmt->fetchAll(PDO::FETCH_ASSOC);

        $results = [];
        foreach ($rawDrivers as $d) {
            $driverLat = isset($d['current_lat']) && is_numeric($d['current_lat']) ? (float)$d['current_lat'] : null;
            $driverLng = isset($d['current_lng']) && is_numeric($d['current_lng']) ? (float)$d['current_lng'] : null;

            $distanceKm = null;
            $etaMinutes = null;

            if ($lat !== null && $lng !== null && $driverLat !== null && $driverLng !== null) {
                $dLat = deg2rad($driverLat - $lat);
                $dLng = deg2rad($driverLng - $lng);
                $a = sin($dLat/2) * sin($dLat/2) +
                     cos(deg2rad($lat)) * cos(deg2rad($driverLat)) *
                     sin($dLng/2) * sin($dLng/2);
                $c = 2 * atan2(sqrt($a), sqrt(1-$a));
                $distanceKm = round(6371 * $c, 2);
                $etaMinutes = max(2, (int)round(($distanceKm / 25) * 60));
            }

            $driverHourly = (float)($d['hourly_rate'] ?: 150.00);
            $baseFare = 150.00;
            $kmRate = 14.00;
            $estFare = round($baseFare + ($roadDistKm * $kmRate), 2);
            if ($hiringType === 'hourly') {
                $estFare = round(100.00 + (4 * $driverHourly), 2);
            }

            $isAvailable = ((int)$d['is_online'] === 1 && (int)$d['is_busy'] === 0);

            $results[] = [
                'id'                 => (int)$d['id'],
                'driver_name'        => $d['name'],
                'avatar'             => $d['avatar'] ?? null,
                'license_number'     => $d['license_number'] ?? null,
                'vehicle_type'       => $d['vehicle_type'] ?? 'Sedan',
                'vehicle_model'      => $d['vehicle_model'] ?? 'Standard Car',
                'vehicle_number'     => $d['vehicle_number'] ?? null,
                'avg_rating'         => $d['avg_rating'] !== null ? (float)$d['avg_rating'] : null,
                'total_trips'        => (int)($d['total_trips'] ?? 0),
                'experience_years'   => $d['experience_years'] !== null ? (int)$d['experience_years'] : null,
                'hourly_rate'        => $driverHourly,
                'estimated_fare'     => $estFare,
                'is_online'          => (bool)$d['is_online'],
                'is_busy'            => (bool)$d['is_busy'],
                'is_available'       => $isAvailable,
                'verification_status'=> $d['status'],
                'current_lat'        => $driverLat,
                'current_lng'        => $driverLng,
                'distance_km'        => $distanceKm,
                'eta_minutes'        => $etaMinutes,
            ];
        }

        if ($sort === 'available_now') {
            $results = array_values(array_filter($results, fn($r) => $r['is_available']));
        }

        usort($results, function($a, $b) use ($sort) {
            switch ($sort) {
                case 'nearest':
                    $dA = $a['distance_km'] ?? 999999;
                    $dB = $b['distance_km'] ?? 999999;
                    return $dA <=> $dB;
                case 'available_now':
                    if ($a['is_available'] !== $b['is_available']) {
                        return $b['is_available'] ? 1 : -1;
                    }
                    $dA = $a['distance_km'] ?? 999999;
                    $dB = $b['distance_km'] ?? 999999;
                    return $dA <=> $dB;
                case 'experience':
                    $eA = $a['experience_years'] ?? 0;
                    $eB = $b['experience_years'] ?? 0;
                    return $eB <=> $eA;
                case 'fare':
                    return ($a['estimated_fare'] ?? 0) <=> ($b['estimated_fare'] ?? 0);
                case 'top_rated':
                default:
                    $rA = $a['avg_rating'] ?? 0.0;
                    $rB = $b['avg_rating'] ?? 0.0;
                    if ($rA != $rB) return $rB <=> $rA;
                    return $b['total_trips'] <=> $a['total_trips'];
            }
        });

        Response::success($results);
    }

    /**
     * GET /drivers/profile-detail?driver_id=X&lat=...&lng=...
     * Detailed driver profile with reviews and security phone masking
     */
    public function profileDetail(): void {
        AuthMiddleware::authenticate();

        $driverId = (int)($_GET['driver_id'] ?? 0);
        if ($driverId <= 0) {
            Response::error('Valid driver_id is required', 400);
        }

        $lat = isset($_GET['lat']) && is_numeric($_GET['lat']) ? (float)$_GET['lat'] : null;
        $lng = isset($_GET['lng']) && is_numeric($_GET['lng']) ? (float)$_GET['lng'] : null;

        $stmt = $this->db->prepare("
            SELECT u.id, u.name, u.avatar,
                   dp.license_number, dp.vehicle_type, dp.vehicle_model, dp.vehicle_number,
                   dp.avg_rating, dp.total_trips, dp.experience_years, dp.hourly_rate,
                   dp.is_online, dp.status, dp.current_lat, dp.current_lng,
                   CASE 
                     WHEN EXISTS (SELECT 1 FROM trips tr WHERE tr.driver_id = u.id AND tr.status = 'ongoing') THEN 1 
                     WHEN EXISTS (SELECT 1 FROM bookings b WHERE b.driver_id = u.id AND b.status IN ('confirmed', 'arrived', 'ongoing')) THEN 1
                     ELSE 0 
                   END AS is_busy
            FROM driver_profile dp
            JOIN users u ON dp.user_id = u.id
            WHERE u.id = ? AND dp.status = 'verified' AND u.status = 'active'
            LIMIT 1
        ");
        $stmt->execute([$driverId]);
        $driver = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$driver) {
            Response::error('Driver profile not found or driver is not active/verified', 404);
        }

        $distanceKm = null;
        $etaMinutes = null;
        $driverLat = isset($driver['current_lat']) && is_numeric($driver['current_lat']) ? (float)$driver['current_lat'] : null;
        $driverLng = isset($driver['current_lng']) && is_numeric($driver['current_lng']) ? (float)$driver['current_lng'] : null;

        if ($lat !== null && $lng !== null && $driverLat !== null && $driverLng !== null) {
            $dLat = deg2rad($driverLat - $lat);
            $dLng = deg2rad($driverLng - $lng);
            $a = sin($dLat/2) * sin($dLat/2) +
                 cos(deg2rad($lat)) * cos(deg2rad($driverLat)) *
                 sin($dLng/2) * sin($dLng/2);
            $c = 2 * atan2(sqrt($a), sqrt(1-$a));
            $distanceKm = round(6371 * $c, 2);
            $etaMinutes = max(2, (int)round(($distanceKm / 25) * 60));
        }

        // Fetch genuine customer reviews from MySQL reviews table
        $revStmt = $this->db->prepare("
            SELECT r.id, r.rating, r.comment, r.created_at,
                   u_c.name AS reviewer_name, u_c.avatar AS reviewer_avatar
            FROM reviews r
            JOIN users u_c ON r.user_id = u_c.id
            WHERE r.driver_id = ?
            ORDER BY r.created_at DESC LIMIT 10
        ");
        $revStmt->execute([$driverId]);
        $reviews = $revStmt->fetchAll(PDO::FETCH_ASSOC);

        // Security check: Driver's private phone number is strictly withheld before an authorized booking
        Response::success([
            'id'                 => (int)$driver['id'],
            'driver_name'        => $driver['name'],
            'avatar'             => $driver['avatar'] ?? null,
            'license_number'     => $driver['license_number'] ?? null,
            'vehicle_type'       => $driver['vehicle_type'] ?? 'Sedan',
            'vehicle_model'      => $driver['vehicle_model'] ?? 'Standard Car',
            'vehicle_number'     => $driver['vehicle_number'] ?? null,
            'avg_rating'         => $driver['avg_rating'] !== null ? (float)$driver['avg_rating'] : null,
            'total_trips'        => (int)($driver['total_trips'] ?? 0),
            'experience_years'   => $driver['experience_years'] !== null ? (int)$driver['experience_years'] : null,
            'hourly_rate'        => (float)($driver['hourly_rate'] ?: 150.00),
            'is_online'          => (bool)$driver['is_online'],
            'is_busy'            => (bool)$driver['is_busy'],
            'is_available'       => ((int)$driver['is_online'] === 1 && (int)$driver['is_busy'] === 0),
            'verification_status'=> $driver['status'],
            'current_lat'        => $driverLat,
            'current_lng'        => $driverLng,
            'distance_km'        => $distanceKm,
            'eta_minutes'        => $etaMinutes,
            'reviews'            => $reviews,
            'reviews_count'      => count($reviews)
        ]);
    }

    /**
     * POST /drivers/smart-match
     * Weighted scoring algorithm:
     * - Driver availability: 35%
     * - Pickup distance & ETA: 30%
     * - Actual average customer rating: 20%
     * - Completed trips & experience: 10%
     * - Vehicle compatibility: 5%
     */
    public function smartMatch(): void {
        AuthMiddleware::authenticate();
        $data = Response::body();

        $pickupLat = isset($data['pickup_lat']) ? (float)$data['pickup_lat'] : null;
        $pickupLng = isset($data['pickup_lng']) ? (float)$data['pickup_lng'] : null;
        $vehiclePref = strtolower(trim($data['vehicle_preference'] ?? ''));

        // Configurable weights (default to standard 35/30/20/10/5)
        $customWeights = $data['weights'] ?? [];
        $wAvail = isset($customWeights['availability']) ? (float)$customWeights['availability'] : 35.0;
        $wDist  = isset($customWeights['distance_eta']) ? (float)$customWeights['distance_eta'] : 30.0;
        $wRate  = isset($customWeights['rating']) ? (float)$customWeights['rating'] : 20.0;
        $wExp   = isset($customWeights['experience']) ? (float)$customWeights['experience'] : 10.0;
        $wCompat= isset($customWeights['compatibility']) ? (float)$customWeights['compatibility'] : 5.0;

        $stmt = $this->db->prepare("
            SELECT u.id, u.name, u.avatar,
                   dp.license_number, dp.vehicle_type, dp.vehicle_model, dp.vehicle_number,
                   dp.avg_rating, dp.total_trips, dp.experience_years, dp.hourly_rate,
                   dp.is_online, dp.status, dp.current_lat, dp.current_lng
            FROM driver_profile dp
            JOIN users u ON dp.user_id = u.id
            WHERE dp.status = 'verified' AND u.status = 'active'
              AND dp.is_online = 1
              AND NOT EXISTS (SELECT 1 FROM trips tr WHERE tr.driver_id = u.id AND tr.status = 'ongoing')
              AND NOT EXISTS (SELECT 1 FROM bookings b WHERE b.driver_id = u.id AND b.status IN ('confirmed', 'arrived', 'ongoing'))
        ");
        $stmt->execute();
        $candidates = $stmt->fetchAll(PDO::FETCH_ASSOC);

        if (empty($candidates)) {
            Response::error('No verified online drivers are currently available in your service area', 404);
        }

        $scoredDrivers = [];
        foreach ($candidates as $c) {
            $availScore = $wAvail;

            $distKm = null;
            $etaMin = null;
            $cLat = isset($c['current_lat']) && is_numeric($c['current_lat']) ? (float)$c['current_lat'] : null;
            $cLng = isset($c['current_lng']) && is_numeric($c['current_lng']) ? (float)$c['current_lng'] : null;

            if ($pickupLat !== null && $pickupLng !== null && $cLat !== null && $cLng !== null) {
                $dLat = deg2rad($cLat - $pickupLat);
                $dLng = deg2rad($cLng - $pickupLng);
                $a = sin($dLat/2) * sin($dLat/2) +
                     cos(deg2rad($pickupLat)) * cos(deg2rad($cLat)) *
                     sin($dLng/2) * sin($dLng/2);
                $distKm = round(6371 * 2 * atan2(sqrt($a), sqrt(1-$a)), 2);
                $etaMin = max(2, (int)round(($distKm / 25) * 60));

                if ($distKm <= 2.0) $distScore = $wDist * 1.0;
                elseif ($distKm <= 5.0) $distScore = round($wDist * (25.0 / 30.0), 1);
                elseif ($distKm <= 10.0) $distScore = round($wDist * (18.0 / 30.0), 1);
                elseif ($distKm <= 20.0) $distScore = round($wDist * (10.0 / 30.0), 1);
                else $distScore = round($wDist * (5.0 / 30.0), 1);
            } else {
                $distScore = round($wDist * 0.5, 1);
            }

            $rawRating = $c['avg_rating'] !== null ? (float)$c['avg_rating'] : null;
            if ($rawRating !== null && $rawRating > 0) {
                $ratingScore = round(($rawRating / 5.0) * $wRate, 1);
            } else {
                $ratingScore = round($wRate * 0.5, 1);
            }

            $trips = (int)($c['total_trips'] ?? 0);
            $expYears = (int)($c['experience_years'] ?? 1);
            $tripScore = min($wExp * 0.5, round(($trips / 100.0) * ($wExp * 0.5), 1));
            $expScore = min($wExp * 0.5, round(($expYears / 5.0) * ($wExp * 0.5), 1));
            $expTotalScore = round($tripScore + $expScore, 1);

            $vType = strtolower($c['vehicle_type'] ?? '');
            if (!empty($vehiclePref) && str_contains($vType, $vehiclePref)) {
                $compatScore = $wCompat;
            } else {
                $compatScore = round($wCompat * 0.8, 1);
            }

            $totalScore = round($availScore + $distScore + $ratingScore + $expTotalScore + $compatScore, 1);

            $hourlyRate = (float)($c['hourly_rate'] ?? 150.0);
            $estFare = max(150.0, round(($distKm ?? 5.0) * 18.0 + 80.0, 2));

            $scoredDrivers[] = [
                'id'               => (int)$c['id'],
                'driver_name'      => $c['name'],
                'avatar'           => $c['avatar'] ?? null,
                'license_number'   => $c['license_number'] ?? null,
                'vehicle_type'     => $c['vehicle_type'] ?? 'Sedan',
                'vehicle_model'    => $c['vehicle_model'] ?? 'Standard Car',
                'vehicle_number'   => $c['vehicle_number'] ?? null,
                'avg_rating'       => $rawRating,
                'total_trips'      => $trips,
                'experience_years' => $expYears,
                'hourly_rate'      => $hourlyRate,
                'estimated_fare'   => $estFare,
                'distance_km'      => $distKm,
                'eta_minutes'      => $etaMin,
                'is_online'        => true,
                'is_busy'          => false,
                'is_available'     => true,
                'verification_status' => $c['status'] ?? 'verified',
                'current_lat'      => $cLat,
                'current_lng'      => $cLng,
                'total_match_score'=> $totalScore,
                'score_breakdown'  => [
                    'availability_pts' => $availScore,
                    'distance_eta_pts' => $distScore,
                    'rating_pts'       => $ratingScore,
                    'experience_pts'   => $expTotalScore,
                    'compatibility_pts'=> $compatScore,
                    'weights'          => [
                        'availability' => (int)$wAvail . '%',
                        'distance_eta' => (int)$wDist . '%',
                        'rating'       => (int)$wRate . '%',
                        'experience'   => (int)$wExp . '%',
                        'compatibility'=> (int)$wCompat . '%'
                    ]
                ]
            ];
        }

        usort($scoredDrivers, fn($a, $b) => $b['total_match_score'] <=> $a['total_match_score']);

        $bestDriver = $scoredDrivers[0];
        $runnersUp = array_slice($scoredDrivers, 1);

        Response::success([
            'algorithm'          => 'DriveMate Smart Weighted Auto-Match Engine v1.0',
            'recommended_driver' => $bestDriver,
            'runners_up'         => $runnersUp,
            'total_evaluated'    => count($scoredDrivers)
        ], 'Smart match calculated successfully');
    }
}
