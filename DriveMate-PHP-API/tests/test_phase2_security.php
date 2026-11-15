<?php
/**
 * test_phase2_security.php
 * Automated End-to-End Verification Test Suite for Phase 2:
 * PHP Backend Security, Database Schema Correction, and Quality Gate Verification.
 */

require_once __DIR__ . '/../vendor/autoload.php';
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__ . '/..');
$dotenv->load();

date_default_timezone_set($_ENV['APP_TIMEZONE'] ?? 'Asia/Kolkata');

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/JwtHelper.php';

$baseUrl = 'http://localhost/drivemate-api';
$db = Database::getInstance();

$totalTests = 0;
$passedTests = 0;
$failedTests = 0;

function runTest(string $testId, string $description, callable $fn): void {
    global $totalTests, $passedTests, $failedTests;
    $totalTests++;
    try {
        $result = $fn();
        if ($result['pass']) {
            $passedTests++;
            echo "[$testId] $description ... PASS ({$result['reason']})\n";
        } else {
            $failedTests++;
            echo "[$testId] $description ... FAIL: {$result['reason']}\n";
        }
    } catch (Throwable $e) {
        $failedTests++;
        echo "[$testId] $description ... EXCEPTION: {$e->getMessage()}\n";
    }
}

function apiRequest(string $method, string $path, array $data = [], ?string $jwt = null): array {
    global $baseUrl;
    $url = $baseUrl . $path;
    $ch = curl_init($url);
    $headers = ['Content-Type: application/json'];
    if ($jwt) {
        $headers[] = "Authorization: Bearer $jwt";
    }
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    if (!empty($data) && in_array($method, ['POST', 'PUT', 'DELETE'])) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    }
    $res = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    $json = json_decode($res, true) ?: [];
    return ['code' => $code, 'body' => $json, 'raw' => $res];
}

// Generate tokens for genuine test users
$jwtCustomerA = JwtHelper::encode(['sub' => 2, 'role' => 'customer', 'email' => 'customer@drivemate.com', 'exp' => time() + 3600]);
$jwtCustomerB = JwtHelper::encode(['sub' => 5, 'role' => 'customer', 'email' => 'amit@example.com', 'exp' => time() + 3600]);
$jwtDriverA   = JwtHelper::encode(['sub' => 3, 'role' => 'driver',   'email' => 'driver@drivemate.com', 'exp' => time() + 3600]);
$jwtAdmin     = JwtHelper::encode(['sub' => 1, 'role' => 'admin',    'email' => 'admin@drivemate.com', 'exp' => time() + 3600]);

echo "====================================================================\n";
echo "   DRIVEMATE PHASE 2: BACKEND SECURITY & INTEGRITY TEST SUITE       \n";
echo "====================================================================\n\n";

// --- GROUP 1: Driver ID Fallback Elimination ---
echo "--- GROUP 1: Identity Fallback & Driver ID 3 Elimination ---\n";

runTest('DRV-FALLBACK-01', 'Booking hire_driver without selecting driver leaves driver_id null (no fallback to 3)', function() use ($jwtCustomerA, $db) {
    $res = apiRequest('POST', '/bookings/create', [
        'type'            => 'hire_driver',
        'pickup_location' => 'Salt Lake Sector V',
        'destination'     => 'Howrah Station',
        'total_amount'    => 500.00
    ], $jwtCustomerA);

    $bookingId = $res['body']['data']['booking_id'] ?? 0;
    $stmt = $db->prepare("SELECT driver_id, status FROM bookings WHERE id = ?");
    $stmt->execute([$bookingId]);
    $row = $stmt->fetch();

    $pass = ($res['code'] === 201 && $row && $row['driver_id'] === null && $row['status'] === 'pending');
    return ['pass' => $pass, 'reason' => "driver_id is " . var_export($row['driver_id'] ?? false, true) . ", status='{$row['status']}'"];
});

