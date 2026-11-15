<?php
// tests/test_phase1_security.php — Comprehensive Live Verification Suite for Phase 1 Security Fixes

require_once __DIR__ . '/../vendor/autoload.php';
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();
date_default_timezone_set($_ENV['APP_TIMEZONE'] ?? 'Asia/Kolkata');

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/JwtHelper.php';

$baseUrl = 'http://localhost/drivemate-api';
$db = Database::getInstance();

echo "====================================================================\n";
echo "   DRIVEMATE PHASE 1: BACKEND SECURITY VERIFICATION TEST SUITE      \n";
echo "====================================================================\n\n";

$passCount = 0;
$failCount = 0;

function httpRequest(string $method, string $path, array $headers = [], ?array $body = null): array {
    global $baseUrl;
    $url = $baseUrl . $path;

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);

    $headerLines = ['Content-Type: application/json'];
    foreach ($headers as $k => $v) {
        $headerLines[] = "$k: $v";
    }
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headerLines);

    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    }

    $raw = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErr = curl_error($ch);
    curl_close($ch);

    $json = json_decode($raw, true) ?? [];
    return [
        'code' => $httpCode,
        'body' => $json,
        'raw'  => $raw,
        'err'  => $curlErr
    ];
}

function runTest(string $testId, string $desc, callable $fn): void {
    global $passCount, $failCount;
    echo "[$testId] $desc ... ";
    try {
        $result = $fn();
        if ($result['pass']) {
            echo "PASS (HTTP {$result['code']})\n";
            $passCount++;
        } else {
            echo "FAIL! (HTTP {$result['code']}) — {$result['reason']}\n";
            $failCount++;
        }
    } catch (Throwable $e) {
        echo "ERROR! " . $e->getMessage() . "\n";
        $failCount++;
    }
}

// Generate Genuine JWTs
$jwtAdmin = JwtHelper::encode(['sub' => 1, 'role' => 'admin', 'email' => 'admin@drivemate.com', 'exp' => time() + 3600]);
$jwtCustomerA = JwtHelper::encode(['sub' => 2, 'role' => 'customer', 'email' => 'customer@drivemate.com', 'exp' => time() + 3600]);
$jwtDriverA = JwtHelper::encode(['sub' => 3, 'role' => 'driver', 'email' => 'driver@drivemate.com', 'exp' => time() + 3600]);
$jwtCustomerB = JwtHelper::encode(['sub' => 5, 'role' => 'customer', 'email' => 'amit@example.com', 'exp' => time() + 3600]);
$jwtDriverB = JwtHelper::encode(['sub' => 9, 'role' => 'driver', 'email' => 'amitava.driver@drivemate.com', 'exp' => time() + 3600]);

// -----------------------------------------------------------------------------
// BUG-CRIT-01: Authentication Bypass Verification
// -----------------------------------------------------------------------------
echo "--- GROUP 1: BUG-CRIT-01 Authentication Bypass Tests ---\n";

