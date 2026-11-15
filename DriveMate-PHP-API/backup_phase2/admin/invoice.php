<?php
// admin/invoice.php — DriveMate Official Tax & Ride Invoice
require_once __DIR__ . '/auth_check.php';

$bookingId = (int)($_GET['booking_id'] ?? 0);
if ($bookingId <= 0) {
    die("Invalid booking reference specified.");
}

$stmt = $db->prepare("SELECT b.*, 
                             u_c.name AS customer_name, u_c.email AS customer_email, u_c.phone AS customer_phone,
                             u_d.name AS driver_name, u_d.phone AS driver_phone,
                             dp.license_number, dp.vehicle_model, dp.vehicle_number,
                             p.id AS payment_id, p.amount AS paid_amount, p.payment_method, p.transaction_id, p.status AS payment_status, p.paid_at
                      FROM bookings b 
                      LEFT JOIN users u_c ON b.user_id = u_c.id 
                      LEFT JOIN users u_d ON b.driver_id = u_d.id 
                      LEFT JOIN driver_profile dp ON b.driver_id = dp.user_id 
                      LEFT JOIN payments p ON b.id = p.booking_id 
                      WHERE b.id = ? LIMIT 1");
$stmt->execute([$bookingId]);
$inv = $stmt->fetch();

if (!$inv) {
    die("Booking record #$bookingId not found in the database.");
}

$total = (float)($inv['paid_amount'] ?: $inv['total_amount']);
$baseFare = round($total / 1.05, 2);
$gstAmount = round($total - $baseFare, 2);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tax Invoice #INV-BK-<?= $bookingId ?> — DriveMate</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <style>
        body { background: #f8fafc; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; color: #1e293b; }
        .invoice-box { max-width: 800px; margin: 30px auto; background: #fff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
        .invoice-header { border-bottom: 2px solid #00F2FE; padding-bottom: 20px; margin-bottom: 25px; }
        .paid-stamp { display: inline-block; padding: 6px 16px; border: 2px solid #10B981; color: #10B981; font-weight: 800; text-transform: uppercase; border-radius: 6px; letter-spacing: 2px; }
        @media print {
            body { background: #fff; }
            .invoice-box { box-shadow: none; margin: 0; padding: 0; }
            .no-print { display: none !important; }
        }
    </style>
</head>
<body>

<div class="container py-4">
    <div class="d-flex justify-content-between align-items-center mb-3 no-print" style="max-width: 800px; margin: 0 auto;">
        <a href="payments.php" class="btn btn-outline-secondary btn-sm"><i class="bi bi-arrow-left"></i> Back to Payments</a>
        <button onclick="window.print();" class="btn btn-primary btn-sm"><i class="bi bi-printer-fill me-1"></i> Print Invoice</button>
    </div>

    <div class="invoice-box">
        <div class="invoice-header d-flex justify-content-between align-items-start">
            <div>
                <h3 class="fw-bold mb-1" style="color: #0B132B;">Drive<span style="color: #00F2FE;">Mate</span></h3>
                <small class="text-muted d-block">DriveMate Technologies India Pvt. Ltd.</small>
                <small class="text-muted">GSTIN: 19ABCDE1234F1Z5 &bull; CIN: U72900WB2026PTC123456</small>
            </div>
            <div class="text-end">
                <h5 class="fw-bold mb-1">TAX INVOICE</h5>
                <div class="text-muted small">Invoice No: <strong>#DM-INV-<?= str_pad($inv['id'], 6, '0', STR_PAD_LEFT) ?></strong></div>
                <div class="text-muted small">Date: <?= date('d M Y', strtotime($inv['created_at'])) ?></div>
                <div class="mt-2">
                    <span class="paid-stamp">PAID &bull; VERIFIED</span>
                </div>
            </div>
        </div>

        <div class="row mb-4">
            <div class="col-6">
                <small class="text-muted text-uppercase fw-bold">Billed To (Customer):</small>
                <h6 class="fw-bold mb-1 mt-1"><?= htmlspecialchars($inv['customer_name'] ?? 'Guest Customer') ?></h6>
                <div class="small text-muted"><i class="bi bi-telephone me-1"></i> <?= htmlspecialchars($inv['customer_phone'] ?? '-') ?></div>
                <div class="small text-muted"><i class="bi bi-envelope me-1"></i> <?= htmlspecialchars($inv['customer_email'] ?? '-') ?></div>
            </div>
            <div class="col-6 text-end">
                <small class="text-muted text-uppercase fw-bold">Service / Fleet Provider:</small>
                <h6 class="fw-bold mb-1 mt-1"><?= htmlspecialchars($inv['driver_name'] ?? 'DriveMate Partner Driver') ?></h6>
                <div class="small text-muted">Vehicle: <?= htmlspecialchars($inv['vehicle_model'] ?: 'Assigned Fleet') ?></div>
                <div class="small text-muted">Reg No: <strong><?= htmlspecialchars($inv['vehicle_number'] ?: 'N/A') ?></strong></div>
            </div>
        </div>

        <div class="card bg-light border-0 p-3 mb-4">
            <div class="row">
                <div class="col-md-6 mb-2 mb-md-0">
                    <small class="text-muted text-uppercase fw-bold">Pickup Location:</small>
                    <div class="small fw-semibold"><?= htmlspecialchars($inv['pickup_location'] ?? 'Not Specified') ?></div>
                </div>
                <div class="col-md-6">
                    <small class="text-muted text-uppercase fw-bold">Destination Drop-Off:</small>
                    <div class="small fw-semibold"><?= htmlspecialchars($inv['destination'] ?? 'Not Specified') ?></div>
                </div>
            </div>
        </div>

        <table class="table table-bordered mb-4">
            <thead class="table-light">
                <tr>
                    <th>Description</th>
                    <th class="text-center">Distance / Rate</th>
                    <th class="text-end">Amount (INR)</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>
                        <strong><?= strtoupper(str_replace('_', ' ', $inv['type'])) ?> Ride Service</strong>
                        <div class="small text-muted">Booking Reference: #BK-<?= $inv['id'] ?> &bull; Driver Chauffeur</div>
                    </td>
                    <td class="text-center"><?= $inv['distance_km'] ? $inv['distance_km'] . ' KM' : 'Trip Flat' ?></td>
                    <td class="text-end">₹<?= number_format($baseFare, 2) ?></td>
                </tr>
                <tr>
                    <td colspan="2" class="text-end fw-semibold">CGST (2.5%)</td>
                    <td class="text-end">₹<?= number_format($gstAmount / 2, 2) ?></td>
                </tr>
                <tr>
                    <td colspan="2" class="text-end fw-semibold">SGST (2.5%)</td>
                    <td class="text-end">₹<?= number_format($gstAmount / 2, 2) ?></td>
                </tr>
                <tr class="table-light">
                    <td colspan="2" class="text-end fw-bold fs-6">Total Mutually Settled Fare:</td>
                    <td class="text-end fw-bold fs-6 text-primary">₹<?= number_format($total, 2) ?></td>
                </tr>
            </tbody>
        </table>

        <div class="row align-items-center mb-4">
            <div class="col-8">
                <div class="small text-muted">Payment Mode: <strong><?= strtoupper(htmlspecialchars($inv['payment_method'] ?? 'UPI')) ?></strong></div>
                <div class="small text-muted">Gateway Txn ID: <code><?= htmlspecialchars($inv['transaction_id'] ?: 'CASH_DIRECT_SETTLED') ?></code></div>
            </div>
            <div class="col-4 text-end">
                <div class="small text-muted">Authorized Signatory</div>
                <div class="fw-bold text-dark mt-3">DriveMate Systems</div>
            </div>
        </div>

        <div class="border-top pt-3 text-center text-muted" style="font-size: 0.75rem;">
            This is a computer-generated electronic invoice generated in accordance with the Information Technology Act. No physical signature is required.
        </div>
    </div>
</div>

</body>
</html>
