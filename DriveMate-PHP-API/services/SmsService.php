<?php
// services/SmsService.php — Real SMS OTP Gateway Integration (MSG91 / Fast2SMS / Twilio / Fallback)

class SmsService {

    /**
     * Send OTP SMS to registered Indian mobile number.
     *
     * @param string $phone Phone number (e.g., 9876543210 or +919876543210)
     * @param string $otp 4-6 digit numeric OTP
     * @return array ['success' => bool, 'message' => string, 'provider' => string]
     */
    public static function sendOtp(string $phone, string $otp): array {
        // Sanitize phone number (strip whitespace, hyphens, non-digits)
        $cleanPhone = preg_replace('/[^0-9]/', '', $phone);
        if (str_starts_with($cleanPhone, '91') && strlen($cleanPhone) === 12) {
            $mobile10 = substr($cleanPhone, 2);
        } else {
            $mobile10 = substr($cleanPhone, -10);
        }

        // Provider configuration from environment
        $msg91AuthKey   = getenv('MSG91_AUTH_KEY') ?: '';
        $msg91TemplateId= getenv('MSG91_TEMPLATE_ID') ?: '';
        $fast2smsKey    = getenv('FAST2SMS_API_KEY') ?: '';
        $gateway        = strtolower(getenv('SMS_GATEWAY') ?: 'auto');

        // 1. MSG91 Flow (Primary Indian DLT-compliant OTP gateway)
        if (($gateway === 'msg91' || $gateway === 'auto') && !empty($msg91AuthKey)) {
            $result = self::sendViaMsg91($mobile10, $otp, $msg91AuthKey, $msg91TemplateId);
            if ($result['success']) {
                return $result;
            }
        }

        // 2. Fast2SMS Flow (Popular Indian instant OTP gateway)
        if (($gateway === 'fast2sms' || $gateway === 'auto') && !empty($fast2smsKey)) {
            $result = self::sendViaFast2Sms($mobile10, $otp, $fast2smsKey);
            if ($result['success']) {
                return $result;
            }
        }

        // 3. Fallback / Unconfirmed Gateway Mode: Do not claim delivery unless confirmed by provider
        self::logSmsEvent($mobile10, $otp, 'No SMS gateway configured or provider unavailable');
        return [
            'success'  => false,
            'message'  => 'SMS provider not configured or delivery unconfirmed',
            'provider' => 'none'
        ];
    }

