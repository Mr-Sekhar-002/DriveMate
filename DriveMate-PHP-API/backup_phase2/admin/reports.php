<?php
// admin/reports.php — DriveMate Financial Intelligence & Revenue Reports
$pageTitle = 'Revenue & Financial Reports';
$activePage = 'reports';
require_once __DIR__ . '/header.php';

// Handle CSV Export
if (isset($_GET['export']) && $_GET['export'] === 'csv') {
    $exportStmt = $db->query("SELECT p.id AS payment_id, p.booking_id, u.name AS customer_name, p.amount, p.payment_method, p.transaction_id, p.status, p.paid_at, p.created_at 
                              FROM payments p 
                              LEFT JOIN users u ON p.user_id = u.id 
                              WHERE p.status = 'paid' 
                              ORDER BY p.created_at DESC");
    $rows = $exportStmt->fetchAll(PDO::FETCH_ASSOC);

    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename=DriveMate_Revenue_Report_' . date('Ymd_His') . '.csv');
    $output = fopen('php://output', 'w');
    fputcsv($output, ['Payment ID', 'Booking ID', 'Customer Name', 'Amount (INR)', 'Method', 'Transaction Ref', 'Status', 'Paid At', 'Created At']);
    foreach ($rows as $row) {
        fputcsv($output, $row);
    }
    fclose($output);
    exit();
}

// Key Financial Aggregates
$totalGrossRevenue = 0.00;
$totalTransactions = 0;
$cashTotal = 0.00;
$upiTotal = 0.00;

try {
    $totalGrossRevenue = (float)$db->query("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'paid'")->fetchColumn();
    $totalTransactions  = (int)$db->query("SELECT COUNT(*) FROM payments WHERE status = 'paid'")->fetchColumn();
    $cashTotal          = (float)$db->query("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'paid' AND payment_method = 'cash'")->fetchColumn();
    $upiTotal           = (float)$db->query("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'paid' AND payment_method != 'cash'")->fetchColumn();
} catch (Exception $e) {}

$platformCommission = round($totalGrossRevenue * 0.15, 2); // 15% Platform cut
$driverPayout       = round($totalGrossRevenue * 0.85, 2); // 85% Driver earnings
$avgBookingValue    = $totalTransactions > 0 ? round($totalGrossRevenue / $totalTransactions, 2) : 0;

// Monthly Breakdown
$monthlyData = [];
try {
    $mStmt = $db->query("SELECT DATE_FORMAT(created_at, '%Y-%m') AS month_label,
                                COUNT(*) AS total_rides,
                                COALESCE(SUM(amount), 0) AS gross_revenue
                         FROM payments 
                         WHERE status = 'paid'
                         GROUP BY month_label 
                         ORDER BY month_label DESC LIMIT 12");
    $monthlyData = $mStmt->fetchAll();
} catch (Exception $e) {}
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-graph-up-arrow text-cyan me-2"></i>Revenue Reports & Financial Analytics</h4>
        <p class="text-muted small mb-0">Platform Settlement &bull; 15% Commission Model &bull; Real Database Aggregates</p>
    </div>
    <div class="mt-3 mt-md-0">
        <a href="reports.php?export=csv" class="btn btn-cyan btn-sm d-flex align-items-center gap-2">
            <i class="bi bi-download"></i> Export Revenue (CSV)
        </a>
    </div>
</div>

<!-- Revenue KPI Grid -->
<div class="row g-3 mb-4">
    <div class="col-sm-6 col-xl-3">
        <div class="dm-stat-widget">
            <small class="text-muted text-uppercase fw-bold">Gross Platform Volume</small>
            <h3 class="fw-bold mb-1 text-white">₹<?= number_format($totalGrossRevenue, 2) ?></h3>
            <small class="text-muted small"><?= $totalTransactions ?> Paid Transactions</small>
        </div>
    </div>
    <div class="col-sm-6 col-xl-3">
        <div class="dm-stat-widget" style="border-left-color: #10B981;">
            <small class="text-muted text-uppercase fw-bold">Platform Commission (15%)</small>
            <h3 class="fw-bold mb-1 text-success">₹<?= number_format($platformCommission, 2) ?></h3>
            <small class="text-success small">Net Operational Earnings</small>
        </div>
    </div>
    <div class="col-sm-6 col-xl-3">
        <div class="dm-stat-widget" style="border-left-color: #3B82F6;">
            <small class="text-muted text-uppercase fw-bold">Driver Payouts (85%)</small>
            <h3 class="fw-bold mb-1" style="color: #60A5FA;">₹<?= number_format($driverPayout, 2) ?></h3>
            <small class="text-muted small">Fleet Partner Share</small>
        </div>
    </div>
    <div class="col-sm-6 col-xl-3">
        <div class="dm-stat-widget" style="border-left-color: #F59E0B;">
            <small class="text-muted text-uppercase fw-bold">Average Ride Value</small>
            <h3 class="fw-bold mb-1 text-warning">₹<?= number_format($avgBookingValue, 2) ?></h3>
            <small class="text-muted small">Per Completed Booking</small>
        </div>
    </div>
</div>

<!-- Payment Modes Breakdown -->
<div class="row g-4 mb-4">
    <div class="col-md-6">
        <div class="dm-card p-4">
            <h6 class="fw-bold text-white mb-3">Settlement Channels</h6>
            <div class="d-flex justify-content-between align-items-center mb-2">
                <span class="text-muted">Digital UPI / Gateway Payment</span>
                <span class="fw-bold text-cyan">₹<?= number_format($upiTotal, 2) ?></span>
            </div>
            <div class="progress mb-4" style="height: 8px; background: rgba(255,255,255,0.05);">
                <?php $upiPct = $totalGrossRevenue > 0 ? ($upiTotal / $totalGrossRevenue) * 100 : 0; ?>
                <div class="progress-bar" style="width: <?= $upiPct ?>%; background: var(--dm-cyan);"></div>
            </div>

            <div class="d-flex justify-content-between align-items-center mb-2">
                <span class="text-muted">Direct Cash Collection</span>
                <span class="fw-bold text-warning">₹<?= number_format($cashTotal, 2) ?></span>
            </div>
            <div class="progress" style="height: 8px; background: rgba(255,255,255,0.05);">
                <?php $cashPct = $totalGrossRevenue > 0 ? ($cashTotal / $totalGrossRevenue) * 100 : 0; ?>
                <div class="progress-bar bg-warning" style="width: <?= $cashPct ?>%;"></div>
            </div>
        </div>
    </div>

    <div class="col-md-6">
        <div class="dm-card p-4">
            <h6 class="fw-bold text-white mb-2">GST Tax Collection Breakdown</h6>
            <p class="text-muted small mb-3">Aggregated GST calculation under GSTIN 19ABCDE1234F1Z5</p>
            <?php
            $taxBase = round($totalGrossRevenue / 1.05, 2);
            $totalTax = round($totalGrossRevenue - $taxBase, 2);
            ?>
            <div class="d-flex justify-content-between py-2 border-bottom" style="border-color: rgba(255,255,255,0.05) !important;">
                <span class="text-muted">Taxable Base Amount</span>
                <span class="text-white fw-semibold">₹<?= number_format($taxBase, 2) ?></span>
            </div>
            <div class="d-flex justify-content-between py-2 border-bottom" style="border-color: rgba(255,255,255,0.05) !important;">
                <span class="text-muted">CGST (2.5%)</span>
                <span class="text-white">₹<?= number_format($totalTax / 2, 2) ?></span>
            </div>
            <div class="d-flex justify-content-between py-2">
                <span class="text-muted">SGST (2.5%)</span>
                <span class="text-white">₹<?= number_format($totalTax / 2, 2) ?></span>
            </div>
        </div>
    </div>
</div>

<!-- Monthly Breakdown Table -->
<div class="dm-card">
    <div class="dm-card-header">
        <h5>Monthly Revenue Trends</h5>
    </div>
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Month</th>
                    <th>Completed Transactions</th>
                    <th>Gross Volume (INR)</th>
                    <th>Platform Share (15%)</th>
                    <th>Fleet Payout (85%)</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($monthlyData)): ?>
                    <tr>
                        <td colspan="5" class="text-center py-4 text-muted">No monthly billing history found</td>
                    </tr>
                <?php else: foreach ($monthlyData as $m): 
                    $mGross = (float)$m['gross_revenue'];
                    $mPlat  = round($mGross * 0.15, 2);
                    $mFleet = round($mGross * 0.85, 2);
                ?>
                    <tr>
                        <td class="fw-bold text-cyan"><?= date('F Y', strtotime($m['month_label'] . '-01')) ?></td>
                        <td><span class="badge bg-dark border" style="border-color: var(--dm-border) !important;"><?= $m['total_rides'] ?> Rides</span></td>
                        <td class="fw-bold text-white fs-6">₹<?= number_format($mGross, 2) ?></td>
                        <td class="text-success fw-semibold">₹<?= number_format($mPlat, 2) ?></td>
                        <td class="text-muted">₹<?= number_format($mFleet, 2) ?></td>
                    </tr>
                <?php endforeach; endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require_once __DIR__ . '/footer.php'; ?>
