<?php
// admin/auth_check.php — DriveMate Admin Security & Session Gatekeeper
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once __DIR__ . '/../config/database.php';
$db = Database::getInstance();

// Check if user is logged in as admin
if (empty($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true || ($_SESSION['admin_role'] ?? '') !== 'admin') {
    $currentUrl = urlencode($_SERVER['REQUEST_URI'] ?? 'index.php');
    header("Location: login.php?redirect={$currentUrl}");
    exit();
}

// Ensure CSRF Token is initialized
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

/**
 * Verify CSRF Token from POST request
 */
function verify_csrf_token(?string $token): bool {
    if (empty($token) || empty($_SESSION['csrf_token'])) {
        return false;
    }
    return hash_equals($_SESSION['csrf_token'], $token);
}

/**
 * Audit log helper to record administrative actions
 */
function log_admin_action(string $action, string $targetType, ?int $targetId = null, ?string $details = null): void {
    global $db;
    try {
        $adminId = (int)($_SESSION['admin_user_id'] ?? 0);
        if ($adminId <= 0) return;
        $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
        $stmt = $db->prepare("INSERT INTO admin_audit_logs (admin_id, action, target_type, target_id, details, ip_address, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())");
        $stmt->execute([$adminId, $action, $targetType, $targetId, $details, $ip]);
    } catch (Exception $e) {
        // Silently capture or log to system error log
        error_log("Failed to log admin action: " . $e->getMessage());
    }
}
