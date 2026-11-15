<?php
// controllers/SettingsController.php — System settings, dynamic pricing & analytics reports

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class SettingsController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // GET /settings (Public / Auth) — Get platform rates and contact details
    public function getSettings(): void {
        $stmt = $this->db->query("SELECT setting_key, setting_value, description FROM system_settings");
        $rows = $stmt->fetchAll();

        $settings = [];
        foreach ($rows as $row) {
            $settings[$row['setting_key']] = $row['setting_value'];
        }

        Response::success($settings);
    }

    // PUT /admin/settings (Admin only) — Update fare rates or commission
    public function updateSettings(): void {
        AuthMiddleware::requireRole('admin');
        $data = Response::body();

        if (empty($data)) {
            Response::error('No settings provided to update');
        }

        $stmt = $this->db->prepare("
            INSERT INTO system_settings (setting_key, setting_value)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)
        ");

        foreach ($data as $key => $val) {
            $stmt->execute([$key, (string)$val]);
        }

        Response::success([], 'Settings updated successfully');
    }

    // GET /admin/reports/analytics (Admin only) — Revenue, trips, growth
    public function getAnalytics(): void {
        AuthMiddleware::requireRole('admin');

        $totalUsers    = (int)$this->db->query("SELECT COUNT(*) FROM users")->fetchColumn();
        $totalDrivers  = (int)$this->db->query("SELECT COUNT(*) FROM driver_profile WHERE status = 'verified'")->fetchColumn();
        $totalVehicles = (int)$this->db->query("SELECT COUNT(*) FROM vehicles WHERE status = 'active'")->fetchColumn();
        $totalBookings = (int)$this->db->query("SELECT COUNT(*) FROM bookings")->fetchColumn();
        $totalTrips    = (int)$this->db->query("SELECT COUNT(*) FROM trips WHERE status = 'completed'")->fetchColumn();
        $grossRevenue  = (float)$this->db->query("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'paid'")->fetchColumn();

        // Calculate platform net revenue based on commission
        $commPercent = (float)($this->db->query("SELECT setting_value FROM system_settings WHERE setting_key = 'platform_commission_percent'")->fetchColumn() ?: 15);
        $netPlatformRevenue = round($grossRevenue * ($commPercent / 100), 2);

        // Recent 7 days booking trend
        $stmtTrend = $this->db->query("
            SELECT DATE(created_at) as date, COUNT(*) as bookings, COALESCE(SUM(total_amount), 0) as daily_revenue
            FROM bookings
            WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
            GROUP BY DATE(created_at)
            ORDER BY date ASC
        ");
        $trend = $stmtTrend->fetchAll();

        Response::success([
            'total_users'          => $totalUsers,
            'verified_drivers'     => $totalDrivers,
            'active_vehicles'      => $totalVehicles,
            'total_bookings'       => $totalBookings,
            'completed_trips'      => $totalTrips,
            'gross_revenue'        => $grossRevenue,
            'platform_commission'  => $commPercent,
            'net_platform_revenue' => $netPlatformRevenue,
            'weekly_trend'         => $trend,
            'currency'             => 'INR'
        ]);
    }
}
