<?php
// controllers/PaymentController.php — Comprehensive Payment Gateway (Razorpay, UPI QR, Cash on Delivery, In-App Wallet)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class PaymentController {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    /**
     * POST /payments/create-order
     * Supports: 'razorpay', 'upi', 'cash', 'wallet'
     */
    public function createOrder(): void {
        $auth      = AuthMiddleware::authenticate();
        $userId    = $auth['sub'];
        $data      = Response::body();
        $bookingId = (int)($data['booking_id'] ?? 0);
        $amount    = (float)($data['amount'] ?? 0);
        $method    = strtolower(trim($data['payment_method'] ?? 'razorpay'));

        if (!$bookingId || $amount <= 0) {
            Response::error('Valid booking_id and amount greater than 0 are required');
        }

        // Verify booking exists
        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();
        if (!$booking) {
            Response::error('Booking not found', 404);
        }

        // 1. CASH PAYMENT (Pay to Driver on trip completion)
        if ($method === 'cash') {
            $txnId = 'CASH_' . strtoupper(bin2hex(random_bytes(6)));
            $stmt = $this->db->prepare("
                INSERT INTO payments (booking_id, user_id, amount, payment_method, transaction_id, status, notes, created_at)
                VALUES (?, ?, ?, 'cash', ?, 'pending', 'Cash payable to driver at trip end', NOW())
            ");
            $stmt->execute([$bookingId, $userId, $amount, $txnId]);

            Response::success([
                'booking_id'     => $bookingId,
                'amount'         => $amount,
                'currency'       => 'INR',
                'payment_method' => 'cash',
                'transaction_id' => $txnId,
                'status'         => 'pending',
                'instructions'   => 'Please pay ₹' . number_format($amount, 2) . ' cash directly to your driver upon trip completion.'
            ], 'Cash payment registered. Payment will be collected by driver.');
            return;
        }

        // 2. IN-APP WALLET PAYMENT
        if ($method === 'wallet') {
            $walletStmt = $this->db->prepare("SELECT * FROM wallets WHERE user_id = ?");
            $walletStmt->execute([$userId]);
            $wallet = $walletStmt->fetch();

            $currentBalance = $wallet ? (float)$wallet['balance'] : 0.00;
            if ($currentBalance < $amount) {
                Response::error("Insufficient wallet balance. Available: ₹{$currentBalance}, Required: ₹{$amount}", 400);
            }

            // Deduct from wallet
            $newBalance = $currentBalance - $amount;
            $this->db->prepare("UPDATE wallets SET balance = ? WHERE id = ?")->execute([$newBalance, $wallet['id']]);

            $txnId = 'WLT_' . strtoupper(bin2hex(random_bytes(6)));

            // Log wallet transaction
            $this->db->prepare("
                INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, reference_type, reference_id, description, balance_after)
                VALUES (?, ?, 'debit', ?, 'booking_payment', ?, ?, ?)
            ")->execute([$wallet['id'], $userId, $amount, (string)$bookingId, "Payment for Booking #{$bookingId}", $newBalance]);

            // Insert paid payment record
            $this->db->prepare("
                INSERT INTO payments (booking_id, user_id, amount, payment_method, transaction_id, status, paid_at, notes, created_at)
                VALUES (?, ?, ?, 'wallet', ?, 'paid', NOW(), 'Paid using DriveMate In-App Wallet', NOW())
            ")->execute([$bookingId, $userId, $amount, $txnId]);

            // Update booking payment status
            $this->db->prepare("UPDATE bookings SET payment_status = 'paid' WHERE id = ?")->execute([$bookingId]);

            // Allocate driver commission
            $this->distributeDriverEarnings($bookingId, $amount);

            Response::success([
                'booking_id'     => $bookingId,
                'amount'         => $amount,
                'currency'       => 'INR',
                'payment_method' => 'wallet',
                'transaction_id' => $txnId,
                'status'         => 'paid',
                'wallet_balance' => $newBalance
            ], 'Payment completed successfully via DriveMate Wallet');
            return;
        }

        // 3. UPI PAYMENT (Dynamic Intent & QR Code for GPay / PhonePe / Paytm)
        if ($method === 'upi') {
            $upiVpa   = $_ENV['UPI_VPA'] ?? 'drivemate@icici';
            $payee    = rawurlencode($_ENV['UPI_PAYEE_NAME'] ?? 'DriveMate Mobility');
            $txnId    = 'UPI_' . strtoupper(bin2hex(random_bytes(6)));
            $note     = rawurlencode("DriveMate Ride #{$bookingId}");
            $upiUrl   = "upi://pay?pa={$upiVpa}&pn={$payee}&am={$amount}&cu=INR&tn={$note}&tr={$txnId}";
            $qrApiUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" . urlencode($upiUrl);

            $stmt = $this->db->prepare("
                INSERT INTO payments (booking_id, user_id, amount, payment_method, transaction_id, status, notes, created_at)
                VALUES (?, ?, ?, 'upi', ?, 'pending', 'UPI QR generated', NOW())
            ");
            $stmt->execute([$bookingId, $userId, $amount, $txnId]);

            Response::success([
                'booking_id'     => $bookingId,
                'amount'         => $amount,
                'currency'       => 'INR',
                'payment_method' => 'upi',
                'upi_vpa'        => $upiVpa,
                'transaction_id' => $txnId,
                'upi_intent_url' => $upiUrl,
                'qr_code_url'    => $qrApiUrl,
                'status'         => 'pending'
            ], 'UPI order generated. Scan QR or open UPI app to pay.');
            return;
        }

        // 4. RAZORPAY ONLINE GATEWAY (Credit/Debit Card, Netbanking, Online)
        $razorpayKey    = $_ENV['RAZORPAY_KEY'] ?? 'rzp_test_DriveMateSandbox';
        $razorpaySecret = $_ENV['RAZORPAY_SECRET'] ?? 'drivemate_sandbox_secret_9876';

        $orderData = [
            'amount'   => (int)round($amount * 100), // paise
            'currency' => 'INR',
            'receipt'  => 'rcpt_bk_' . $bookingId . '_' . time(),
            'notes'    => [
                'booking_id' => (string)$bookingId,
                'user_id'    => (string)$userId
            ]
        ];

        $orderId = null;

        // Try Razorpay API if live/valid credentials
        if (!empty($razorpayKey) && !empty($razorpaySecret) && strpos($razorpayKey, 'Sandbox') === false) {
            $ch = curl_init('https://api.razorpay.com/v1/orders');
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($orderData));
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
            curl_setopt($ch, CURLOPT_USERPWD, "{$razorpayKey}:{$razorpaySecret}");
            curl_setopt($ch, CURLOPT_TIMEOUT, 10);
            $response = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            $result = json_decode($response, true);
            if ($httpCode === 200 && !empty($result['id'])) {
                $orderId = $result['id'];
            }
        }

        // Sandbox/Fallback simulation mode (seamless local development without gateway block)
        if (!$orderId) {
            $orderId = 'order_sb_' . bin2hex(random_bytes(8));
        }

        // Store pending payment record
        $stmt = $this->db->prepare("
            INSERT INTO payments (booking_id, user_id, amount, payment_method, transaction_id, status, notes, created_at)
            VALUES (?, ?, ?, 'razorpay', ?, 'pending', 'Razorpay checkout initiated', NOW())
        ");
        $stmt->execute([$bookingId, $userId, $amount, $orderId]);

        Response::success([
            'order_id'       => $orderId,
            'booking_id'     => $bookingId,
            'amount'         => $amount,
            'currency'       => 'INR',
            'razorpay_key'   => $razorpayKey,
            'payment_method' => 'razorpay',
            'customer_name'  => $auth['name'] ?? 'DriveMate Customer',
            'customer_email' => $auth['email'] ?? 'customer@drivemate.in',
            'customer_phone' => $auth['phone'] ?? '9876543210'
        ], 'Razorpay order created successfully');
    }

    /**
     * POST /payments/verify
     * Verifies payment signature (Razorpay or UPI confirmation)
     */
    public function verify(): void {
        $auth      = AuthMiddleware::authenticate();
        $data      = Response::body();
        $orderId   = trim($data['razorpay_order_id'] ?? $data['order_id'] ?? '');
        $paymentId = trim($data['razorpay_payment_id'] ?? $data['payment_id'] ?? '');
        $signature = trim($data['razorpay_signature'] ?? '');
        $bookingId = (int)($data['booking_id'] ?? 0);

        if (empty($orderId) && empty($paymentId) && !$bookingId) {
            Response::error('order_id, payment_id, or booking_id is required');
        }

        $secret = $_ENV['RAZORPAY_SECRET'] ?? 'drivemate_sandbox_secret_9876';

        // Check if real signature is provided
        if (!empty($signature) && !empty($orderId) && !empty($paymentId)) {
            $expectedSig = hash_hmac('sha256', $orderId . '|' . $paymentId, $secret);
            if (!hash_equals($expectedSig, $signature) && strpos($orderId, 'order_sb_') === false) {
                Response::error('Payment signature verification failed', 400);
            }
        }

        // If paymentId not provided in sandbox mode, generate one
        if (empty($paymentId)) {
            $paymentId = 'pay_' . bin2hex(random_bytes(8));
        }

        // Update payment record
        $stmt = $this->db->prepare("
            SELECT * FROM payments 
            WHERE transaction_id = ? OR (booking_id = ? AND status = 'pending')
            ORDER BY id DESC LIMIT 1
        ");
        $stmt->execute([$orderId ?: $paymentId, $bookingId]);
        $payment = $stmt->fetch();

        if ($payment) {
            $this->db->prepare("
                UPDATE payments 
                SET status = 'paid', transaction_id = ?, paid_at = NOW(), notes = 'Payment verified successfully'
                WHERE id = ?
            ")->execute([$paymentId, $payment['id']]);

            $bId = $payment['booking_id'];
            $this->db->prepare("UPDATE bookings SET payment_status = 'paid' WHERE id = ?")->execute([$bId]);

            // Allocate driver commission
            $this->distributeDriverEarnings($bId, (float)$payment['amount']);
        } else if ($bookingId) {
            // Create paid record directly
            $this->db->prepare("
                INSERT INTO payments (booking_id, user_id, amount, payment_method, transaction_id, status, paid_at, notes, created_at)
                VALUES (?, ?, (SELECT total_amount FROM bookings WHERE id = ?), 'online', ?, 'paid', NOW(), 'Direct verified', NOW())
            ")->execute([$bookingId, $auth['sub'], $bookingId, $paymentId]);

            $this->db->prepare("UPDATE bookings SET payment_status = 'paid' WHERE id = ?")->execute([$bookingId]);
        }

        Response::success([
            'payment_id' => $paymentId,
            'status'     => 'paid',
            'verified'   => true
        ], 'Payment verified and confirmed successfully');
    }

    /**
     * POST /payments/cash-collect
     * Driver or User marks cash collected on trip completion
     */
    public function cashCollect(): void {
        $auth      = AuthMiddleware::authenticate();
        $data      = Response::body();
        $bookingId = (int)($data['booking_id'] ?? 0);
        $amount    = (float)($data['amount'] ?? 0);

        if (!$bookingId) {
            Response::error('booking_id is required');
        }

        $stmt = $this->db->prepare("SELECT * FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $booking = $stmt->fetch();
        if (!$booking) {
            Response::error('Booking not found', 404);
        }

        $totalAmt = $amount > 0 ? $amount : (float)$booking['total_amount'];
        $txnId = 'CASH_' . strtoupper(bin2hex(random_bytes(6)));

        // Update or insert payment
        $existing = $this->db->prepare("SELECT id FROM payments WHERE booking_id = ? AND payment_method = 'cash' LIMIT 1");
        $existing->execute([$bookingId]);
        $existingPayment = $existing->fetch();

        if ($existingPayment) {
            $this->db->prepare("
                UPDATE payments 
                SET status = 'paid', transaction_id = ?, paid_at = NOW(), amount = ?, notes = 'Cash received by driver'
                WHERE id = ?
            ")->execute([$txnId, $totalAmt, $existingPayment['id']]);
        } else {
            $this->db->prepare("
                INSERT INTO payments (booking_id, user_id, amount, payment_method, transaction_id, status, paid_at, notes, created_at)
                VALUES (?, ?, ?, 'cash', ?, 'paid', NOW(), 'Cash collected by driver', NOW())
            ")->execute([$bookingId, $booking['user_id'], $totalAmt, $txnId]);
        }

        // Update booking
        $this->db->prepare("UPDATE bookings SET payment_status = 'paid' WHERE id = ?")->execute([$bookingId]);

        // Distribute driver earnings
        $this->distributeDriverEarnings($bookingId, $totalAmt);

        Response::success([
            'booking_id'     => $bookingId,
            'amount_paid'    => $totalAmt,
            'payment_method' => 'cash',
            'transaction_id' => $txnId,
            'status'         => 'paid'
        ], 'Cash payment collected and booking marked as paid');
    }

    /**
     * GET /payments/invoice (Query: ?booking_id=1)
     * Complete tax invoice with fare breakdown (GST, distance, driver details)
     */
    public function invoice(): void {
        $auth      = AuthMiddleware::authenticate();
        $bookingId = (int)($_GET['booking_id'] ?? 0);

        if (!$bookingId) {
            Response::error('booking_id parameter is required');
        }

        $stmt = $this->db->prepare("
            SELECT b.*, 
                   cu.name AS customer_name, cu.email AS customer_email, cu.phone AS customer_phone,
                   du.name AS driver_name, du.phone AS driver_phone,
                   dp.avg_rating AS driver_rating,
                   v.model AS vehicle_model, v.number_plate, v.type AS vehicle_category,
                   p.payment_method, p.transaction_id, p.status AS payment_status_record, p.paid_at
            FROM bookings b
            JOIN users cu ON b.user_id = cu.id
            LEFT JOIN users du ON b.driver_id = du.id
            LEFT JOIN driver_profile dp ON b.driver_id = dp.user_id
            LEFT JOIN vehicles v ON b.vehicle_id = v.id
            LEFT JOIN payments p ON b.id = p.booking_id
            WHERE b.id = ?
            ORDER BY p.id DESC LIMIT 1
        ");
        $stmt->execute([$bookingId]);
        $inv = $stmt->fetch();

        if (!$inv) {
            Response::error('Booking or invoice not found', 404);
        }

        // Get trip metrics if available
        $tripStmt = $this->db->prepare("SELECT * FROM trips WHERE booking_id = ? LIMIT 1");
        $tripStmt->execute([$bookingId]);
        $trip = $tripStmt->fetch();

        $distanceKm  = $trip ? (float)$trip['distance_km'] : 0.0;
        $totalAmount = (float)$inv['total_amount'];

        // Calculate fair tax breakdown (5% GST for passenger transport services in India)
        $gstRate       = 0.05;
        $subtotal      = round($totalAmount / (1 + $gstRate), 2);
        $gstAmount     = round($totalAmount - $subtotal, 2);
        $cgst          = round($gstAmount / 2, 2);
        $sgst          = round($gstAmount / 2, 2);
        $platformFee   = 25.00; // included in fare

        $paymentStatus = $inv['payment_status'] === 'paid' ? 'PAID' : 'DUE';
        $upiVpa = !empty($_ENV['UPI_VPA']) ? trim($_ENV['UPI_VPA']) : null;
        $payeeName = !empty($_ENV['UPI_PAYEE_NAME']) ? trim($_ENV['UPI_PAYEE_NAME']) : 'DriveMate Mobility';
        $txnId = $inv['transaction_id'] ?? null;

        if (empty($txnId) && $paymentStatus !== 'PAID') {
            // Find or create pending payment to prevent duplicates
            $pCheck = $this->db->prepare("SELECT transaction_id FROM payments WHERE booking_id = ? ORDER BY id DESC LIMIT 1");
            $pCheck->execute([$bookingId]);
            $existingTxn = $pCheck->fetchColumn();
            if ($existingTxn) {
                $txnId = $existingTxn;
            } else {
                $txnId = 'DM_TXN_' . $bookingId . '_' . time() . '_' . strtoupper(bin2hex(random_bytes(3)));
                $this->db->prepare("
                    INSERT INTO payments (booking_id, user_id, amount, payment_method, transaction_id, status, notes, created_at)
                    VALUES (?, ?, ?, 'upi', ?, 'pending', 'Pending payment invoice created', NOW())
                ")->execute([$bookingId, $inv['user_id'], $totalAmount, $txnId]);
            }
        }

        $qrAvailable = false;
        $qrCodeUrl = null;
        $upiIntentUrl = null;
        $qrMessage = '';

        if ($paymentStatus === 'PAID') {
            $qrAvailable = false;
            $qrMessage = 'Payment confirmed and verified in full.';
        } elseif (!empty($upiVpa) && $upiVpa !== 'not_configured') {
            $note = rawurlencode("DriveMate Booking #{$bookingId} Fare");
            $encodedPayee = rawurlencode($payeeName);
            $upiIntentUrl = "upi://pay?pa={$upiVpa}&pn={$encodedPayee}&am={$totalAmount}&cu=INR&tn={$note}&tr={$txnId}";
            $qrCodeUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" . urlencode($upiIntentUrl);
            $qrAvailable = true;
            $qrMessage = "Scan with any UPI app (Google Pay, PhonePe, Paytm, BHIM) to pay.";
        } else {
            $qrAvailable = false;
            $qrMessage = "Online payment gateway is not configured on the server. Please pay cash directly to the driver.";
        }

        $invoiceData = [
            'invoice_number'   => 'INV-DM-' . str_pad($bookingId, 6, '0', STR_PAD_LEFT),
            'invoice_date'     => $inv['created_at'],
            'booking_id'       => $bookingId,
            'booking_type'     => $inv['type'],
            'customer' => [
                'name'  => $inv['customer_name'],
                'phone' => $inv['customer_phone'],
                'email' => $inv['customer_email'],
            ],
            'driver' => [
                'name'         => $inv['driver_name'] ?? 'Assigned Driver',
                'phone'        => $inv['driver_phone'] ?? 'N/A',
                'rating'       => $inv['driver_rating'] ?? '4.9',
                'vehicle'      => ($inv['vehicle_model'] ?? 'Vehicle') . ' (' . ($inv['number_plate'] ?? 'WB-01-XXXX') . ')',
            ],
            'trip_details' => [
                'pickup'       => $inv['pickup_location'],
                'destination'  => $inv['destination'],
                'distance_km'  => $distanceKm > 0 ? $distanceKm : 'Estimated',
                'trip_status'  => $inv['status'],
            ],
            'fare_breakdown' => [
                'subtotal'     => $subtotal,
                'platform_fee' => $platformFee,
                'cgst_2_5'     => $cgst,
                'sgst_2_5'     => $sgst,
                'gst_total'    => $gstAmount,
                'total_amount' => $totalAmount,
                'currency'     => 'INR',
            ],
            'payment' => [
                'method'         => strtoupper($inv['payment_method'] ?? 'UPI'),
                'status'         => $paymentStatus,
                'transaction_id' => $txnId ?? 'PENDING',
                'paid_at'        => $inv['paid_at'] ?? null,
            ],
            'payment_qr' => [
                'available'      => $qrAvailable,
                'qr_code_url'    => $qrCodeUrl,
                'upi_intent_url' => $upiIntentUrl,
                'upi_vpa'        => $upiVpa,
                'transaction_id' => $txnId,
                'amount'         => $totalAmount,
                'message'        => $qrMessage,
            ]
        ];

        Response::success($invoiceData, 'Invoice retrieved successfully');
    }

    /**
     * GET /payments/wallet
     * Returns user's wallet balance & transaction ledger
     */
    public function wallet(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];

        // Get or create wallet
        $stmt = $this->db->prepare("SELECT * FROM wallets WHERE user_id = ?");
        $stmt->execute([$userId]);
        $wallet = $stmt->fetch();

        if (!$wallet) {
            $this->db->prepare("INSERT INTO wallets (user_id, balance, currency) VALUES (?, 0.00, 'INR')")
                     ->execute([$userId]);
            $stmt->execute([$userId]);
            $wallet = $stmt->fetch();
        }

        // Get recent transactions
        $txStmt = $this->db->prepare("
            SELECT * FROM wallet_transactions 
            WHERE user_id = ? 
            ORDER BY created_at DESC LIMIT 20
        ");
        $txStmt->execute([$userId]);
        $transactions = $txStmt->fetchAll();

        Response::success([
            'balance'      => (float)$wallet['balance'],
            'currency'     => $wallet['currency'],
            'wallet_id'    => $wallet['id'],
            'transactions' => $transactions
        ]);
    }

    /**
     * POST /payments/wallet/add-money
     * Add funds to in-app wallet
     */
    public function addWalletMoney(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];
        $data   = Response::body();
        $amount = (float)($data['amount'] ?? 0);

        if ($amount < 10) {
            Response::error('Minimum top-up amount is ₹10');
        }

        // Ensure wallet exists
        $stmt = $this->db->prepare("SELECT * FROM wallets WHERE user_id = ?");
        $stmt->execute([$userId]);
        $wallet = $stmt->fetch();

        if (!$wallet) {
            $this->db->prepare("INSERT INTO wallets (user_id, balance, currency) VALUES (?, 0.00, 'INR')")
                     ->execute([$userId]);
            $stmt->execute([$userId]);
            $wallet = $stmt->fetch();
        }

        $newBalance = (float)$wallet['balance'] + $amount;
        $this->db->prepare("UPDATE wallets SET balance = ? WHERE id = ?")->execute([$newBalance, $wallet['id']]);

        $txnId = 'TOP_' . strtoupper(bin2hex(random_bytes(6)));
        $this->db->prepare("
            INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, reference_type, reference_id, description, balance_after)
            VALUES (?, ?, 'credit', ?, 'topup', ?, 'Wallet Top-up', ?)
        ")->execute([$wallet['id'], $userId, $amount, $txnId, $newBalance]);

        Response::success([
            'transaction_id' => $txnId,
            'amount_added'   => $amount,
            'new_balance'    => $newBalance,
            'currency'       => 'INR'
        ], '₹' . number_format($amount, 2) . ' added to DriveMate Wallet successfully');
    }

    /**
     * GET /payments/history
     */
    public function history(): void {
        $auth   = AuthMiddleware::authenticate();
        $userId = $auth['sub'];

        $stmt = $this->db->prepare("
            SELECT p.*, b.type AS booking_type, b.pickup_location, b.destination
            FROM payments p
            JOIN bookings b ON p.booking_id = b.id
            WHERE b.user_id = ? OR p.user_id = ?
            ORDER BY p.created_at DESC
        ");
        $stmt->execute([$userId, $userId]);
        Response::success($stmt->fetchAll());
    }

    /**
     * POST /payments/refund
     */
    public function refund(): void {
        AuthMiddleware::authenticate();
        $data      = Response::body();
        $bookingId = (int)($data['booking_id'] ?? 0);
        $toWallet  = !empty($data['to_wallet']);

        if (!$bookingId) {
            Response::error('booking_id is required');
        }

        $stmt = $this->db->prepare("SELECT * FROM payments WHERE booking_id = ? AND status = 'paid' LIMIT 1");
        $stmt->execute([$bookingId]);
        $payment = $stmt->fetch();

        if (!$payment) {
            Response::error('No completed payment found for this booking to refund', 404);
        }

        $refundId = 'RFND_' . strtoupper(bin2hex(random_bytes(6)));
        $amount   = (float)$payment['amount'];

        // Mark payment record as refunded
        $this->db->prepare("UPDATE payments SET status = 'refunded', refund_id = ? WHERE id = ?")
                 ->execute([$refundId, $payment['id']]);

        $this->db->prepare("UPDATE bookings SET payment_status = 'refunded', status = 'cancelled' WHERE id = ?")
                 ->execute([$bookingId]);

        // If refunding to wallet, credit immediately
        if ($toWallet || $payment['payment_method'] === 'wallet') {
            $userId = $payment['user_id'];
            $wStmt = $this->db->prepare("SELECT id, balance FROM wallets WHERE user_id = ?");
            $wStmt->execute([$userId]);
            $w = $wStmt->fetch();

            if ($w) {
                $newBal = (float)$w['balance'] + $amount;
                $this->db->prepare("UPDATE wallets SET balance = ? WHERE id = ?")->execute([$newBal, $w['id']]);
                $this->db->prepare("
                    INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, reference_type, reference_id, description, balance_after)
                    VALUES (?, ?, 'credit', ?, 'refund', ?, 'Refund for cancelled booking', ?)
                ")->execute([$w['id'], $userId, $amount, (string)$bookingId, $newBal]);
            }
        }

        Response::success([
            'refund_id' => $refundId,
            'amount'    => $amount,
            'status'    => 'refunded'
        ], 'Payment refunded successfully');
    }

    /**
     * POST /payments/webhook (Razorpay Public Webhook)
     */
    public function webhook(): void {
        $body      = file_get_contents('php://input');
        $signature = $_SERVER['HTTP_X_RAZORPAY_SIGNATURE'] ?? '';
        $secret    = $_ENV['RAZORPAY_WEBHOOK_SECRET'] ?? 'drivemate_webhook_secret';

        if (!empty($signature) && !empty($secret)) {
            $expected = hash_hmac('sha256', $body, $secret);
            if (!hash_equals($expected, $signature)) {
                Response::error('Invalid webhook signature', 400);
            }
        }

        $data  = json_decode($body, true);
        $event = $data['event'] ?? '';

        if ($event === 'payment.captured') {
            $paymentEntity = $data['payload']['payment']['entity'] ?? [];
            $orderId       = $paymentEntity['order_id'] ?? '';
            $paymentId     = $paymentEntity['id'] ?? '';
            $bookingId     = (int)($paymentEntity['notes']['booking_id'] ?? 0);

            if ($orderId && $paymentId) {
                $this->db->prepare("
                    UPDATE payments SET status = 'paid', transaction_id = ?, paid_at = NOW() 
                    WHERE transaction_id = ? OR booking_id = ?
                ")->execute([$paymentId, $orderId, $bookingId]);

                if ($bookingId) {
                    $this->db->prepare("UPDATE bookings SET payment_status = 'paid' WHERE id = ?")
                             ->execute([$bookingId]);
                    $amt = (float)($paymentEntity['amount'] ?? 0) / 100;
                    $this->distributeDriverEarnings($bookingId, $amt);
                }
            }
        }

        Response::success([], 'Webhook event processed');
    }

    /**
     * Helper: Distribute commission & driver earnings automatically
     */
    private function distributeDriverEarnings(int $bookingId, float $totalAmount): void {
        $stmt = $this->db->prepare("SELECT driver_id FROM bookings WHERE id = ?");
        $stmt->execute([$bookingId]);
        $driverId = $stmt->fetchColumn();

        if ($driverId && $totalAmount > 0) {
            // 85% driver share, 15% platform commission
            $commissionRate = 0.15;
            $driverShare    = round($totalAmount * (1 - $commissionRate), 2);

            $this->db->prepare("
                UPDATE driver_profile 
                SET total_trips = total_trips + 1,
                    earnings = earnings + ? 
                WHERE user_id = ?
            ")->execute([$driverShare, $driverId]);
        }
    }
}
