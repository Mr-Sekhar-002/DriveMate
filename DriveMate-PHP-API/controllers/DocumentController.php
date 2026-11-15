<?php
// controllers/DocumentController.php — Upload KYC, DL, RC, Insurance documents

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class DocumentController {
    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // POST /documents/upload (Auth required)
    public function upload(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];

        $type = $_POST['type'] ?? ''; // kyc | rc | dl | insurance | photo
        if (!in_array($type, ['kyc', 'rc', 'dl', 'insurance', 'photo'])) {
            Response::error('Invalid document type. Allowed: kyc, rc, dl, insurance, photo');
        }

        if (!isset($_FILES['document']) || $_FILES['document']['error'] !== UPLOAD_ERR_OK) {
            Response::error('No document uploaded or upload error occurred');
        }

        $file     = $_FILES['document'];
        $allowed  = ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'];
        $fileType = mime_content_type($file['tmp_name']);

        if (!in_array($fileType, $allowed)) {
            Response::error('Only JPG, PNG, WEBP, or PDF files are allowed');
        }

        $uploadDir = __DIR__ . '/../uploads/documents/';
        if (!is_dir($uploadDir)) {
            mkdir($uploadDir, 0777, true);
        }

        $ext      = pathinfo($file['name'], PATHINFO_EXTENSION);
        $filename = "doc_{$userId}_{$type}_" . time() . ".{$ext}";
        $dest     = $uploadDir . $filename;

        if (!move_uploaded_file($file['tmp_name'], $dest)) {
            Response::error('Failed to save uploaded file', 500);
        }

        $fileUrl = ($_ENV['BASE_URL'] ?? 'http://localhost/drivemate-api') . "/uploads/documents/{$filename}";

        $stmt = $this->db->prepare("
            INSERT INTO documents (user_id, type, file_url, status, created_at)
            VALUES (?, ?, ?, 'pending', NOW())
        ");
        $stmt->execute([$userId, $type, $fileUrl]);
        $docId = $this->db->lastInsertId();

        Response::success(['document_id' => $docId, 'file_url' => $fileUrl], 'Document uploaded successfully', 201);
    }

    // GET /documents/my (Auth required)
    public function myDocuments(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];

        $stmt = $this->db->prepare("
            SELECT * FROM documents WHERE user_id = ? ORDER BY created_at DESC
        ");
        $stmt->execute([$userId]);
        Response::success($stmt->fetchAll());
    }
}
