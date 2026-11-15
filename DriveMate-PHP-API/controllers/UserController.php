<?php
// controllers/UserController.php — Profile, update, list

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class UserController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // GET /users/profile  (auth required)
    public function profile(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];

        $stmt = $this->db->prepare(
            "SELECT id, name, email, phone, role, avatar, status, preferred_language, created_at FROM users WHERE id = ?"
        );
        $stmt->execute([$userId]);
        $user = $stmt->fetch();

        if (!$user) Response::error('User not found', 404);

        Response::success($user);
    }

    // PUT /users/profile  (auth required)
    public function updateProfile(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data   = Response::body();

        $name   = trim($data['name']  ?? '');
        $phone  = trim($data['phone'] ?? '');
        $email  = trim($data['email'] ?? '');
        $lang   = strtolower(trim($data['preferred_language'] ?? ''));

        if (!$name) {
            Response::error('Name is required', 400);
        }

        if ($email !== '') {
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                Response::error('Invalid email address format', 400);
            }
            $chk = $this->db->prepare("SELECT id FROM users WHERE email = ? AND id != ?");
            $chk->execute([$email, $userId]);
            if ($chk->fetch()) {
                Response::error('This email is already in use by another account', 409);
            }
        }

        if ($phone !== '') {
            $cleanPhone = preg_replace('/[^0-9]/', '', $phone);
            if (strlen($cleanPhone) < 10) {
                Response::error('Phone number must have at least 10 digits', 400);
            }
        }

        $supported = ['en', 'bn', 'hi', 'or', 'ur'];
        $langVal = ($lang && in_array($lang, $supported)) ? $lang : null;

        // Build update query dynamically
        $updates = ['name = ?', 'phone = ?'];
        $params  = [$name, $phone];

        if ($email !== '') {
            $updates[] = 'email = ?';
            $params[]  = $email;
        }
        if ($langVal !== null) {
            $updates[] = 'preferred_language = ?';
            $params[]  = $langVal;
        }

        $params[] = $userId;
        $sql = "UPDATE users SET " . implode(', ', $updates) . " WHERE id = ?";
        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);

        // Fetch refreshed user record
        $fetchStmt = $this->db->prepare(
            "SELECT id, name, email, phone, role, avatar, status, preferred_language, created_at FROM users WHERE id = ?"
        );
        $fetchStmt->execute([$userId]);
        $updatedUser = $fetchStmt->fetch(PDO::FETCH_ASSOC);

        Response::success($updatedUser, 'Profile updated successfully');
    }

    // POST /users/change-password  (auth required)
    public function changePassword(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data   = Response::body();

        $currentPassword = (string)($data['current_password'] ?? '');
        $newPassword     = (string)($data['new_password'] ?? '');
        $confirmPassword = (string)($data['confirm_password'] ?? '');

        if (empty($currentPassword)) {
            Response::error('Current password is required', 400);
        }
        if (empty($newPassword)) {
            Response::error('New password is required', 400);
        }
        if (strlen($newPassword) < 6) {
            Response::error('New password must be at least 6 characters long', 400);
        }
        if ($newPassword !== $confirmPassword) {
            Response::error('New password and confirmation password do not match', 400);
        }

        // Verify current password from database
        $stmt = $this->db->prepare("SELECT password FROM users WHERE id = ?");
        $stmt->execute([$userId]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user || !password_verify($currentPassword, $user['password'])) {
            Response::error('Current password is incorrect', 400);
        }

        if (password_verify($newPassword, $user['password'])) {
            Response::error('New password must be different from current password', 400);
        }

        $newHash = password_hash($newPassword, PASSWORD_DEFAULT);
        $upd = $this->db->prepare("UPDATE users SET password = ? WHERE id = ?");
        $upd->execute([$newHash, $userId]);

        Response::success([], 'Password changed successfully');
    }

    // POST /users/set-language (Updates authenticated user profile, or returns locale info for guest)
    public function setLanguage(): void {
        $auth = AuthMiddleware::optionalAuthenticate();
        $data = Response::body();

        $lang = strtolower(trim($data['language'] ?? 'en'));

        $supported = ['en', 'bn', 'hi', 'or', 'ur'];
        if (!in_array($lang, $supported)) {
            Response::error('Invalid language code. Supported: en, bn, hi, or, ur', 400);
        }

        // Only update database when legitimately authenticated via verified JWT
        if ($auth && !empty($auth['sub'])) {
            $userId = (int)$auth['sub'];
            $stmt = $this->db->prepare("UPDATE users SET preferred_language = ? WHERE id = ?");
            $stmt->execute([$lang, $userId]);
        }

        $messages = [
            'en' => 'Language preference saved successfully',
            'bn' => 'ভাষার পছন্দ সফলভাবে সংরক্ষিত হয়েছে',
            'hi' => 'भाषा प्राथमिकता सफलतापूर्वक सहेजी गई',
            'or' => 'ଭାଷା ପସନ୍ଦ ସଫଳତାର ସହିତ ସଂରକ୍ଷିତ ହେଲା',
            'ur' => 'زبان کی ترجیح کامیابی کے ساتھ محفوظ ہو گئی'
        ];

        Response::success([
            'language' => $lang,
            'direction' => ($lang === 'ur') ? 'rtl' : 'ltr',
            'supported_languages' => $supported
        ], $messages[$lang] ?? $messages['en']);
    }

    // POST /users/avatar  (auth required)
    public function uploadAvatar(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];

        if (!isset($_FILES['avatar'])) {
            Response::error('No file uploaded');
        }

        $file    = $_FILES['avatar'];
        $allowed = ['image/jpeg', 'image/png', 'image/webp'];

        if (!in_array($file['type'], $allowed)) {
            Response::error('Only JPG, PNG, WEBP allowed');
        }

        $ext      = pathinfo($file['name'], PATHINFO_EXTENSION);
        $filename = "avatar_{$userId}_" . time() . ".{$ext}";
        $dest     = __DIR__ . "/../uploads/avatars/{$filename}";

        if (!move_uploaded_file($file['tmp_name'], $dest)) {
            Response::error('Upload failed', 500);
        }

        $url  = $_ENV['BASE_URL'] . "/uploads/avatars/{$filename}";
        $stmt = $this->db->prepare("UPDATE users SET avatar = ? WHERE id = ?");
        $stmt->execute([$url, $userId]);

        Response::success(['avatar_url' => $url], 'Avatar uploaded');
    }

    // GET /users/list  (admin only)
    public function listUsers(): void {
        AuthMiddleware::requireRole('admin');

        $role = $_GET['role'] ?? null;
        $sql  = "SELECT id, name, email, phone, role, status, created_at FROM users";
        $params = [];

        if ($role) {
            $sql .= " WHERE role = ?";
            $params[] = $role;
        }

        $sql .= " ORDER BY created_at DESC";
        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);

        Response::success($stmt->fetchAll());
    }
}
