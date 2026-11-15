<?php
/**
 * DriveMate REST API - Promotion & Reward Controller (Feature 9)
 * Handles Promo Codes, Discounts, Referral Program & Reward Points
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class PromotionController {
    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    /**
     * GET /promotions
     * List active promotional offers & coupons
     */
    public function listPromotions(): void {
        $stmt = $this->db->query("
            SELECT id, code, title, description, discount_type, discount_value, min_order_amount, max_discount_cap, expires_at
            FROM promotions
            WHERE is_active = 1
            ORDER BY id ASC
        ");
        $promotions = $stmt->fetchAll(PDO::FETCH_ASSOC);

        Response::success($promotions, 'Active promotions retrieved successfully');
    }

    /**
     * POST /promotions/validate
     * Authoritatively validate coupon code
     */
    public function validatePromo(): void {
        $data = Response::body();
        $code = strtoupper(trim($data['code'] ?? ''));
        $orderAmount = (float)($data['order_amount'] ?? 0.0);

        if (empty($code)) {
            Response::error('Promo code is required', 400);
        }

        $stmt = $this->db->prepare("SELECT * FROM promotions WHERE code = ? AND is_active = 1 LIMIT 1");
        $stmt->execute([$code]);
        $promo = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$promo) {
            Response::error('Invalid or inactive promo coupon code', 404);
        }

        // 1. Expiry Date Verification
        if (!empty($promo['expires_at'])) {
            $expiryTimestamp = strtotime($promo['expires_at']);
            if ($expiryTimestamp !== false && $expiryTimestamp < time()) {
                Response::error("This promo coupon expired on " . date('d M Y', $expiryTimestamp), 400);
            }
        }

        // 2. Minimum Booking Amount Requirement
        $minAmount = (float)($promo['min_order_amount'] ?? 0);
        if ($orderAmount > 0 && $orderAmount < $minAmount) {
            Response::error("Minimum booking amount of ₹" . number_format($minAmount, 2) . " required for this coupon", 400);
        }

        // 3. User Eligibility & Single-Use Restriction
        $auth = AuthMiddleware::optionalAuthenticate();
        if ($auth && !empty($auth['sub'])) {
            $userId = (int)$auth['sub'];
            $usedCheck = $this->db->prepare("SELECT 1 FROM bookings WHERE user_id = ? AND promo_code = ? AND status != 'cancelled' LIMIT 1");
            $usedCheck->execute([$userId, $code]);
            if ($usedCheck->fetch()) {
                Response::error("You have already applied this coupon code to a previous booking", 400);
            }
        }

        // 4. Discount Calculation with Maximum Limit
        $discountVal = (float)$promo['discount_value'];
        $maxCap      = (float)$promo['max_discount_cap'];

        if ($promo['discount_type'] === 'percentage') {
            $discount = round(($orderAmount * $discountVal) / 100, 2);
            if ($maxCap > 0 && $discount > $maxCap) {
                $discount = $maxCap;
            }
        } else {
            $discount = ($maxCap > 0 && $discountVal > $maxCap) ? $maxCap : $discountVal;
        }

        $netFare = max(0.0, round($orderAmount - $discount, 2));

        Response::success([
            'code'                => $promo['code'],
            'title'               => $promo['title'],
            'discount_type'       => $promo['discount_type'],
            'discount_value'      => $discountVal,
            'calculated_discount' => $discount,
            'net_fare'            => $netFare,
            'min_order_amount'    => $minAmount,
            'max_discount_cap'    => $maxCap,
            'is_valid'            => true,
        ], 'Promo code applied successfully');
    }

    /**
     * GET /rewards/my
     * Fetch user's referral code, reward points, and statistics
     */
    public function myRewards(): void {
        $auth = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];

        $stmt = $this->db->prepare("SELECT * FROM user_rewards WHERE user_id = ? LIMIT 1");
        $stmt->execute([$userId]);
        $reward = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$reward) {
            // Generate unique referral code
            $refCode = 'DRIVE-' . strtoupper(substr(md5(uniqid((string)$userId, true)), 0, 6));
            $ins = $this->db->prepare("
                INSERT INTO user_rewards (user_id, referral_code, reward_points, lifetime_points_earned, referrals_count)
                VALUES (?, ?, 150, 150, 0)
            ");
            $ins->execute([$userId, $refCode]);

            $stmt->execute([$userId]);
            $reward = $stmt->fetch(PDO::FETCH_ASSOC);
        }

        Response::success([
            'referral_code'          => $reward['referral_code'],
            'reward_points'          => (int)$reward['reward_points'],
            'points_value_inr'       => (float)$reward['reward_points'], // 1 Point = ₹1
            'lifetime_points_earned' => (int)$reward['lifetime_points_earned'],
            'referrals_count'        => (int)$reward['referrals_count'],
            'referral_bonus_inr'     => 150.0,
            'share_message'          => "Use my referral code {$reward['referral_code']} on DriveMate and get flat ₹150 off your first chauffeur or car rental trip! Download now: https://drivemate.app/r/{$reward['referral_code']}",
        ], 'User rewards retrieved successfully');
    }

    /**
     * POST /rewards/redeem
     * Redeem reward points into wallet balance
     */
    public function redeemPoints(): void {
        $auth = AuthMiddleware::authenticate();
        $userId = (int)$auth['sub'];
        $data = Response::body();
        $pointsToRedeem = (int)($data['points'] ?? 0);

        if ($pointsToRedeem < 50) {
            Response::error('Minimum 50 reward points required for wallet conversion', 400);
        }

        $stmt = $this->db->prepare("SELECT * FROM user_rewards WHERE user_id = ? LIMIT 1");
        $stmt->execute([$userId]);
        $reward = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$reward || (int)$reward['reward_points'] < $pointsToRedeem) {
            $avail = $reward ? (int)$reward['reward_points'] : 0;
            Response::error("Insufficient reward points. Available: $avail points", 400);
        }

        $newPoints = (int)$reward['reward_points'] - $pointsToRedeem;
        $this->db->prepare("UPDATE user_rewards SET reward_points = ? WHERE id = ?")
                 ->execute([$newPoints, $reward['id']]);

        // Credit to wallet (1 point = ₹1)
        $wStmt = $this->db->prepare("SELECT * FROM wallets WHERE user_id = ? LIMIT 1");
        $wStmt->execute([$userId]);
        $wallet = $wStmt->fetch(PDO::FETCH_ASSOC);

        if (!$wallet) {
            $this->db->prepare("INSERT INTO wallets (user_id, balance, currency) VALUES (?, 0.00, 'INR')")
                     ->execute([$userId]);
            $wStmt->execute([$userId]);
            $wallet = $wStmt->fetch(PDO::FETCH_ASSOC);
        }

        $creditAmount = (float)$pointsToRedeem;
        $newBalance   = (float)$wallet['balance'] + $creditAmount;
        $this->db->prepare("UPDATE wallets SET balance = ? WHERE id = ?")
                 ->execute([$newBalance, $wallet['id']]);

        $txnId = 'RWD_' . strtoupper(bin2hex(random_bytes(6)));
        $this->db->prepare("
            INSERT INTO wallet_transactions (wallet_id, user_id, type, amount, reference_type, reference_id, description, balance_after)
            VALUES (?, ?, 'credit', ?, 'promo_reward', ?, 'Reward Points Redeemed to Wallet', ?)
        ")->execute([$wallet['id'], $userId, $creditAmount, $txnId, $newBalance]);

        Response::success([
            'redeemed_points' => $pointsToRedeem,
            'credit_amount'   => $creditAmount,
            'remaining_points'=> $newPoints,
            'new_wallet_balance' => $newBalance,
        ], "$pointsToRedeem reward points successfully converted to ₹$creditAmount in your DriveMate Wallet!");
    }
}