runTest('DRV-FALLBACK-02', 'Reject booking creation with non-existent or inactive driver_id', function() use ($jwtCustomerA) {
    $res = apiRequest('POST', '/bookings/create', [
        'type'            => 'hire_driver',
        'driver_id'       => 99999, // Non-existent driver
        'pickup_location' => 'Airport Gate 1',
        'destination'     => 'Digha Beach',
        'total_amount'    => 2500.00
    ], $jwtCustomerA);

    $pass = ($res['code'] === 400);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, response: " . ($res['body']['message'] ?? '')];
});

runTest('DRV-FALLBACK-03', 'Driver hiring endpoint rejects missing driver_id instead of defaulting to 3', function() use ($jwtCustomerA) {
    $res = apiRequest('POST', '/driver-hiring/booking', [
        'hiring_type'     => 'one_way',
        'pickup_location' => 'Kakdwip Station',
        'destination'     => 'Lot 8 Ghat',
        'distance_km'     => 15.0,
        'duration_minutes'=> 30
        // Notice: driver_id omitted!
    ], $jwtCustomerA);

    $pass = ($res['code'] === 400);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, response: " . ($res['body']['message'] ?? '')];
});

// --- GROUP 2: Unauthenticated Profile & Language Tampering Prevention ---
echo "\n--- GROUP 2: Unauthenticated Profile & Language Tampering Prevention ---\n";

runTest('USER-TAMPER-01', 'Unauthenticated request cannot tamper with other user preferred language via body user_id', function() use ($db) {
    $origLang = $db->query("SELECT preferred_language FROM users WHERE id = 1")->fetchColumn();

    // Attacker sends request trying to change user 1's language to 'ur'
    $res = apiRequest('POST', '/users/set-language', [
        'user_id'  => 1,
        'language' => 'ur'
    ], null); // No JWT

    $afterLang = $db->query("SELECT preferred_language FROM users WHERE id = 1")->fetchColumn();
    $pass = ($origLang === $afterLang && $afterLang !== 'ur');
    return ['pass' => $pass, 'reason' => "User 1 language remained '$afterLang' (tamper blocked)"];
});

runTest('USER-TAMPER-02', 'Authenticated user can update their own language preference', function() use ($jwtCustomerA, $db) {
    $res = apiRequest('POST', '/users/set-language', [
        'language' => 'bn'
    ], $jwtCustomerA);

    $savedLang = $db->query("SELECT preferred_language FROM users WHERE id = 2")->fetchColumn();
    // Revert back to en
    $db->prepare("UPDATE users SET preferred_language = 'en' WHERE id = 2")->execute();

    $pass = ($res['code'] === 200 && $savedLang === 'bn');
    return ['pass' => $pass, 'reason' => "User 2 language updated to '$savedLang'"];
});

// --- GROUP 3: Password Reset OTP Security & Honest SMS Status ---
echo "\n--- GROUP 3: Password Reset OTP Security & Honest SMS Status ---\n";

runTest('SMS-HONEST-01', 'Forgot password reports carrier unconfirmed status when SMS gateway is unconfigured', function() use ($db) {
    $res = apiRequest('POST', '/auth/forgot-password', [
        'phone' => '9876543210' // User 2 phone
    ]);

    $sent = $res['body']['data']['sent'] ?? null;
    $msg  = $res['body']['message'] ?? '';
    $pass = ($res['code'] === 200 && $sent === false && strpos($msg, 'SMS delivery could not be confirmed') !== false);
    return ['pass' => $pass, 'reason' => "sent=" . var_export($sent, true) . ", msg='$msg'"];
});

