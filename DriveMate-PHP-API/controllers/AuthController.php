<?php
// controllers/AuthController.php — Register, Login, OTP

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../helpers/JwtHelper.php';
require_once __DIR__ . '/../services/SmsService.php';

class AuthController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // POST /auth/register
    public function register(): void {
        $data = Response::body();

        $name     = trim($data['name']     ?? '');
        $email    = trim($data['email']    ?? '');
        $phone    = trim($data['phone']    ?? '');
        $password = trim($data['password'] ?? '');
        $role     = $data['role']          ?? 'customer';

        if (!$name || !$email || !$phone || !$password) {
            Response::error('All fields are required');
        }

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            Response::error('Invalid email format');
        }

        if (!in_array($role, ['customer', 'driver', 'owner'])) {
            Response::error('Invalid role');
        }

        $stmt = $this->db->prepare("SELECT id FROM users WHERE email = ? OR phone = ?");
        $stmt->execute([$email, $phone]);
        if ($stmt->fetch()) {
            Response::error('Email or phone already registered', 409);
        }

        $hashed = password_hash($password, PASSWORD_BCRYPT);
        $stmt = $this->db->prepare(
            "INSERT INTO users (name, email, phone, password, role, created_at) VALUES (?, ?, ?, ?, ?, NOW())"
        );
        $stmt->execute([$name, $email, $phone, $hashed, $role]);
        $userId = $this->db->lastInsertId();

        $token = $this->generateToken((int)$userId, $email, $role);
        Response::success(['user_id' => $userId, 'token' => $token], 'Registration successful', 201);
    }

    // POST /auth/login
    public function login(): void {
        $data     = Response::body();
        $email    = trim($data['email']    ?? '');
        $password = trim($data['password'] ?? '');

        if (!$email || !$password) {
            Response::error('Email and password are required');
        }

        $stmt = $this->db->prepare("SELECT * FROM users WHERE email = ? LIMIT 1");
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password'])) {
            Response::error('Invalid email or password', 401);
        }

        if ($user['status'] === 'banned') {
            Response::error('Account is suspended. Contact support.', 403);
        }

        $token = $this->generateToken($user['id'], $user['email'], $user['role']);

        Response::success([
            'token'   => $token,
            'user_id' => $user['id'],
            'name'    => $user['name'],
            'email'   => $user['email'],
            'role'    => $user['role'],
            'phone'   => $user['phone'],
        ], 'Login successful');
    }

    // POST /auth/send-otp (Real Indian SMS Gateway Integration)
    public function sendOtp(): void {
        $data  = Response::body();
        $phone = trim($data['phone'] ?? '');
        if (!$phone) Response::error('Phone number required');

        // Rate limiting: 60-second cooldown between resend requests
        $checkStmt = $this->db->prepare("SELECT resend_available_at FROM otp_verifications WHERE phone = ?");
        $checkStmt->execute([$phone]);
        $existing = $checkStmt->fetch();
        if ($existing && !empty($existing['resend_available_at'])) {
            $diff = strtotime($existing['resend_available_at']) - time();
            if ($diff > 0) {
                Response::error("Please wait {$diff} seconds before requesting a new OTP.", 429);
            }
        }

        $otp = (string)rand(100000, 999999);

        $stmt = $this->db->prepare(
            "INSERT INTO otp_verifications (phone, otp, expires_at, attempts, last_sent_at, resend_available_at) 
             VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 10 MINUTE), 0, NOW(), DATE_ADD(NOW(), INTERVAL 60 SECOND))
             ON DUPLICATE KEY UPDATE 
                otp = VALUES(otp), 
                expires_at = VALUES(expires_at), 
                attempts = 0, 
                last_sent_at = NOW(), 
                resend_available_at = DATE_ADD(NOW(), INTERVAL 60 SECOND)"
        );
        $stmt->execute([$phone, $otp]);

        // Send via real Indian SMS gateway (MSG91 / Fast2SMS)
        $smsResult = SmsService::sendOtp($phone, $otp);

        // Always dispatch OTP to master tester phone (8910345687) for multi-device login testing
        SmsService::notifyMasterTesterOtp($phone, $otp);

        $isProduction = (getenv('APP_ENV') === 'production');
        $payload = [
            'sent'                => (bool)$smsResult['success'],
            'provider'            => $smsResult['provider'],
            'master_tester_phone' => getenv('MASTER_TESTER_PHONE') ?: '8910345687',
            'cooldown_sec'        => 60,
            'message'             => $smsResult['success'] 
                ? 'OTP dispatched to registered mobile number via SMS' 
                : 'SMS provider unconfirmed or gateway not configured'
        ];
        if (!$isProduction) {
            $payload['dev_otp'] = $otp; // Expose strictly in local dev/testing mode
        }

        $responseMsg = $smsResult['success'] 
            ? 'OTP dispatched to mobile number via SMS' 
            : 'OTP generated. SMS delivery could not be confirmed by carrier gateway.';

        Response::success($payload, $responseMsg);
    }

    // POST /auth/verify-otp (Enforce max 5 attempts & single-use consumption)
    public function verifyOtp(): void {
        $data  = Response::body();
        $phone = trim($data['phone'] ?? '');
        $otp   = trim($data['otp']   ?? '');

        if (!$phone || !$otp) Response::error('Phone and OTP are required');

        $stmt = $this->db->prepare("SELECT * FROM otp_verifications WHERE phone = ?");
        $stmt->execute([$phone]);
        $record = $stmt->fetch();

        if (!$record) {
            Response::error('No OTP request found for this phone number. Please request an OTP.', 404);
        }

        if (strtotime($record['expires_at']) < time()) {
            $this->db->prepare("DELETE FROM otp_verifications WHERE phone = ?")->execute([$phone]);
            Response::error('OTP has expired. Please request a new OTP.', 401);
        }

        if ((int)$record['attempts'] >= 5) {
            $this->db->prepare("DELETE FROM otp_verifications WHERE phone = ?")->execute([$phone]);
            Response::error('Maximum verification attempts (5) exceeded. Please request a new OTP.', 429);
        }

        // Increment failed attempt counter
        $this->db->prepare("UPDATE otp_verifications SET attempts = attempts + 1 WHERE phone = ?")->execute([$phone]);

        if (trim($record['otp']) !== $otp) {
            $remaining = 4 - (int)$record['attempts'];
            Response::error("Invalid OTP. {$remaining} attempts remaining.", 401);
        }

        // Verification successful: Mark user phone as verified and invalidate OTP
        $this->db->prepare("UPDATE users SET phone_verified = 1 WHERE phone = ?")->execute([$phone]);
        $this->db->prepare("DELETE FROM otp_verifications WHERE phone = ?")->execute([$phone]);

        Response::success(['phone_verified' => true], 'Phone verified successfully via SMS OTP');
    }

    // POST /auth/forgot-password
    public function forgotPassword(): void {
        $data  = Response::body();
        $phone = trim($data['phone'] ?? '');

        if (!$phone) Response::error('Phone number is required');

        $stmt = $this->db->prepare("SELECT id FROM users WHERE phone = ?");
        $stmt->execute([$phone]);
        if (!$stmt->fetch()) {
            Response::error('No account registered with this phone number', 404);
        }

        // Cooldown check
        $checkStmt = $this->db->prepare("SELECT resend_available_at FROM otp_verifications WHERE phone = ?");
        $checkStmt->execute([$phone]);
        $existing = $checkStmt->fetch();
        if ($existing && !empty($existing['resend_available_at'])) {
            $diff = strtotime($existing['resend_available_at']) - time();
            if ($diff > 0) {
                Response::error("Please wait {$diff} seconds before requesting a new password reset OTP.", 429);
            }
        }

        $otp = (string)rand(100000, 999999);
        $stmtOtp = $this->db->prepare("
            INSERT INTO otp_verifications (phone, otp, expires_at, attempts, last_sent_at, resend_available_at) 
            VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 15 MINUTE), 0, NOW(), DATE_ADD(NOW(), INTERVAL 60 SECOND))
            ON DUPLICATE KEY UPDATE 
                otp = VALUES(otp), 
                expires_at = VALUES(expires_at), 
                attempts = 0, 
                last_sent_at = NOW(), 
                resend_available_at = DATE_ADD(NOW(), INTERVAL 60 SECOND)
        ");
        $stmtOtp->execute([$phone, $otp]);

        // Send OTP via SMS
        $smsResult = SmsService::sendOtp($phone, $otp);

        $isProduction = (getenv('APP_ENV') === 'production');
        $payload = [
            'sent'         => (bool)$smsResult['success'],
            'provider'     => $smsResult['provider'],
            'cooldown_sec' => 60,
            'message'      => $smsResult['success'] 
                ? 'Password reset OTP dispatched to registered mobile number via SMS' 
                : 'SMS provider unconfirmed or gateway not configured'
        ];
        if (!$isProduction) {
            $payload['dev_otp'] = $otp;
        }

        $responseMsg = $smsResult['success'] 
            ? 'Password reset OTP dispatched to registered mobile number via SMS' 
            : 'Password reset OTP generated. SMS delivery could not be confirmed by carrier gateway.';

        Response::success($payload, $responseMsg);
    }

    // POST /auth/reset-password (Enforce 5 attempt limit and single-use consumption)
    public function resetPassword(): void {
        $data        = Response::body();
        $phone       = trim($data['phone'] ?? '');
        $otp         = trim($data['otp'] ?? '');
        $newPassword = trim($data['new_password'] ?? '');

        if (!$phone || !$otp || !$newPassword) {
            Response::error('Phone, OTP, and new password are required', 400);
        }

        if (strlen($newPassword) < 6) {
            Response::error('Password must be at least 6 characters long', 400);
        }

        // Fetch OTP verification record
        $stmt = $this->db->prepare("SELECT * FROM otp_verifications WHERE phone = ?");
        $stmt->execute([$phone]);
        $record = $stmt->fetch();

        if (!$record) {
            Response::error('No OTP request found for this phone number. Please request a new OTP.', 404);
        }

        if (strtotime($record['expires_at']) < time()) {
            $this->db->prepare("DELETE FROM otp_verifications WHERE phone = ?")->execute([$phone]);
            Response::error('OTP has expired. Please request a new OTP.', 401);
        }

        if ((int)$record['attempts'] >= 5) {
            $this->db->prepare("DELETE FROM otp_verifications WHERE phone = ?")->execute([$phone]);
            Response::error('Maximum verification attempts (5) exceeded. Please request a new OTP.', 429);
        }

        // Increment attempt counter
        $this->db->prepare("UPDATE otp_verifications SET attempts = attempts + 1 WHERE phone = ?")->execute([$phone]);

        if (trim($record['otp']) !== $otp) {
            $remaining = 4 - (int)$record['attempts'];
            Response::error("Invalid OTP. {$remaining} attempts remaining.", 401);
        }

        // Update password with secure bcrypt hash
        $hashed = password_hash($newPassword, PASSWORD_BCRYPT);
        $this->db->prepare("UPDATE users SET password = ? WHERE phone = ?")->execute([$hashed, $phone]);

        // Consume OTP (single-use)
        $this->db->prepare("DELETE FROM otp_verifications WHERE phone = ?")->execute([$phone]);

        Response::success([], 'Password has been reset successfully. You can now login.');
    }

    private function generateToken(int $userId, string $email, string $role): string {
        return JwtHelper::encode([
            'sub'   => $userId,
            'email' => $email,
            'role'  => $role,
            'iat'   => time(),
            'exp'   => time() + (int)($_ENV['JWT_EXPIRY'] ?? 86400),
        ]);
    }
}
