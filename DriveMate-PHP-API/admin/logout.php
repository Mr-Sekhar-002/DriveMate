<?php
// admin/logout.php — Secure Admin Session Termination
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once __DIR__ . '/../config/database.php';

if (!empty($_SESSION['admin_user_id'])) {
    try {
        $db = Database::getInstance();
        $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
        $logStmt = $db->prepare("INSERT INTO admin_audit_logs (admin_id, action, target_type, target_id, details, ip_address, created_at) VALUES (?, 'logout', 'admin', ?, 'Admin logged out', ?, NOW())");
        $logStmt->execute([$_SESSION['admin_user_id'], $_SESSION['admin_user_id'], $ip]);
    } catch (Exception $e) {}
}

$_SESSION = [];
if (ini_get("session.use_cookies")) {
    $params = session_get_cookie_params();
    setcookie(session_name(), '', time() - 42000,
        $params["path"], $params["domain"],
        $params["secure"], $params["httponly"]
    );
}
session_destroy();

header("Location: login.php");
exit();
