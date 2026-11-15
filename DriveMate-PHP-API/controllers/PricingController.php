<?php
// controllers/PricingController.php — Authoritative Dynamic Smart Fare Engine

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/Response.php';
require_once __DIR__ . '/../middleware/AuthMiddleware.php';

class PricingController {
    private PDO $db;

    public function __construct() {
        $this->db = Database::getInstance();
    }

    /**
     * Compute authoritative fare with transparent component breakdown.
     * Can be invoked directly or called internally from BookingController.
     */
    public function computeAuthoritativeFare(array $params): array {
        $serviceType   = strtolower(trim($params['service_type'] ?? 'hire_driver'));
        $hiringType    = strtolower(trim($params['hiring_type'] ?? 'one_way'));
        $distanceKm    = max(0.0, (float)($params['distance_km'] ?? 10.0));
        $durationMins  = max(0, (int)($params['duration_minutes'] ?? 25));
        $hours         = max(0.0, (float)($params['hours'] ?? 0.0));
        $days          = max(0, (int)($params['days'] ?? 0));
        $waitingMins   = max(0, (int)($params['waiting_minutes'] ?? 0));
        $tollCharges   = max(0.0, (float)($params['toll_charges'] ?? 0.0));
        $parkingCharges= max(0.0, (float)($params['parking_charges'] ?? 0.0));
        $promoCode     = strtoupper(trim($params['promo_code'] ?? ''));
        $isFinal       = !empty($params['is_final']);
        $startTimeStr  = $params['start_time'] ?? date('Y-m-d H:i:s');

        // Fetch matching rule from database
        $stmt = $this->db->prepare("
            SELECT * FROM pricing_rules 
            WHERE service_type = ? AND hiring_type = ? AND is_active = 1
            LIMIT 1
        ");
        $stmt->execute([$serviceType, $hiringType]);
        $rule = $stmt->fetch(PDO::FETCH_ASSOC);

        // Fallback default rule if exact combination is not matched
        if (!$rule) {
            $stmtDef = $this->db->prepare("
                SELECT * FROM pricing_rules 
                WHERE service_type = ? AND is_active = 1
                LIMIT 1
            ");
            $stmtDef->execute([$serviceType]);
            $rule = $stmtDef->fetch(PDO::FETCH_ASSOC);
        }

        if (!$rule) {
            $rule = [
                'base_fare'             => 150.00,
                'rate_per_km'           => 14.00,
                'rate_per_minute'       => 2.00,
                'hourly_rate'           => 150.00,
                'daily_rate'            => 1800.00,
                'waiting_rate_per_min'  => 3.00,
                'night_charge_percent'  => 20.00,
                'night_start_hour'      => 22,
                'night_end_hour'        => 6,
                'platform_fee'          => 25.00,
                'gst_percent'           => 5.00,
                'commission_percent'    => 15.00
            ];
        }

        // Component 1: Base Fare
        $baseFare = (float)$rule['base_fare'];

        // Component 2: Distance Charges
        $ratePerKm = (float)$rule['rate_per_km'];
        $distanceCharges = round($distanceKm * $ratePerKm, 2);

        // Component 3: Hourly Charges (for hourly, half_day, or hourly overages)
        $hourlyRate = (float)$rule['hourly_rate'];
        $hourlyCharges = 0.0;
        if ($hiringType === 'hourly' && $hours > 0) {
            $hourlyCharges = round($hours * $hourlyRate, 2);
            // In pure hourly hiring, base + hourly applies; distance is secondary or included up to 10km/hr
            $distanceCharges = max(0.0, round(max(0.0, $distanceKm - ($hours * 10)) * $ratePerKm, 2));
        }

        // Component 4: Daily Rental Charges
        $dailyRate = (float)$rule['daily_rate'];
        $dailyCharges = 0.0;
        if (($hiringType === 'daily' || $hiringType === 'outstation') && $days > 0) {
            $dailyCharges = round($days * $dailyRate, 2);
            // Over quota distance charges (e.g. 100km/day included)
            $includedKm = $days * 100.0;
            $distanceCharges = max(0.0, round(max(0.0, $distanceKm - $includedKm) * $ratePerKm, 2));
        }

        // Component 5: Waiting Charges
        $waitingRate = (float)$rule['waiting_rate_per_min'];
        $waitingCharges = round($waitingMins * $waitingRate, 2);

        // Component 6: Night Charges (Applicable between 22:00 and 06:00)
        $startHour = (int)date('H', strtotime($startTimeStr));
        $isNight = ($startHour >= (int)$rule['night_start_hour'] || $startHour < (int)$rule['night_end_hour']);
        $nightPercent = (float)$rule['night_charge_percent'];
        $nightCharges = 0.0;
        if ($isNight) {
            $nightSubjectFare = $baseFare + $distanceCharges + $hourlyCharges + $dailyCharges;
            $nightCharges = round($nightSubjectFare * ($nightPercent / 100.0), 2);
        }

        // Component 7: Toll & Parking Charges
        $tolls = round($tollCharges, 2);
        $parking = round($parkingCharges, 2);

        // Component 8: Platform Fee
        $platformFee = (float)$rule['platform_fee'];

        // Subtotal before discounts
        $subtotal = round($baseFare + $distanceCharges + $hourlyCharges + $dailyCharges + $waitingCharges + $nightCharges + $tolls + $parking + $platformFee, 2);

        // Component 9: Promo / Discounts
        $discount = 0.0;
        $discountDescription = null;
        if ($promoCode === 'WELCOME50') {
            $discount = min(50.00, $subtotal);
            $discountDescription = '₹50 New Customer Welcome Discount';
        } elseif ($promoCode === 'DRIVE10') {
            $discount = round($subtotal * 0.10, 2);
            $discountDescription = '10% Smart Mobility Promo Discount';
        } elseif ($promoCode === 'FLAT100') {
            $discount = min(100.00, $subtotal);
            $discountDescription = '₹100 Flat Promotional Discount';
        } elseif (!empty($promoCode)) {
            $discountDescription = 'Invalid or expired promotional code';
        }

        $taxableAmount = max(0.0, round($subtotal - $discount, 2));

        // Component 10: GST Taxes (5% total: CGST 2.5% + SGST 2.5%)
        $gstPercent = (float)$rule['gst_percent'];
        $cgst = round($taxableAmount * (($gstPercent / 2.0) / 100.0), 2);
        $sgst = round($taxableAmount * (($gstPercent / 2.0) / 100.0), 2);
        $totalTax = round($cgst + $sgst, 2);

        // Final Authoritative Total Fare
        $totalFare = round($taxableAmount + $totalTax, 2);

        // Platform Commission & Driver Net Payout
        $commPercent = (float)$rule['commission_percent'];
        // Commission is levied on net ride fare excluding pass-through tolls, parking and taxes
        $commissionableAmount = max(0.0, $taxableAmount - $tolls - $parking - $platformFee);
        $platformCommission = round(($commissionableAmount * ($commPercent / 100.0)) + $platformFee, 2);
        $driverNetEarnings = round(max(0.0, $totalFare - $platformCommission - $totalTax), 2);

        return [
            'fare_id'             => 'DM-FARE-' . strtoupper(substr(md5(uniqid('', true)), 0, 10)),
            'service_type'        => $serviceType,
            'hiring_type'         => $hiringType,
            'fare_type'           => $isFinal ? 'FINAL' : 'ESTIMATED',
            'is_authoritative'    => true,
            'calculated_at'       => date('c'),
            'inputs'              => [
                'distance_km'      => $distanceKm,
                'duration_minutes' => $durationMins,
                'hours'            => $hours,
                'days'             => $days,
                'waiting_minutes'  => $waitingMins,
                'is_night'         => $isNight,
                'night_hours'      => "{$rule['night_start_hour']}:00 - 0{$rule['night_end_hour']}:00",
                'promo_code'       => $promoCode ?: null,
            ],
            'breakdown'           => [
                'base_fare'           => $baseFare,
                'distance_charges'    => $distanceCharges,
                'rate_per_km'         => $ratePerKm,
                'hourly_charges'      => $hourlyCharges,
                'hourly_rate'         => $hourlyRate,
                'daily_charges'       => $dailyCharges,
                'daily_rate'          => $dailyRate,
                'waiting_charges'     => $waitingCharges,
                'waiting_rate_per_min'=> $waitingRate,
                'night_charges'       => $nightCharges,
                'night_charge_percent'=> $nightPercent . '%',
                'toll_charges'        => $tolls,
                'parking_charges'     => $parking,
                'platform_fee'        => $platformFee,
                'subtotal'            => $subtotal,
                'discount'            => $discount,
                'discount_details'    => $discountDescription,
                'taxable_amount'      => $taxableAmount,
                'cgst_2_5'            => $cgst,
                'sgst_2_5'            => $sgst,
                'total_tax'           => $totalTax,
                'total_fare'          => $totalFare,
                'driver_earnings'     => $driverNetEarnings,
                'platform_commission' => $platformCommission,
                'commission_percent'  => $commPercent . '%',
                'currency'            => 'INR',
                'currency_symbol'     => '₹'
            ]
        ];
    }

    // POST /pricing/calculate (Public / Auth) — Real-time authoritative fare calculation
    public function calculateFare(): void {
        AuthMiddleware::optionalAuthenticate();
        $data = Response::body();

        $fare = $this->computeAuthoritativeFare($data);
        Response::success($fare, 'Authoritative fare calculation computed successfully');
    }

    // GET /pricing/rules (Public / Auth) — Retrieve current active pricing matrix
    public function getRules(): void {
        AuthMiddleware::optionalAuthenticate();

        $stmt = $this->db->prepare("SELECT * FROM pricing_rules WHERE is_active = 1 ORDER BY service_type, hiring_type");
        $stmt->execute();
        $rules = $stmt->fetchAll(PDO::FETCH_ASSOC);

        Response::success($rules);
    }

    // PUT or POST /admin/pricing/rules (Admin only) — Update authoritative pricing rule
    public function updateRule(): void {
        AuthMiddleware::requireAdmin();
        $data = Response::body();

        $ruleId = (int)($data['id'] ?? 0);
        $service = trim($data['service_type'] ?? '');
        $hiring  = trim($data['hiring_type'] ?? '');

        if ($ruleId <= 0 && (empty($service) || empty($hiring))) {
            Response::error('Either rule id or (service_type, hiring_type) is required', 400);
        }

        $baseFare   = isset($data['base_fare']) ? (float)$data['base_fare'] : null;
        $kmRate     = isset($data['rate_per_km']) ? (float)$data['rate_per_km'] : null;
        $minRate    = isset($data['rate_per_minute']) ? (float)$data['rate_per_minute'] : null;
        $hrRate     = isset($data['hourly_rate']) ? (float)$data['hourly_rate'] : null;
        $dailyRate  = isset($data['daily_rate']) ? (float)$data['daily_rate'] : null;
        $waitingRate= isset($data['waiting_rate_per_min']) ? (float)$data['waiting_rate_per_min'] : null;
        $nightPct   = isset($data['night_charge_percent']) ? (float)$data['night_charge_percent'] : null;
        $platformFee= isset($data['platform_fee']) ? (float)$data['platform_fee'] : null;
        $gstPct     = isset($data['gst_percent']) ? (float)$data['gst_percent'] : null;
        $commPct    = isset($data['commission_percent']) ? (float)$data['commission_percent'] : null;

        if ($ruleId > 0) {
            $stmt = $this->db->prepare("
                UPDATE pricing_rules SET
                    base_fare             = COALESCE(?, base_fare),
                    rate_per_km           = COALESCE(?, rate_per_km),
                    rate_per_minute       = COALESCE(?, rate_per_minute),
                    hourly_rate           = COALESCE(?, hourly_rate),
                    daily_rate            = COALESCE(?, daily_rate),
                    waiting_rate_per_min  = COALESCE(?, waiting_rate_per_min),
                    night_charge_percent  = COALESCE(?, night_charge_percent),
                    platform_fee          = COALESCE(?, platform_fee),
                    gst_percent           = COALESCE(?, gst_percent),
                    commission_percent    = COALESCE(?, commission_percent),
                    updated_at            = NOW()
                WHERE id = ?
            ");
            $stmt->execute([$baseFare, $kmRate, $minRate, $hrRate, $dailyRate, $waitingRate, $nightPct, $platformFee, $gstPct, $commPct, $ruleId]);
        } else {
            $stmt = $this->db->prepare("
                UPDATE pricing_rules SET
                    base_fare             = COALESCE(?, base_fare),
                    rate_per_km           = COALESCE(?, rate_per_km),
                    rate_per_minute       = COALESCE(?, rate_per_minute),
                    hourly_rate           = COALESCE(?, hourly_rate),
                    daily_rate            = COALESCE(?, daily_rate),
                    waiting_rate_per_min  = COALESCE(?, waiting_rate_per_min),
                    night_charge_percent  = COALESCE(?, night_charge_percent),
                    platform_fee          = COALESCE(?, platform_fee),
                    gst_percent           = COALESCE(?, gst_percent),
                    commission_percent    = COALESCE(?, commission_percent),
                    updated_at            = NOW()
                WHERE service_type = ? AND hiring_type = ?
            ");
            $stmt->execute([$baseFare, $kmRate, $minRate, $hrRate, $dailyRate, $waitingRate, $nightPct, $platformFee, $gstPct, $commPct, $service, $hiring]);
        }

        Response::success([], 'Pricing rule updated successfully by administrator');
    }
}
