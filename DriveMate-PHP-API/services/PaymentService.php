<?php
// services/PaymentService.php — Multi-Method Payment Gateway & Wallet Service

require_once __DIR__ . '/../config/database.php';

class PaymentService {

    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    /**
     * Generate NPCI-compliant UPI Intent Link & dynamic QR URL
     */
    public function generateUpiPayload(int $bookingId, float $amount): array {
        $vpa       = $_ENV['UPI_VPA'] ?? 'drivemate@icici';
        $payeeName = rawurlencode($_ENV['UPI_PAYEE_NAME'] ?? 'DriveMate Mobility');
        $txnId     = 'UPI_' . strtoupper(bin2hex(random_bytes(6)));
        $note      = rawurlencode("DriveMate Booking #{$bookingId}");

        $upiUrl   = "upi://pay?pa={$vpa}&pn={$payeeName}&am={$amount}&cu=INR&tn={$note}&tr={$txnId}";
        $qrCodeUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" . urlencode($upiUrl);

        return [
            'transaction_id' => $txnId,
            'upi_vpa'        => $vpa,
            'upi_intent_url' => $upiUrl,
            'qr_code_url'    => $qrCodeUrl,
            'amount'         => $amount,
            'currency'       => 'INR'
        ];
    }

    /**
     * Verify Razorpay payment signature
     */
    public function verifyRazorpaySignature(string $orderId, string $paymentId, string $signature): bool {
        $secret = $_ENV['RAZORPAY_SECRET'] ?? 'drivemate_sandbox_secret_9876';
        $expected = hash_hmac('sha256', $orderId . '|' . $paymentId, $secret);
        return hash_equals($expected, $signature);
    }

    /**
     * Calculate 5% GST & Itemized Fare Breakdown
     */
    public function calculateFareBreakdown(float $totalAmount): array {
        $gstRate     = 0.05; // 5% GST for passenger transport in India
        $subtotal    = round($totalAmount / (1 + $gstRate), 2);
        $gstAmount   = round($totalAmount - $subtotal, 2);
        $cgst        = round($gstAmount / 2, 2);
        $sgst        = round($gstAmount / 2, 2);
        $platformFee = 25.00;

        return [
            'subtotal'     => $subtotal,
            'platform_fee' => $platformFee,
            'cgst_2_5'     => $cgst,
            'sgst_2_5'     => $sgst,
            'gst_total'    => $gstAmount,
            'total_amount' => $totalAmount,
            'currency'     => 'INR'
        ];
    }
}
