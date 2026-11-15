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
        $userId = $auth['sub'];
        $data   = Response::body();

        $name  = trim($data['name']  ?? '');
        $phone = trim($data['phone'] ?? '');
        $lang  = strtolower(trim($data['preferred_language'] ?? ''));

        if (!$name) Response::error('Name is required');

        $supported = ['en', 'bn', 'hi', 'or', 'ur'];
        if ($lang && in_array($lang, $supported)) {
            $stmt = $this->db->prepare("UPDATE users SET name = ?, phone = ?, preferred_language = ? WHERE id = ?");
            $stmt->execute([$name, $phone, $lang, $userId]);
        } else {
            $stmt = $this->db->prepare("UPDATE users SET name = ?, phone = ? WHERE id = ?");
            $stmt->execute([$name, $phone, $userId]);
        }

        Response::success([], 'Profile updated');
    }

    // POST /users/set-language (auth required or optional with user_id)
    public function setLanguage(): void {
        $auth = AuthMiddleware::optionalAuthenticate();
        $data = Response::body();

        $userId = $auth ? (int)$auth['sub'] : (int)($data['user_id'] ?? 0);
        $lang   = strtolower(trim($data['language'] ?? 'en'));

        $supported = ['en', 'bn', 'hi', 'or', 'ur'];
        if (!in_array($lang, $supported)) {
            Response::error('Invalid language code. Supported: en, bn, hi, or, ur', 400);
        }

        if ($userId > 0) {
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
