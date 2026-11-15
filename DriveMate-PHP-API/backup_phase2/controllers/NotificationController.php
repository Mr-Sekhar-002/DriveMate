<?php
// controllers/NotificationController.php — FCM Push Notifications & Real-Time Driver Booking Alerts

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class NotificationController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    // High-priority Booking Push Notification to Driver
    public static function sendBookingNotification(
        int $bookingId,
        int $driverId,
        string $customerName,
        string $pickup,
        string $destination,
        float $fare
    ): void {
        $db = Database::getInstance();

        // Check if booking is already accepted or cancelled
        $bStmt = $db->prepare("SELECT status FROM bookings WHERE id = ?");
        $bStmt->execute([$bookingId]);
        $booking = $bStmt->fetch();
        if (!$booking || $booking['status'] !== 'pending') {
            return; // Stop notifying if already confirmed, cancelled or completed
        }

        // Fetch driver's preferred language (Phase 18 Multi-Language System)
        $langStmt = $db->prepare("SELECT preferred_language FROM users WHERE id = ?");
        $langStmt->execute([$driverId]);
        $lang = $langStmt->fetchColumn() ?: 'en';

        $templates = [
            'en' => [
                'title' => "New Booking Request!",
                'body'  => "A customer has requested a car booking. Tap to view details."
            ],
            'bn' => [
                'title' => "নতুন বুকিং অনুরোধ!",
                'body'  => "একজন গ্রাহক রাইড বুকিংয়ের অনুরোধ করেছেন। বিস্তারিত দেখতে ট্যাপ করুন।"
            ],
            'hi' => [
                'title' => "नई बुकिंग का अनुरोध!",
                'body'  => "एक ग्राहक ने बुकिंग का अनुरोध किया है। विवरण देखने के लिए टैप करें।"
            ],
            'or' => [
                'title' => "ନୂତନ ବୁକିଂ ଅନୁରୋଧ!",
                'body'  => "ଜଣେ ଗ୍ରାହକ ବୁକିଂ ଅନୁରୋଧ କରିଛନ୍ତି। ବିବରଣୀ ଦେଖିବାକୁ ଟ୍ୟାପ୍ କରନ୍ତୁ।"
            ],
            'ur' => [
                'title' => "نئی بکنگ کی درخواست!",
                'body'  => "ایک گاہک نے بکنگ کی درخواست کی ہے۔ تفصیلات دیکھنے کے لیے ٹیپ کریں۔"
            ]
        ];

        $tpl = $templates[$lang] ?? $templates['en'];
        $title = $tpl['title'];
        $body  = $tpl['body'];

        $dataPayload = [
            'type'          => 'booking_request',
            'booking_id'    => (string)$bookingId,
            'customer_name' => $customerName,
            'pickup'        => $pickup,
            'destination'   => $destination,
            'fare'          => (string)round($fare, 2),
            'currency'      => 'INR',
            'channel_id'    => 'drivemate_booking_channel',
            'sound'         => 'booking_alert',
            'priority'      => 'high',
            'click_action'  => 'FLUTTER_NOTIFICATION_CLICK'
        ];

        self::sendPushToUser($driverId, $title, $body, $dataPayload, $bookingId);
    }

    // Broadcast Booking to all verified online drivers (if unassigned)
    public static function broadcastBookingNotification(
        int $bookingId,
        string $customerName,
        string $pickup,
        string $destination,
        float $fare
    ): void {
        $db = Database::getInstance();

        // Get all eligible verified online drivers
        $stmt = $db->prepare("
            SELECT DISTINCT u.id 
            FROM users u
            JOIN driver_profile dp ON u.id = dp.user_id
            WHERE u.role = 'driver' AND u.status = 'active'
              AND dp.status = 'verified' AND dp.is_online = 1
        ");
        $stmt->execute();
        $drivers = $stmt->fetchAll(PDO::FETCH_COLUMN);

        foreach ($drivers as $dId) {
            self::sendBookingNotification($bookingId, (int)$dId, $customerName, $pickup, $destination, $fare);
        }
    }

    // Send push notification to all active device tokens of a user
    public static function sendPushToUser(
        int $userId,
        string $title,
        string $body,
        array $data = [],
        ?int $bookingId = null
    ): void {
        $db = Database::getInstance();

        // Fetch all active tokens for this driver/user
        $tokens = [];
        $tStmt = $db->prepare("SELECT fcm_token FROM driver_device_tokens WHERE driver_id = ? AND is_active = 1");
        $tStmt->execute([$userId]);
        $rows = $tStmt->fetchAll(PDO::FETCH_COLUMN);
        if (!empty($rows)) {
            $tokens = $rows;
        }

        // Fallback to users table fcm_token
        $uStmt = $db->prepare("SELECT fcm_token FROM users WHERE id = ?");
        $uStmt->execute([$userId]);
        $userFcm = $uStmt->fetchColumn();
        if ($userFcm && !in_array($userFcm, $tokens)) {
            $tokens[] = $userFcm;
        }

        // Record in in-app notifications table
        $db->prepare("
            INSERT INTO notifications (user_id, type, title, message, is_read, created_at)
            VALUES (?, 'booking', ?, ?, 0, NOW())
        ")->execute([$userId, $title, $body]);

        $serverKey = getenv('FIREBASE_SERVER_KEY') ?: ($_ENV['FIREBASE_SERVER_KEY'] ?? '');

        // If no tokens or no server key configured, record delivery attempt in logs and return
        if (empty($tokens)) {
            $db->prepare("
                INSERT INTO notification_logs (recipient_user_id, booking_id, notification_type, title, body, status, response_code, error_message, sent_at)
                VALUES (?, ?, 'booking_request', ?, ?, 'queued', 200, 'Driver has no active device token registered; in-app notification recorded', NOW())
            ")->execute([$userId, $bookingId, $title, $body]);
            return;
        }

        foreach ($tokens as $token) {
            $payload = [
                'to'                => $token,
                'priority'          => 'high',
                'content_available' => true,
                'notification'      => [
                    'title'                 => $title,
                    'body'                  => $body,
                    'sound'                 => 'default',
                    'android_channel_id'    => 'drivemate_booking_channel',
                    'channel_id'            => 'drivemate_booking_channel',
                    'click_action'          => 'FLUTTER_NOTIFICATION_CLICK',
                ],
                'data'              => $data,
                'android'           => [
                    'priority'      => 'high',
                    'notification'  => [
                        'channel_id'    => 'drivemate_booking_channel',
                        'sound'         => 'default',
                        'notification_priority' => 'PRIORITY_MAX',
                        'visibility'    => 'PUBLIC'
                    ]
                ]
            ];

            $ch = curl_init('https://fcm.googleapis.com/fcm/send');
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
            curl_setopt($ch, CURLOPT_TIMEOUT, 3);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Content-Type: application/json',
                'Authorization: key=' . $serverKey,
            ]);

            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError= curl_error($ch);
            curl_close($ch);

            $status = ($httpCode >= 200 && $httpCode < 300) ? 'sent' : 'failed';
            $errorMsg = $curlError;

            // Handle invalid/unregistered token cleanup
            if ($response) {
                $respJson = json_decode($response, true);
                if (isset($respJson['results'][0]['error'])) {
                    $err = $respJson['results'][0]['error'];
                    $errorMsg = $err;
                    if (in_array($err, ['NotRegistered', 'InvalidRegistration', 'MismatchSenderId'])) {
                        $db->prepare("UPDATE driver_device_tokens SET is_active = 0 WHERE fcm_token = ?")->execute([$token]);
                    }
                }
            }

            // Log attempt in notification_logs
            $db->prepare("
                INSERT INTO notification_logs (recipient_user_id, booking_id, notification_type, title, body, status, response_code, error_message, sent_at)
                VALUES (?, ?, 'booking_request', ?, ?, ?, ?, ?, NOW())
            ")->execute([$userId, $bookingId, $title, $body, $status, $httpCode, $errorMsg ?: null]);
        }
    }

    // Legacy method wrapper
    public static function sendPush(int $userId, string $title, string $message, array $data = []): void {
        self::sendPushToUser($userId, $title, $message, $data);
    }

    // GET /notifications/my
    public function myNotifications(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];

        $stmt = $this->db->prepare(
            "SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50"
        );
        $stmt->execute([$userId]);
        Response::success($stmt->fetchAll());
    }

    // PUT /notifications/mark-read
    public function markRead(): void {
        $auth   = AuthMiddleware::authenticate();
        $data   = Response::body();
        $userId = $auth['sub'];
        $notifId= $data['notification_id'] ?? null;

        if ($notifId) {
            $this->db->prepare("UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?")
                     ->execute([$notifId, $userId]);
        } else {
            $this->db->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = ?")
                     ->execute([$userId]);
        }

        Response::success([], 'Marked as read');
    }

    // POST /notifications/save-token  (Register Driver FCM Token + Device Info)
    public function saveToken(): void {
        $auth        = AuthMiddleware::authenticate();
        $data        = Response::body();
        $fcmToken    = trim($data['fcm_token'] ?? '');
        $deviceModel = trim($data['device_model'] ?? 'Android Device');
        $deviceOs    = trim($data['device_os'] ?? 'Android');
        $appVersion  = trim($data['app_version'] ?? '1.0.0');

        if (!$fcmToken) Response::error('FCM device token is required', 400);

        // Update single token on users table
        $this->db->prepare("UPDATE users SET fcm_token = ? WHERE id = ?")
                 ->execute([$fcmToken, $auth['sub']]);

        // Insert or update in driver_device_tokens table for multi-device support
        $stmt = $this->db->prepare("
            INSERT INTO driver_device_tokens (driver_id, fcm_token, device_model, device_os, app_version, is_active, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, 1, NOW(), NOW())
            ON DUPLICATE KEY UPDATE 
                device_model = VALUES(device_model),
                device_os    = VALUES(device_os),
                app_version  = VALUES(app_version),
                is_active    = 1,
                updated_at   = NOW()
        ");
        $stmt->execute([$auth['sub'], $fcmToken, $deviceModel, $deviceOs, $appVersion]);

        Response::success([
            'driver_id'    => (int)$auth['sub'],
            'device_model' => $deviceModel,
            'fcm_token'    => $fcmToken,
            'is_active'    => true
        ], 'Driver FCM device token registered successfully');
    }

    // POST /notifications/remove-token  (Deactivate token on Logout)
    public function removeToken(): void {
        $auth     = AuthMiddleware::authenticate();
        $data     = Response::body();
        $fcmToken = trim($data['fcm_token'] ?? '');

        if ($fcmToken) {
            $this->db->prepare("UPDATE driver_device_tokens SET is_active = 0 WHERE driver_id = ? AND fcm_token = ?")
                     ->execute([$auth['sub'], $fcmToken]);
        } else {
            $this->db->prepare("UPDATE driver_device_tokens SET is_active = 0 WHERE driver_id = ?")
                     ->execute([$auth['sub']]);
        }

        Response::success([], 'Driver device token deactivated');
    }
}
