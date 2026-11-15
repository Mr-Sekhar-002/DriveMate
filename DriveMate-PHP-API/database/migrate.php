<?php
// database/migrate.php — One-click database patch & auto-migration
require_once __DIR__ . '/../config/database.php';

header('Content-Type: text/html; charset=utf-8');

try {
    $db = Database::getInstance();

    // 1. Add driver online/GPS fields if not present
    $columns = $db->query("SHOW COLUMNS FROM driver_profile LIKE 'is_online'")->fetchAll();
    if (empty($columns)) {
        $db->exec("ALTER TABLE driver_profile 
            ADD COLUMN is_online TINYINT(1) NOT NULL DEFAULT 0,
            ADD COLUMN current_lat DECIMAL(10,7) DEFAULT NULL,
            ADD COLUMN current_lng DECIMAL(10,7) DEFAULT NULL,
            ADD COLUMN last_active_at DATETIME DEFAULT NULL");
    }

    // 2. Support tickets
    $db->exec("CREATE TABLE IF NOT EXISTS support_tickets (
        id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        user_id     INT UNSIGNED NOT NULL,
        booking_id  INT UNSIGNED DEFAULT NULL,
        subject     VARCHAR(200) NOT NULL,
        category    ENUM('booking','payment','driver','vehicle','app','other') NOT NULL DEFAULT 'other',
        message     TEXT NOT NULL,
        status      ENUM('open','in_progress','resolved','closed') NOT NULL DEFAULT 'open',
        admin_reply TEXT DEFAULT NULL,
        created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at  DATETIME DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL
    )");

    // 3. System settings
    $db->exec("CREATE TABLE IF NOT EXISTS system_settings (
        setting_key   VARCHAR(50) PRIMARY KEY,
        setting_value TEXT NOT NULL,
        description   VARCHAR(255) DEFAULT NULL,
        updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )");

    // 4. Default settings (Indian Rupee Rates)
    $db->exec("INSERT INTO system_settings (setting_key, setting_value, description) VALUES
        ('base_fare', '150.00', 'Base fare for bookings in INR'),
        ('per_km_rate', '18.00', 'Rate per kilometer in INR'),
        ('driver_hourly_rate', '120.00', 'Hourly rate for hired driver in INR'),
        ('platform_commission_percent', '15', 'Commission percentage deducted from driver/owner'),
        ('currency', 'INR', 'Currency code'),
        ('currency_symbol', '₹', 'Currency display symbol'),
        ('support_email', 'support@drivemate.in', 'Customer support contact email'),
        ('support_phone', '+91 9876543210', 'Customer support hotline phone')
        ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)");

    // 5. Fare Negotiations Table (Requirement 4)
    $db->exec("CREATE TABLE IF NOT EXISTS fare_negotiations (
        id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        booking_id   INT UNSIGNED NOT NULL,
        sender_id    INT UNSIGNED NOT NULL,
        sender_role  ENUM('customer','driver') NOT NULL,
        offered_fare DECIMAL(10,2) NOT NULL,
        counter_fare DECIMAL(10,2) DEFAULT NULL,
        status       ENUM('PENDING','COUNTER_OFFERED','ACCEPTED','REJECTED','EXPIRED') NOT NULL DEFAULT 'PENDING',
        notes        TEXT DEFAULT NULL,
        created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at   DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_booking_id (booking_id),
        INDEX idx_sender_id (sender_id),
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    // 6. Trip Status History Table (Requirement 6)
    $db->exec("CREATE TABLE IF NOT EXISTS trip_status_history (
        id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        trip_id            INT UNSIGNED NOT NULL,
        status             ENUM('pending','confirmed','ongoing','completed','cancelled') NOT NULL,
        changed_by_user_id INT UNSIGNED NOT NULL,
        notes              VARCHAR(255) DEFAULT NULL,
        created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_tsh_trip (trip_id),
        INDEX idx_tsh_user (changed_by_user_id),
        FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
        FOREIGN KEY (changed_by_user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    // 7. Add negotiated_fare columns to bookings if not present
    $bookingCols = $db->query("SHOW COLUMNS FROM bookings LIKE 'negotiated_fare'")->fetchAll();
    if (empty($bookingCols)) {
        $db->exec("ALTER TABLE bookings 
            ADD COLUMN negotiated_fare DECIMAL(10,2) DEFAULT NULL AFTER total_amount,
            ADD COLUMN negotiation_status ENUM('NONE','PENDING','AGREED','REJECTED') DEFAULT 'NONE' AFTER negotiated_fare");
    }

    // 8. Add attempts and rate limiting to otp_verifications if not present
    $otpCols = $db->query("SHOW COLUMNS FROM otp_verifications LIKE 'attempts'")->fetchAll();
    if (empty($otpCols)) {
        $db->exec("ALTER TABLE otp_verifications 
            ADD COLUMN attempts TINYINT(3) UNSIGNED NOT NULL DEFAULT 0,
            ADD COLUMN last_sent_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            ADD COLUMN resend_available_at DATETIME DEFAULT NULL");
    }

    echo "<h2 style='color:green;'>✅ DriveMate Database Master Migration Succeeded!</h2>";
    echo "<p>Installed <b>fare_negotiations</b>, <b>trip_status_history</b>, <b>INR settings</b>, and <b>rate-limiting OTP</b> fields.</p>";
    echo "<a href='../admin/index.php'>Go to Admin Dashboard</a>";
} catch (Exception $e) {
    echo "<h2 style='color:red;'>❌ Migration Error:</h2><p>" . htmlspecialchars($e->getMessage()) . "</p>";
}