runTest('AUTH-01', 'Reject request with no Authorization header on protected route', function() {
    $res = httpRequest('GET', '/users/profile');
    $pass = ($res['code'] === 401 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('AUTH-02', 'Reject request spoofing X-User-Role: admin and X-User-Id: 1 header', function() {
    $res = httpRequest('GET', '/users/profile', [
        'X-User-Role' => 'admin',
        'X-User-Id'   => '1'
    ]);
    $pass = ($res['code'] === 401 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('AUTH-03', 'Reject request spoofing user_role/user_id in POST body', function() {
    $res = httpRequest('POST', '/bookings/create', [], [
        'user_role'   => 'admin',
        'user_id'     => 1,
        'type'        => 'hire_driver',
        'total_amount'=> 500
    ]);
    $pass = ($res['code'] === 401 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('AUTH-04', 'Reject invalid or corrupted Bearer token signature', function() {
    $res = httpRequest('GET', '/users/profile', [
        'Authorization' => 'Bearer invalid.fake.token'
    ]);
    $pass = ($res['code'] === 401 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('AUTH-05', 'Allow legitimate user with valid Bearer JWT to access profile', function() use ($jwtCustomerA) {
    $res = httpRequest('GET', '/users/profile', [
        'Authorization' => "Bearer $jwtCustomerA"
    ]);
    $pass = ($res['code'] === 200 && ($res['body']['success'] ?? null) === true && ($res['body']['data']['id'] ?? 0) == 2);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('AUTH-06', 'Enforce RBAC: Customer token cannot access strictly Admin routes (/bookings/all)', function() use ($jwtCustomerA) {
    $res = httpRequest('GET', '/bookings/all', [
        'Authorization' => "Bearer $jwtCustomerA"
    ]);
    $pass = ($res['code'] === 403 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('AUTH-07', 'Enforce RBAC: Admin token can access strictly Admin routes (/bookings/all)', function() use ($jwtAdmin) {
    $res = httpRequest('GET', '/bookings/all', [
        'Authorization' => "Bearer $jwtAdmin"
    ]);
    $pass = ($res['code'] === 200 && ($res['body']['success'] ?? null) === true);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

// -----------------------------------------------------------------------------
// BUG-CRIT-02: Master OTP Bypass & Attempt Limits
// -----------------------------------------------------------------------------
echo "\n--- GROUP 2: BUG-CRIT-02 Master OTP Bypass & Attempt Limits Tests ---\n";

// Create a new booking for Customer A assigned to Driver A
$testBookingId = null;
$realOtp = null;

runTest('OTP-01', 'Create new booking with customer JWT; verify dynamic random OTP (no 4821 default)', function() use ($jwtCustomerA, &$testBookingId, &$realOtp, $db) {
    $res = httpRequest('POST', '/bookings/create', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'start_date'      => date('Y-m-d H:i:s'),
        'pickup_location' => 'Salt Lake Sector V, Kolkata',
        'pickup_lat'      => 22.5800,
        'pickup_lng'      => 88.4300,
        'destination'     => 'Park Street, Kolkata',
        'dest_lat'        => 22.5500,
        'dest_lng'        => 88.3500,
        'total_amount'    => 450.00,
        'start_otp'       => '4821' // Client attempts to force fixed 4821
    ]);

    $testBookingId = $res['body']['data']['booking_id'] ?? null;
    $returnedOtp   = $res['body']['data']['start_otp'] ?? null;

    // Check DB directly
    $stmt = $db->prepare("SELECT start_otp, start_otp_attempts FROM bookings WHERE id = ?");
    $stmt->execute([$testBookingId]);
    $row = $stmt->fetch();
    $realOtp = $row['start_otp'];

    $pass = ($res['code'] === 201 && $testBookingId > 0 && !empty($realOtp) && $realOtp !== '4821');
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "Server generated OTP '$realOtp' (ignored client '4821')"];
});

runTest('OTP-02', 'Reject legacy master OTP 4821 in /trips/verify-otp', function() use ($jwtDriverA, &$testBookingId) {
    $res = httpRequest('POST', '/trips/verify-otp', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id' => $testBookingId,
        'otp'        => '4821'
    ]);
    $pass = ($res['code'] === 400 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('OTP-03', 'Increment failed attempt counter on invalid OTP', function() use ($jwtDriverA, &$testBookingId, $db) {
    $res = httpRequest('POST', '/trips/verify-otp', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id' => $testBookingId,
        'otp'        => '0000'
    ]);

    $stmt = $db->prepare("SELECT start_otp_attempts FROM bookings WHERE id = ?");
    $stmt->execute([$testBookingId]);
    $attempts = (int)$stmt->fetchColumn();

    $pass = ($res['code'] === 400 && $attempts >= 2);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "Attempts counter in DB: $attempts"];
});

runTest('OTP-04', 'Lock booking after 5 failed verification attempts (HTTP 429)', function() use ($jwtDriverA, &$testBookingId, $db) {
    // Send 3 more failed attempts to reach >= 5
    for ($i = 0; $i < 3; $i++) {
        httpRequest('POST', '/trips/verify-otp', [
            'Authorization' => "Bearer $jwtDriverA"
        ], [
            'booking_id' => $testBookingId,
            'otp'        => '999' . $i
        ]);
    }
    // 6th attempt
    $res = httpRequest('POST', '/trips/verify-otp', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id' => $testBookingId,
        'otp'        => '1111'
    ]);
    $pass = ($res['code'] === 429 && strpos($res['body']['message'] ?? '', 'exceeded') !== false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

// Create fresh booking for successful verification & single-use consumption
$validBookingId = null;
$validOtp = null;

runTest('OTP-05', 'Verify valid booking OTP and consume it (single-use)', function() use ($jwtCustomerA, $jwtDriverA, &$validBookingId, &$validOtp, $db) {
    // 1. Create booking
    $bRes = httpRequest('POST', '/bookings/create', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'start_date'      => date('Y-m-d H:i:s'),
        'pickup_location' => 'Airport, Kolkata',
        'destination'     => 'Howrah, Kolkata',
        'total_amount'    => 600.00
    ]);
    $validBookingId = $bRes['body']['data']['booking_id'];
    $validOtp       = $bRes['body']['data']['start_otp'];

    // 2. Driver marks arrival
    httpRequest('POST', '/trips/arrived', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id' => $validBookingId
    ]);

    // 3. Driver enters correct OTP
    $vRes = httpRequest('POST', '/trips/verify-otp', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id' => $validBookingId,
        'otp'        => $validOtp
    ]);

    // Check DB: start_otp must be NULL and start_otp_verified_at set
    $stmt = $db->prepare("SELECT start_otp, start_otp_verified_at FROM bookings WHERE id = ?");
    $stmt->execute([$validBookingId]);
    $row = $stmt->fetch();

    $pass = ($vRes['code'] === 200 && empty($row['start_otp']) && !empty($row['start_otp_verified_at']));
    return ['pass' => $pass, 'code' => $vRes['code'], 'reason' => "start_otp consumed to NULL, verified_at=" . $row['start_otp_verified_at']];
});

runTest('OTP-06', 'Start trip successfully after OTP verification', function() use ($jwtDriverA, &$validBookingId) {
    $res = httpRequest('POST', '/trips/start', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id'      => $validBookingId,
        'start_latitude'  => 22.6500,
        'start_longitude' => 88.4400
    ]);
    $pass = ($res['code'] === 201 && ($res['body']['data']['status'] ?? '') === 'ongoing');
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

// Focused Verification: OTP Dynamic Expiry & Refresh Behavior
runTest('OTP-EXP-01', 'Immediate ride OTP expiry dynamically set to 30 minutes from creation', function() use ($jwtCustomerA, $db) {
    $res = httpRequest('POST', '/bookings/create', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'pickup_location' => 'Behala Chowrasta, Kolkata',
        'destination'     => 'Howrah Station, Kolkata',
        'total_amount'    => 400.00
    ]);
    $bId = $res['body']['data']['booking_id'];

    $stmt = $db->prepare("SELECT start_otp_expires_at FROM bookings WHERE id = ?");
    $stmt->execute([$bId]);
    $expiresAt = $stmt->fetchColumn();

    $diffMins = (strtotime($expiresAt) - time()) / 60;
    $pass = ($res['code'] === 201 && $diffMins >= 28 && $diffMins <= 32);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "Expires at: $expiresAt (in round(" . round($diffMins, 1) . " mins))"];
});

runTest('OTP-EXP-02', 'Scheduled ride OTP expiry dynamically set to 30 minutes AFTER scheduled pickup', function() use ($jwtCustomerA, $db) {
    $futureTime = date('Y-m-d H:i:s', time() + (4 * 3600)); // 4 hours in future
    $res = httpRequest('POST', '/bookings/create', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'start_date'      => $futureTime,
        'pickup_location' => 'New Town Action Area 1',
        'destination'     => 'Sealdah Station',
        'total_amount'    => 550.00
    ]);
    $bId = $res['body']['data']['booking_id'];

    $stmt = $db->prepare("SELECT start_otp_expires_at FROM bookings WHERE id = ?");
    $stmt->execute([$bId]);
    $expiresAt = $stmt->fetchColumn();

    $expectedExpiry = strtotime($futureTime) + (30 * 60);
    $diffSec = abs(strtotime($expiresAt) - $expectedExpiry);
    $pass = ($res['code'] === 201 && $diffSec <= 10);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "Scheduled: $futureTime | OTP Exp: $expiresAt"];
});

$expiredBookingId = null;
$expiredBookingOtp = null;
runTest('OTP-EXP-03', 'Reject expired OTP verification (HTTP 400 Expired)', function() use ($jwtCustomerA, $jwtDriverA, &$expiredBookingId, &$expiredBookingOtp, $db) {
    // Create booking
    $bRes = httpRequest('POST', '/bookings/create', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'pickup_location' => 'Jadavpur, Kolkata',
        'destination'     => 'Ruby General Hospital',
        'total_amount'    => 300.00
    ]);
    $expiredBookingId  = $bRes['body']['data']['booking_id'];
    $expiredBookingOtp = $bRes['body']['data']['start_otp'];

    // Mark arrived
    httpRequest('POST', '/trips/arrived', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id' => $expiredBookingId
    ]);

    // Force expire in DB: set start_otp_expires_at to 10 minutes ago
    $db->prepare("UPDATE bookings SET start_otp_expires_at = DATE_SUB(NOW(), INTERVAL 10 MINUTE) WHERE id = ?")
       ->execute([$expiredBookingId]);

    // Driver attempts to verify expired OTP
    $vRes = httpRequest('POST', '/trips/verify-otp', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id' => $expiredBookingId,
        'otp'        => $expiredBookingOtp
    ]);

    $pass = ($vRes['code'] === 400 && strpos($vRes['body']['message'] ?? '', 'expired') !== false);
    return ['pass' => $pass, 'code' => $vRes['code'], 'reason' => $vRes['raw']];
});

$refreshedOtp = null;
runTest('OTP-REF-01', 'Customer refreshes expired OTP via POST /bookings/refresh-otp', function() use ($jwtCustomerA, &$expiredBookingId, &$refreshedOtp, &$expiredBookingOtp, $db) {
    $res = httpRequest('POST', '/bookings/refresh-otp', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'booking_id' => $expiredBookingId
    ]);
    $refreshedOtp = $res['body']['data']['start_otp'] ?? null;

    $stmt = $db->prepare("SELECT start_otp, start_otp_attempts, start_otp_expires_at FROM bookings WHERE id = ?");
    $stmt->execute([$expiredBookingId]);
    $row = $stmt->fetch();

    $pass = ($res['code'] === 200 && !empty($refreshedOtp) && $refreshedOtp !== $expiredBookingOtp && $row['start_otp_attempts'] == 0);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "Fresh OTP: $refreshedOtp (Old: $expiredBookingOtp) | Attempts: {$row['start_otp_attempts']}"];
});

runTest('OTP-REF-02', 'Reject unauthorized Customer B attempting to refresh Customer A OTP (HTTP 403 Forbidden)', function() use ($jwtCustomerB, &$expiredBookingId) {
    $res = httpRequest('POST', '/bookings/refresh-otp', [
        'Authorization' => "Bearer $jwtCustomerB"
    ], [
        'booking_id' => $expiredBookingId
    ]);
    $pass = ($res['code'] === 403 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('OTP-REF-03', 'Driver cannot see refreshed OTP in GET /bookings/detail (Shielded from Driver)', function() use ($jwtDriverA, &$expiredBookingId) {
    $res = httpRequest('GET', "/bookings/detail?id=$expiredBookingId", [
        'Authorization' => "Bearer $jwtDriverA"
    ]);
    $hasOtp = isset($res['body']['data']['start_otp']);
    $pass = ($res['code'] === 200 && !$hasOtp);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "Driver payload start_otp present: " . ($hasOtp ? 'YES (FAIL)' : 'NO (SHIELDED)')];
});

runTest('OTP-REF-04', 'Customer DOES see refreshed OTP in GET /bookings/detail (Secure in-app receipt when SMS down)', function() use ($jwtCustomerA, &$expiredBookingId, &$refreshedOtp) {
    $res = httpRequest('GET', "/bookings/detail?id=$expiredBookingId", [
        'Authorization' => "Bearer $jwtCustomerA"
    ]);
    $custOtp = $res['body']['data']['start_otp'] ?? null;
    $pass = ($res['code'] === 200 && $custOtp === $refreshedOtp);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "Customer sees OTP '$custOtp' in-app over HTTPS"];
});

runTest('OTP-REF-05', 'Driver successfully verifies newly refreshed OTP and proceeds with ride', function() use ($jwtDriverA, &$expiredBookingId, &$refreshedOtp, $db) {
    $vRes = httpRequest('POST', '/trips/verify-otp', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id' => $expiredBookingId,
        'otp'        => $refreshedOtp
    ]);

    $stmt = $db->prepare("SELECT start_otp, start_otp_verified_at FROM bookings WHERE id = ?");
    $stmt->execute([$expiredBookingId]);
    $row = $stmt->fetch();

    $pass = ($vRes['code'] === 200 && empty($row['start_otp']) && !empty($row['start_otp_verified_at']));
    return ['pass' => $pass, 'code' => $vRes['code'], 'reason' => "Refreshed OTP verified and single-use consumed to NULL"];
});

// -----------------------------------------------------------------------------
// BUG-CRIT-03: Booking BOLA / IDOR Protection
// -----------------------------------------------------------------------------
echo "\n--- GROUP 3: BUG-CRIT-03 Booking BOLA / IDOR Protection Tests ---\n";

runTest('BOLA-01', 'Reject unauthorized Customer B accessing Customer A booking (HTTP 403 Forbidden)', function() use ($jwtCustomerB, &$validBookingId) {
    $res = httpRequest('GET', "/bookings/detail?id=$validBookingId", [
        'Authorization' => "Bearer $jwtCustomerB"
    ]);
    $pass = ($res['code'] === 403 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('BOLA-02', 'Allow Customer A to access their own booking (HTTP 200 OK)', function() use ($jwtCustomerA, &$validBookingId) {
    $res = httpRequest('GET', "/bookings/detail?id=$validBookingId", [
        'Authorization' => "Bearer $jwtCustomerA"
    ]);
    $pass = ($res['code'] === 200 && ($res['body']['data']['id'] ?? 0) == $validBookingId);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('BOLA-03', 'Allow assigned Driver A to view booking, but shield Ride OTP from response', function() use ($jwtDriverA, &$validBookingId) {
    $res = httpRequest('GET', "/bookings/detail?id=$validBookingId", [
        'Authorization' => "Bearer $jwtDriverA"
    ]);
    $hasOtp = isset($res['body']['data']['start_otp']);
    $pass = ($res['code'] === 200 && !$hasOtp);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "start_otp exposed: " . ($hasOtp ? 'YES (FAIL)' : 'NO (SHIELDED)')];
});

// -----------------------------------------------------------------------------
// BUG-CRIT-04: Fare Negotiation Authorization
// -----------------------------------------------------------------------------
echo "\n--- GROUP 4: BUG-CRIT-04 Fare Negotiation Authorization Tests ---\n";

$negBookingId = null;
runTest('NEG-01', 'Setup pending booking for negotiation test', function() use ($jwtCustomerA, &$negBookingId) {
    $res = httpRequest('POST', '/bookings/create', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'start_date'      => date('Y-m-d H:i:s'),
        'pickup_location' => 'New Town, Kolkata',
        'destination'     => 'Airport, Kolkata',
        'total_amount'    => 500.00,
        'negotiated_fare' => 450.00,
        'negotiation_status' => 'PENDING'
    ]);
    $negBookingId = $res['body']['data']['booking_id'] ?? null;
    $pass = ($res['code'] === 201 && $negBookingId > 0);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "Booking #$negBookingId"];
});

runTest('NEG-02', 'Reject third-party Customer B offering on Customer A booking (HTTP 403 Forbidden)', function() use ($jwtCustomerB, &$negBookingId) {
    $res = httpRequest('POST', '/negotiation/offer', [
        'Authorization' => "Bearer $jwtCustomerB"
    ], [
        'booking_id'   => $negBookingId,
        'offered_fare' => 380.00,
        'notes'        => 'Unauthorized intruder offer'
    ]);
    $pass = ($res['code'] === 403 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('NEG-03', 'Reject unassigned Driver B responding to offer on Customer A booking (HTTP 403 Forbidden)', function() use ($jwtDriverB, &$negBookingId) {
    $res = httpRequest('POST', '/negotiation/respond', [
        'Authorization' => "Bearer $jwtDriverB"
    ], [
        'booking_id'   => $negBookingId,
        'action'       => 'counter',
        'counter_fare' => 490.00
    ]);
    $pass = ($res['code'] === 403 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('NEG-04', 'Allow assigned Driver A to submit valid counter-offer on booking', function() use ($jwtDriverA, &$negBookingId) {
    $res = httpRequest('POST', '/negotiation/respond', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id'   => $negBookingId,
        'action'       => 'counter',
        'counter_fare' => 480.00,
        'notes'        => 'Driver counter-offer'
    ]);
    $pass = ($res['code'] === 200 && ($res['body']['data']['counter_fare'] ?? 0) == 480.00);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('NEG-05', 'Reject party responding to their own offer (Driver cannot accept own counter-offer)', function() use ($jwtDriverA, &$negBookingId) {
    $res = httpRequest('POST', '/negotiation/respond', [
        'Authorization' => "Bearer $jwtDriverA"
    ], [
        'booking_id'   => $negBookingId,
        'action'       => 'accept'
    ]);
    $pass = ($res['code'] === 400 && strpos($res['body']['message'] ?? '', 'own offer') !== false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

// -----------------------------------------------------------------------------
// BUG-CRIT-05: Payment Verification Bypass
// -----------------------------------------------------------------------------
echo "\n--- GROUP 5: BUG-CRIT-05 Payment Verification Bypass Tests ---\n";

$payBookingId = null;
$orderId = null;
$payAmount = 450.00;

runTest('PAY-01', 'Create order for payment verification test', function() use ($jwtCustomerA, &$payBookingId, &$orderId, $payAmount) {
    // 1. Create booking
    $bRes = httpRequest('POST', '/bookings/create', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'start_date'      => date('Y-m-d H:i:s'),
        'pickup_location' => 'Gariahat, Kolkata',
        'destination'     => 'Sealdah, Kolkata',
        'total_amount'    => $payAmount
    ]);
    $payBookingId = $bRes['body']['data']['booking_id'];

    // 2. Create online razorpay order
    $oRes = httpRequest('POST', '/payments/create-order', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'booking_id'     => $payBookingId,
        'amount'         => $payAmount,
        'payment_method' => 'razorpay'
    ]);
    $orderId = $oRes['body']['data']['order_id'] ?? null;

    $pass = ($oRes['code'] === 200 && !empty($orderId));
    return ['pass' => $pass, 'code' => $oRes['code'], 'reason' => "Order ID: $orderId"];
});

runTest('PAY-02', 'Reject payment verification with missing signature (HTTP 400)', function() use ($jwtCustomerA, &$orderId, &$payBookingId) {
    $res = httpRequest('POST', '/payments/verify', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'order_id'   => $orderId,
        'payment_id' => 'pay_1234567890',
        'booking_id' => $payBookingId
        // signature omitted
    ]);
    $pass = ($res['code'] === 400 && strpos($res['body']['message'] ?? '', 'signature') !== false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('PAY-03', 'Reject payment verification with invalid cryptographic signature', function() use ($jwtCustomerA, &$orderId, &$payBookingId) {
    $res = httpRequest('POST', '/payments/verify', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'order_id'   => $orderId,
        'payment_id' => 'pay_1234567890',
        'signature'  => 'fake_invalid_hex_signature_deadbeef',
        'booking_id' => $payBookingId
    ]);
    $pass = ($res['code'] === 400 && strpos($res['body']['message'] ?? '', 'signature') !== false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('PAY-04', 'Reject order_sb_ prefix bypass when signature is invalid (legacy bypass eliminated)', function() use ($jwtCustomerA, &$payBookingId) {
    $res = httpRequest('POST', '/payments/verify', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'order_id'   => 'order_sb_mock_fake_9999',
        'payment_id' => 'pay_mock_fake_8888',
        'signature'  => 'wrong_sig',
        'booking_id' => $payBookingId
    ]);
    $pass = ($res['code'] === 400);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('PAY-05', 'Accept payment verification with valid HMAC-SHA256 signature and credit driver', function() use ($jwtCustomerA, &$orderId, &$payBookingId, $db) {
    $paymentId = 'pay_' . bin2hex(random_bytes(8));
    $secret    = $_ENV['RAZORPAY_SECRET'] ?? 'drivemate_sandbox_secret_9876';
    $validSig  = hash_hmac('sha256', $orderId . '|' . $paymentId, $secret);

    // Initial driver earnings
    $stmt = $db->prepare("SELECT earnings, total_trips FROM driver_profile WHERE user_id = 3");
    $stmt->execute();
    $beforeDriver = $stmt->fetch();
    $earningsBefore = (float)($beforeDriver['earnings'] ?? 0);

    $res = httpRequest('POST', '/payments/verify', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'order_id'   => $orderId,
        'payment_id' => $paymentId,
        'signature'  => $validSig,
        'booking_id' => $payBookingId
    ]);

    // Check DB: payment must be paid, booking payment_status paid, driver credited
    $stmt = $db->prepare("SELECT payment_status FROM bookings WHERE id = ?");
    $stmt->execute([$payBookingId]);
    $bStatus = $stmt->fetchColumn();

    $stmt = $db->prepare("SELECT earnings FROM driver_profile WHERE user_id = 3");
    $stmt->execute();
    $earningsAfter = (float)$stmt->fetchColumn();

    $pass = ($res['code'] === 200 && $bStatus === 'paid' && $earningsAfter > $earningsBefore);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => "Booking payment_status: $bStatus, Earnings before: $earningsBefore, after: $earningsAfter"];
});

runTest('PAY-06', 'Reject duplicate payment verification on already paid booking (no replay attack)', function() use ($jwtCustomerA, &$orderId, &$payBookingId) {
    $paymentId = 'pay_' . bin2hex(random_bytes(8));
    $secret    = $_ENV['RAZORPAY_SECRET'] ?? 'drivemate_sandbox_secret_9876';
    $validSig  = hash_hmac('sha256', $orderId . '|' . $paymentId, $secret);

    $res = httpRequest('POST', '/payments/verify', [
        'Authorization' => "Bearer $jwtCustomerA"
    ], [
        'order_id'   => $orderId,
        'payment_id' => $paymentId,
        'signature'  => $validSig,
        'booking_id' => $payBookingId
    ]);

    $pass = ($res['code'] === 400 && strpos($res['body']['message'] ?? '', 'already') !== false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

runTest('PAY-07', 'Reject unauthorized user Customer B viewing Customer A invoice (HTTP 403 Forbidden)', function() use ($jwtCustomerB, &$payBookingId) {
    $res = httpRequest('GET', "/payments/invoice?booking_id=$payBookingId", [
        'Authorization' => "Bearer $jwtCustomerB"
    ]);
    $pass = ($res['code'] === 403 && ($res['body']['success'] ?? null) === false);
    return ['pass' => $pass, 'code' => $res['code'], 'reason' => $res['raw']];
});

echo "\n====================================================================\n";
echo "   TEST SUMMARY: Total: " . ($passCount + $failCount) . " | PASS: $passCount | FAIL: $failCount\n";
echo "====================================================================\n";

if ($failCount > 0) {
    exit(1);
}
exit(0);