runTest('RESET-OTP-01', 'Increment attempt counter and lock password reset after 5 invalid attempts', function() use ($db) {
    $testPhone = '9876543210';
    // Clear and insert an active OTP record
    $db->prepare("DELETE FROM otp_verifications WHERE phone = ?")->execute([$testPhone]);
    $db->prepare("
        INSERT INTO otp_verifications (phone, otp, expires_at, attempts, last_sent_at)
        VALUES (?, '654321', DATE_ADD(NOW(), INTERVAL 15 MINUTE), 0, NOW())
    ")->execute([$testPhone]);

    // Make 4 incorrect attempts
    for ($i = 1; $i <= 4; $i++) {
        $res = apiRequest('POST', '/auth/reset-password', [
            'phone'        => $testPhone,
            'otp'          => '000000',
            'new_password' => 'newSecretPass123'
        ]);
        if ($res['code'] !== 401) {
            return ['pass' => false, 'reason' => "Attempt $i returned code {$res['code']} instead of 401"];
        }
    }

    // 5th incorrect attempt -> locks and invalidates OTP
    $res5 = apiRequest('POST', '/auth/reset-password', [
        'phone'        => $testPhone,
        'otp'          => '000000',
        'new_password' => 'newSecretPass123'
    ]);

    // 6th attempt -> rejected with 404 or 429
    $res6 = apiRequest('POST', '/auth/reset-password', [
        'phone'        => $testPhone,
        'otp'          => '654321', // Even correct OTP now fails
        'new_password' => 'newSecretPass123'
    ]);

    $pass = ($res6['code'] === 404 || $res6['code'] === 429);
    return ['pass' => $pass, 'reason' => "After 5 failed attempts, 6th attempt returned HTTP {$res6['code']}"];
});

// --- GROUP 4: Server-Side Fare & Negotiation Bounds Validation ---
echo "\n--- GROUP 4: Server-Side Fare & Negotiation Bounds Validation ---\n";

$testNegBookingId = 0;
runTest('FARE-BOUND-01', 'Reject negotiation offer below absolute floor (e.g. ₹10.00)', function() use ($jwtCustomerA, &$testNegBookingId) {
    // Create booking for ₹500
    $bRes = apiRequest('POST', '/bookings/create', [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'pickup_location' => 'Kolkata Airport',
        'destination'     => 'Howrah Station',
        'total_amount'    => 500.00
    ], $jwtCustomerA);
    $testNegBookingId = (int)($bRes['body']['data']['booking_id'] ?? 0);

    // Attempt to offer ₹10 on a ₹500 ride
    $res = apiRequest('POST', '/negotiation/offer', [
        'booking_id'   => $testNegBookingId,
        'offered_fare' => 10.00
    ], $jwtCustomerA);

    $pass = ($res['code'] === 400);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, msg: " . ($res['body']['message'] ?? '')];
});

runTest('FARE-BOUND-02', 'Reject negotiation offer that exceeds maximum ceiling (> ₹50,000)', function() use ($jwtCustomerA, &$testNegBookingId) {
    $res = apiRequest('POST', '/negotiation/offer', [
        'booking_id'   => $testNegBookingId,
        'offered_fare' => 999999.00
    ], $jwtCustomerA);

    $pass = ($res['code'] === 400);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, msg: " . ($res['body']['message'] ?? '')];
});

runTest('FARE-BOUND-03', 'Reject counter-offer below minimum threshold or excessive lowball', function() use ($jwtCustomerA, $jwtDriverA, &$testNegBookingId) {
    // Valid initial offer of ₹450 (90% of ₹500)
    $resOffer = apiRequest('POST', '/negotiation/offer', [
        'booking_id'   => $testNegBookingId,
        'offered_fare' => 450.00
    ], $jwtCustomerA);

    // Driver counters with ₹20 (lowball)
    $resCounter = apiRequest('POST', '/negotiation/respond', [
        'booking_id'   => $testNegBookingId,
        'action'       => 'counter',
        'counter_fare' => 20.00
    ], $jwtDriverA);

    $pass = ($resCounter['code'] === 400);
    return ['pass' => $pass, 'reason' => "HTTP {$resCounter['code']}, msg: " . ($resCounter['body']['message'] ?? '')];
});

// --- GROUP 5: Payment Ownership & Amount Validation ---
echo "\n--- GROUP 5: Payment Ownership & Amount Validation ---\n";

$testPayBookingId = 0;
runTest('PAY-VALID-01', 'Reject customer B initiating payment for customer A booking', function() use ($jwtCustomerA, $jwtCustomerB, &$testPayBookingId) {
    // Customer A creates booking for ₹450
    $bRes = apiRequest('POST', '/bookings/create', [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'pickup_location' => 'Park Circus',
        'destination'     => 'Esplanade',
        'total_amount'    => 450.00
    ], $jwtCustomerA);
    $testPayBookingId = (int)($bRes['body']['data']['booking_id'] ?? 0);

    // Customer B attempts to create order on Customer A booking
    $res = apiRequest('POST', '/payments/create-order', [
        'booking_id'     => $testPayBookingId,
        'amount'         => 450.00,
        'payment_method' => 'cash'
    ], $jwtCustomerB);

    $pass = ($res['code'] === 403);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, msg: " . ($res['body']['message'] ?? '')];
});

runTest('PAY-VALID-02', 'Reject payment initiation when amount is below agreed fare', function() use ($jwtCustomerA, &$testPayBookingId) {
    // Customer A attempts to create payment order for ₹50 instead of ₹450
    $res = apiRequest('POST', '/payments/create-order', [
        'booking_id'     => $testPayBookingId,
        'amount'         => 50.00,
        'payment_method' => 'cash'
    ], $jwtCustomerA);

    $pass = ($res['code'] === 400);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, msg: " . ($res['body']['message'] ?? '')];
});

runTest('PAY-VALID-03', 'Reject refund by customer when booking is not cancelled', function() use ($jwtCustomerA, &$testPayBookingId, $db) {
    // Mark booking as paid and confirmed
    $db->prepare("UPDATE bookings SET payment_status = 'paid', status = 'confirmed' WHERE id = ?")->execute([$testPayBookingId]);
    $db->prepare("
        INSERT INTO payments (booking_id, user_id, amount, payment_method, transaction_id, status, paid_at, created_at)
        VALUES (?, 2, 450.00, 'wallet', 'TX_TEST_REF', 'paid', NOW(), NOW())
    ")->execute([$testPayBookingId]);

    // Customer attempts refund on confirmed (not cancelled) booking
    $res = apiRequest('POST', '/payments/refund', [
        'booking_id' => $testPayBookingId
    ], $jwtCustomerA);

    $pass = ($res['code'] === 400);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, msg: " . ($res['body']['message'] ?? '')];
});

runTest('PAY-VALID-04', 'Allow refund once booking is officially cancelled', function() use ($jwtCustomerA, &$testPayBookingId, $db) {
    // Mark booking as cancelled
    $db->prepare("UPDATE bookings SET status = 'cancelled' WHERE id = ?")->execute([$testPayBookingId]);

    $res = apiRequest('POST', '/payments/refund', [
        'booking_id' => $testPayBookingId,
        'to_wallet'  => true
    ], $jwtCustomerA);

    $pass = ($res['code'] === 200 && ($res['body']['data']['status'] ?? '') === 'refunded');
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, status=" . ($res['body']['data']['status'] ?? '')];
});

// --- GROUP 6: Trip Location & Status History Authorization ---
echo "\n--- GROUP 6: Trip Location & Status History Authorization ---\n";

$testTripId = 3; // Existing ongoing trip in DB: booking_id=9, driver_id=3, customer_id=2
runTest('TRIP-AUTH-01', 'Third-party user cannot track live GPS location of unrelated trip', function() use ($jwtCustomerB, $testTripId) {
    $res = apiRequest('GET', "/trips/live-location?trip_id=$testTripId", [], $jwtCustomerB);

    $pass = ($res['code'] === 403);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, msg: " . ($res['body']['message'] ?? '')];
});

runTest('TRIP-AUTH-02', 'Assigned customer can track live GPS location of their trip', function() use ($jwtCustomerA, $testTripId) {
    $res = apiRequest('GET', "/trips/live-location?trip_id=$testTripId", [], $jwtCustomerA);

    $pass = ($res['code'] === 200 && isset($res['body']['data']['status']));
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, coords retrieved"];
});

runTest('TRIP-AUTH-03', 'Third-party user cannot view status history of unrelated trip', function() use ($jwtCustomerB, $testTripId) {
    $res = apiRequest('GET', "/trips/status-history?trip_id=$testTripId", [], $jwtCustomerB);

    $pass = ($res['code'] === 403);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, msg: " . ($res['body']['message'] ?? '')];
});

// --- GROUP 7: Booking Cancellation Authorization ---
echo "\n--- GROUP 7: Booking Cancellation Authorization ---\n";

$testCancelBookingId = 0;
runTest('CANCEL-AUTH-01', 'Reject customer B attempting to cancel customer A booking', function() use ($jwtCustomerA, $jwtCustomerB, &$testCancelBookingId) {
    $bRes = apiRequest('POST', '/bookings/create', [
        'type'            => 'hire_driver',
        'driver_id'       => 3,
        'pickup_location' => 'Park Circus',
        'destination'     => 'Esplanade',
        'total_amount'    => 400.00
    ], $jwtCustomerA);
    $testCancelBookingId = (int)($bRes['body']['data']['booking_id'] ?? 0);

    // Customer B attempts to cancel Customer A booking
    $res = apiRequest('PUT', '/bookings/cancel', [
        'booking_id' => $testCancelBookingId
    ], $jwtCustomerB);

    $pass = ($res['code'] === 403);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, msg: " . ($res['body']['message'] ?? '')];
});

runTest('CANCEL-AUTH-02', 'Allow Customer A to cancel their own pending/confirmed booking', function() use ($jwtCustomerA, &$testCancelBookingId) {
    $res = apiRequest('PUT', '/bookings/cancel', [
        'booking_id' => $testCancelBookingId
    ], $jwtCustomerA);

    $pass = ($res['code'] === 200 && ($res['body']['data']['status'] ?? '') === 'cancelled');
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, status=" . ($res['body']['data']['status'] ?? '')];
});

runTest('CANCEL-AUTH-03', 'Reject cancellation when booking is already ongoing or completed', function() use ($jwtCustomerA, $db) {
    // Find an ongoing booking (e.g. booking 9)
    $ongoingId = (int)$db->query("SELECT id FROM bookings WHERE status = 'ongoing' LIMIT 1")->fetchColumn();

    $res = apiRequest('PUT', '/bookings/cancel', [
        'booking_id' => $ongoingId
    ], $jwtCustomerA);

    $pass = ($res['code'] === 400);
    return ['pass' => $pass, 'reason' => "HTTP {$res['code']}, msg: " . ($res['body']['message'] ?? '')];
});

// --- GROUP 8: Database Integrity & Indexes Verification ---
echo "\n--- GROUP 8: Database Integrity & Schema Indexes ---\n";

runTest('DB-INDEX-01', 'Confirm performance indexes exist on bookings, trips, payments, support_tickets', function() use ($db) {
    $checkIndex = function(string $table, string $indexName) use ($db): bool {
        $stmt = $db->query("SHOW INDEX FROM `$table` WHERE Key_name = '$indexName'");
        return ($stmt->fetch() !== false);
    };

    $idx1 = $checkIndex('bookings', 'idx_bookings_status');
    $idx2 = $checkIndex('trips', 'idx_trips_driver_status');
    $idx3 = $checkIndex('payments', 'idx_payments_status');
    $idx4 = $checkIndex('support_tickets', 'idx_support_status');
    $idx5 = $checkIndex('notifications', 'idx_notif_user_read');

    $allPresent = ($idx1 && $idx2 && $idx3 && $idx4 && $idx5);
    return ['pass' => $allPresent, 'reason' => "idx1=$idx1, idx2=$idx2, idx3=$idx3, idx4=$idx4, idx5=$idx5"];
});

runTest('DB-INTEG-01', 'Confirm start_otp column in bookings has NULL default (no lingering 4821)', function() use ($db) {
    $stmt = $db->query("SHOW COLUMNS FROM bookings LIKE 'start_otp'");
    $col = $stmt->fetch();

    $pass = ($col && $col['Default'] === null);
    return ['pass' => $pass, 'reason' => "start_otp default is " . var_export($col['Default'] ?? 'missing', true)];
});

// Final Summary
echo "\n====================================================================\n";
echo "   PHASE 2 TEST SUMMARY: Total: $totalTests | PASS: $passedTests | FAIL: $failedTests\n";
echo "====================================================================\n";

if ($failedTests > 0) {
    exit(1);
}
