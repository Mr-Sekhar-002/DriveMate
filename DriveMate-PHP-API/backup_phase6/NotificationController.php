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

    // Send push notification & persist in-app notification record
    public static function sendPushToUser(
        int $userId,
        string $title,
        string $body,
        array $data = [],
        ?int $bookingId = null,
        string $eventType = 'booking_request'
    ): void {
        $db = Database::getInstance();

        // 1. Persist in-app notification record in MySQL
        $db->prepare("
            INSERT INTO notifications (user_id, booking_id, type, event_type, title, message, is_read, created_at)
            VALUES (?, ?, 'booking', ?, ?, ?, 0, NOW())
        ")->execute([$userId, $bookingId, $eventType, $title, $body]);

        // 2. Fetch all active device tokens for this recipient
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

        $serverKey = getenv('FIREBASE_SERVER_KEY') ?: ($_ENV['FIREBASE_SERVER_KEY'] ?? '');

        // Determine Android Notification Channel
        $channelId = in_array($eventType, ['driver_arrived', 'trip_started', 'trip_completed'])
            ? 'drivemate_trip_channel'
            : 'drivemate_booking_channel';

        // 3. If no tokens or no FCM server key configured, record queued log
        if (empty($tokens) || empty($serverKey)) {
            $note = empty($tokens)
                ? 'Recipient has no active FCM device token; in-app notification recorded'
                : 'FCM Server Key not configured; in-app notification recorded';
            $db->prepare("
                INSERT INTO notification_logs (recipient_user_id, booking_id, notification_type, title, body, status, response_code, error_message, sent_at)
                VALUES (?, ?, ?, ?, ?, 'queued', 200, ?, NOW())
            ")->execute([$userId, $bookingId, $eventType, $title, $body, $note]);
            return;
        }

        // 4. Dispatch Push via Firebase Cloud Messaging
        foreach ($tokens as $token) {
            $payload = [
                'to'                => $token,
                'priority'          => 'high',
                'content_available' => true,
                'notification'      => [
                    'title'                 => $title,
                    'body'                  => $body,
                    'sound'                 => 'default',
                    'android_channel_id'    => $channelId,
                    'channel_id'            => $channelId,
                    'click_action'          => 'FLUTTER_NOTIFICATION_CLICK',
                ],
                'data'              => array_merge($data, [
                    'event_type'    => $eventType,
                    'booking_id'    => (string)($bookingId ?? ''),
                    'channel_id'    => $channelId,
                    'click_action'  => 'FLUTTER_NOTIFICATION_CLICK'
                ]),
                'android'           => [
                    'priority'      => 'high',
                    'notification'  => [
                        'channel_id'    => $channelId,
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
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
            ")->execute([$userId, $bookingId, $eventType, $title, $body, $status, $httpCode, $errorMsg ?: null]);
        }
    }

    // Helper: Notify Customer that Driver accepted booking
    public static function notifyCustomerBookingAccepted(int $customerId, int $bookingId, string $driverName): void {
        $title = "Chauffeur Assigned!";
        $body  = "Chauffeur {$driverName} has accepted your booking #{$bookingId}. Tap to track.";
        self::sendPushToUser($customerId, $title, $body, [
            'booking_id' => (string)$bookingId,
            'driver_name'=> $driverName,
        ], $bookingId, 'booking_accepted');
    }

    // Helper: Notify Customer of Counter Offer or Driver of Customer Offer
    public static function notifyFareOffer(int $recipientId, int $bookingId, string $senderRole, float $offeredFare): void {
        $title = ($senderRole === 'driver') ? "Counter Offer Received" : "New Fare Offer Proposed";
        $body  = "A fare offer of ₹" . number_format($offeredFare, 2) . " was proposed for Booking #{$bookingId}. Tap to review.";
        self::sendPushToUser($recipientId, $title, $body, [
            'booking_id'   => (string)$bookingId,
            'offered_fare' => (string)$offeredFare,
            'sender_role'  => $senderRole,
        ], $bookingId, ($senderRole === 'driver' ? 'driver_counter_offer' : 'customer_fare_offer'));
    }

    // Helper: Notify Negotiation Agreed & Booking Confirmed
    public static function notifyBookingConfirmed(int $recipientId, int $bookingId, float $agreedFare): void {
        $title = "Booking Confirmed!";
        $body  = "Fare of ₹" . number_format($agreedFare, 2) . " agreed! Booking #{$bookingId} is confirmed.";
        self::sendPushToUser($recipientId, $title, $body, [
            'booking_id'  => (string)$bookingId,
            'agreed_fare' => (string)$agreedFare,
        ], $bookingId, 'booking_confirmed');
    }

    // Helper: Notify Driver Arrival
    public static function notifyDriverArrived(int $customerId, int $bookingId, string $driverName): void {
        $title = "Driver Arrived at Pickup";
        $body  = "Chauffeur {$driverName} has arrived at your pickup location for Booking #{$bookingId}.";
        self::sendPushToUser($customerId, $title, $body, [
            'booking_id' => (string)$bookingId,
            'driver_name'=> $driverName,
        ], $bookingId, 'driver_arrived');
    }

    // Helper: Notify Trip Started
    public static function notifyTripStarted(int $customerId, int $bookingId): void {
        $title = "Trip In Progress";
        $body  = "Your journey for Booking #{$bookingId} has commenced. Track your route in real time.";
        self::sendPushToUser($customerId, $title, $body, [
            'booking_id' => (string)$bookingId,
        ], $bookingId, 'trip_started');
    }

    // Helper: Notify Trip Completed & Invoice Ready
    public static function notifyTripCompleted(int $customerId, int $bookingId, float $fare): void {
        $title = "Trip Completed";
        $body  = "Your journey for Booking #{$bookingId} is complete. Total fare: ₹" . number_format($fare, 2) . ". Tap to view invoice & rate your driver.";
        self::sendPushToUser($customerId, $title, $body, [
            'booking_id' => (string)$bookingId,
            'final_fare' => (string)$fare,
        ], $bookingId, 'trip_completed');
    }

    // Helper: Notify Booking Cancellation
    public static function notifyBookingCancelled(int $recipientId, int $bookingId, string $cancelledBy, string $reason): void {
        $title = "Booking Cancelled";
        $body  = "Booking #{$bookingId} was cancelled by {$cancelledBy}." . ($reason ? " Reason: {$reason}" : "");
        self::sendPushToUser($recipientId, $title, $body, [
            'booking_id'   => (string)$bookingId,
            'cancelled_by' => $cancelledBy,
        ], $bookingId, 'booking_cancelled');
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
        $userId = (int)$auth['sub'];
        $notifId= isset($data['notification_id']) ? (int)$data['notification_id'] : null;

        if ($notifId) {
            // Verify ownership
            $check = $this->db->prepare("SELECT user_id FROM notifications WHERE id = ?");
            $check->execute([$notifId]);
            $owner = $check->fetchColumn();
            if ($owner === false) {
                Response::error('Notification not found', 404);
            }
            if ((int)$owner !== $userId) {
                Response::error('Forbidden: You are not authorized to mark another user\'s notification as read', 403);
            }

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