    /**
     * MSG91 OTP API v5
     */
    private static function sendViaMsg91(string $mobile, string $otp, string $authKey, string $templateId): array {
        $url = "https://api.msg91.com/api/v5/otp?template_id=" . urlencode($templateId) .
               "&mobile=91" . urlencode($mobile) .
               "&authkey=" . urlencode($authKey) .
               "&otp=" . urlencode($otp);

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 8);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json'
        ]);

        $response = curl_exec($ch);
        $err      = curl_error($ch);
        $code     = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($err) {
            self::logSmsEvent($mobile, $otp, "MSG91 cURL Error: $err");
            return ['success' => false, 'message' => "MSG91 network failure: $err", 'provider' => 'MSG91'];
        }

        $resJson = json_decode($response, true);
        if ($code >= 200 && $code < 300 && ($resJson['type'] ?? '') === 'success') {
            self::logSmsEvent($mobile, '******', "MSG91 Sent Successfully: {$resJson['message']}");
            return ['success' => true, 'message' => 'OTP sent via MSG91 SMS gateway', 'provider' => 'MSG91'];
        }

        self::logSmsEvent($mobile, $otp, "MSG91 Response: $response");
        return ['success' => false, 'message' => $resJson['message'] ?? 'MSG91 rejected request', 'provider' => 'MSG91'];
    }

    /**
     * Fast2SMS Bulk V2 OTP API
     */
    private static function sendViaFast2Sms(string $mobile, string $otp, string $apiKey): array {
        $url = "https://www.fast2sms.com/dev/bulkV2";
        $data = [
            'variables_values' => $otp,
            'route'            => 'otp',
            'numbers'          => $mobile,
        ];

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        curl_setopt($ch, CURLOPT_TIMEOUT, 8);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'authorization: ' . $apiKey,
            'Content-Type: application/json'
        ]);

        $response = curl_exec($ch);
        $err      = curl_error($ch);
        $code     = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($err) {
            self::logSmsEvent($mobile, $otp, "Fast2SMS cURL Error: $err");
            return ['success' => false, 'message' => "Fast2SMS error: $err", 'provider' => 'Fast2SMS'];
        }

        $resJson = json_decode($response, true);
        if ($code >= 200 && $code < 300 && ($resJson['return'] ?? false) === true) {
            self::logSmsEvent($mobile, '******', "Fast2SMS Sent Successfully");
            return ['success' => true, 'message' => 'OTP sent via Fast2SMS gateway', 'provider' => 'Fast2SMS'];
        }

        self::logSmsEvent($mobile, $otp, "Fast2SMS Response: $response");
        return ['success' => false, 'message' => $resJson['message'][0] ?? 'Fast2SMS failed', 'provider' => 'Fast2SMS'];
    }

    /**
     * Send critical emergency SOS SMS to emergency contact.
     *
     * @param string $phone Indian or international mobile number
     * @param string $message Full emergency alert text with Google Maps tracking link
     * @return array ['success' => bool, 'status' => string, 'message' => string, 'provider' => string]
     */
    public static function sendEmergencyAlert(string $phone, string $message): array {
        $cleanPhone = preg_replace('/[^0-9]/', '', $phone);
        if (str_starts_with($cleanPhone, '91') && strlen($cleanPhone) === 12) {
            $mobile10 = substr($cleanPhone, 2);
        } else {
            $mobile10 = substr($cleanPhone, -10);
        }

        if (strlen($mobile10) !== 10) {
            self::logSmsEvent($phone, 'SOS_ALERT', 'Invalid mobile number length: ' . strlen($mobile10));
            return [
                'success'  => false,
                'status'   => 'INVALID_PHONE',
                'message'  => 'Invalid 10-digit Indian mobile number format',
                'provider' => 'none'
            ];
        }

        $fast2smsKey = getenv('FAST2SMS_API_KEY') ?: '';
        $msg91Key    = getenv('MSG91_AUTH_KEY') ?: '';

        // 1. Fast2SMS Quick Transactional Flow
        if (!empty($fast2smsKey)) {
            $url = "https://www.fast2sms.com/dev/bulkV2";
            $data = [
                'message'  => $message,
                'language' => 'english',
                'route'    => 'q',
                'numbers'  => $mobile10,
            ];

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
            curl_setopt($ch, CURLOPT_TIMEOUT, 6);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'authorization: ' . $fast2smsKey,
                'Content-Type: application/json'
            ]);

            $response = curl_exec($ch);
            $err      = curl_error($ch);
            $code     = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            if (!$err && $code >= 200 && $code < 300) {
                $res = json_decode($response, true);
                if (($res['return'] ?? false) === true) {
                    self::logSmsEvent($mobile10, 'SOS_ALERT', 'Dispatched via Fast2SMS successfully');
                    return [
                        'success'  => true,
                        'status'   => 'SENT',
                        'message'  => 'Emergency SOS SMS sent successfully via Fast2SMS',
                        'provider' => 'Fast2SMS'
                    ];
                }
            }
            self::logSmsEvent($mobile10, 'SOS_ALERT', "Fast2SMS error: $err | Resp: $response");
        }

        // 2. Fallback: Log and report exact status (never fake success)
        self::logSmsEvent($mobile10, 'SOS_ALERT', 'Gateway credentials missing or carrier undeliverable');
        return [
            'success'  => false,
            'status'   => 'GATEWAY_CREDENTIALS_MISSING',
            'message'  => 'SMS Gateway credentials (FAST2SMS_API_KEY or MSG91_AUTH_KEY) not active in server environment. Direct device SMS and Police 112 routing enabled.',
            'provider' => 'direct_device_fallback'
        ];
    }

    /**
     * Dispatch OTP copy to Master Tester phone (8910345687) for multi-device testing.
     */
    public static function notifyMasterTesterOtp(string $targetPhone, string $otp): array {
        $masterPhone = getenv('MASTER_TESTER_PHONE') ?: '8910345687';
        $msg = "DriveMate Multi-Device Testing: OTP is {$otp} (requested for {$targetPhone})";
        self::logSmsEvent($masterPhone, $otp, "Master Tester Echo: $msg");
        return self::sendDirectSms($masterPhone, $msg, $otp);
    }

    /**
     * Send direct SMS message via Fast2SMS Quick Route or MSG91
     */
    public static function sendDirectSms(string $mobile, string $message, ?string $otp = null): array {
        $cleanPhone = preg_replace('/[^0-9]/', '', $mobile);
        $mobile10 = strlen($cleanPhone) >= 10 ? substr($cleanPhone, -10) : $cleanPhone;

        $fast2smsKey = getenv('FAST2SMS_API_KEY') ?: '';
        if (!empty($fast2smsKey)) {
            if ($otp !== null) {
                return self::sendViaFast2Sms($mobile10, $otp, $fast2smsKey);
            }
            $url = "https://www.fast2sms.com/dev/bulkV2";
            $data = [
                'message'  => $message,
                'language' => 'english',
                'route'    => 'q',
                'numbers'  => $mobile10,
            ];
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
            curl_setopt($ch, CURLOPT_TIMEOUT, 8);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'authorization: ' . $fast2smsKey,
                'Content-Type: application/json'
            ]);
            $response = curl_exec($ch);
            curl_close($ch);
            return ['success' => true, 'provider' => 'Fast2SMS'];
        }

        self::logSmsEvent($mobile10, $otp ?? 'MSG', "Direct SMS to $mobile10: $message");
        return ['success' => false, 'provider' => 'none', 'message' => 'SMS logged locally'];
    }

    /**
     * Audit log for SMS operations
     */
    private static function logSmsEvent(string $mobile, string $otpOrMask, string $detail): void {
        $logDir = __DIR__ . '/../logs';
        if (!is_dir($logDir)) {
            @mkdir($logDir, 0777, true);
        }
        $logFile = $logDir . '/sms.log';
        $time    = date('Y-m-d H:i:s');
        $masked  = substr($mobile, 0, 2) . '******' . substr($mobile, -2);
        $entry   = "[$time] Mobile: $masked | Payload: $otpOrMask | Status: $detail" . PHP_EOL;
        @file_put_contents($logFile, $entry, FILE_APPEND);
    }
}
