<?php
// admin/payments.php — DriveMate Payment & Invoice Management
$pageTitle = 'Payments & Invoices';
$activePage = 'payments';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Manual Cash Payment Verification Override
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['mark_paid'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $paymentId = (int)($_POST['payment_id'] ?? 0);
        $bId = (int)($_POST['booking_id'] ?? 0);
        if ($paymentId > 0) {
            $stmt = $db->prepare("UPDATE payments SET status = 'paid', paid_at = NOW(), notes = CONCAT(COALESCE(notes, ''), ' [Verified by Admin]') WHERE id = ?");
            $stmt->execute([$paymentId]);
            if ($bId > 0) {
                $db->prepare("UPDATE bookings SET payment_status = 'paid' WHERE id = ?")->execute([$bId]);
            }
            log_admin_action('verify_payment_manual', 'payments', $paymentId, "Marked payment as paid for booking #$bId");
            $msg = "Payment #$paymentId marked as PAID.";
        }
    }
}

// Search & Filter
$statusFilter = trim($_GET['status'] ?? '');
$methodFilter = trim($_GET['method'] ?? '');
$search       = trim($_GET['search'] ?? '');

$sql = "SELECT p.*, 
               b.type AS booking_type, b.pickup_location, b.destination,
               u.name AS customer_name, u.phone AS customer_phone
        FROM payments p 
        LEFT JOIN bookings b ON p.booking_id = b.id 
        LEFT JOIN users u ON p.user_id = u.id 
        WHERE 1=1";

$params = [];
if (!empty($statusFilter)) {
    $sql .= " AND p.status = ?";
    $params[] = $statusFilter;
}
if (!empty($methodFilter)) {
    $sql .= " AND p.payment_method = ?";
    $params[] = $methodFilter;
}
if (!empty($search)) {
    $sql .= " AND (p.id = ? OR p.booking_id = ? OR p.transaction_id LIKE ? OR u.name LIKE ? OR u.phone LIKE ?)";
    $term = "%$search%";
    $num = (int)$search;
    $params[] = $num;
    $params[] = $num;
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
}

$sql .= " ORDER BY p.created_at DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$payments = $stmt->fetchAll();

// Total Summary
$totalPaid = 0;
$totalPending = 0;
foreach ($payments as $p) {
    if ($p['status'] === 'paid') $totalPaid += (float)$p['amount'];
    else $totalPending += (float)$p['amount'];
}
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-credit-card-2-front-fill text-cyan me-2"></i>Payment & Invoice Management</h4>
        <p class="text-muted small mb-0">Total Payments: <strong><?= count($payments) ?></strong> &bull; Paid: <strong class="text-success">₹<?= number_format($totalPaid, 2) ?></strong></p>
    </div>
    <div class="mt-3 mt-md-0">
        <a href="reports.php" class="btn btn-cyan btn-sm d-flex align-items-center gap-2">
            <i class="bi bi-graph-up"></i> Financial Reports & Tax Summary &rarr;
        </a>
    </div>
</div>

<?php if (!empty($msg)): ?>
    <div class="alert alert-success alert-dismissible fade show border-0 d-flex align-items-center" style="background: rgba(16, 185, 129, 0.2); color: #34D399; border-radius: 12px;">
        <i class="bi bi-check-circle-fill me-2 fs-5"></i>
        <div><?= htmlspecialchars($msg) ?></div>
        <button type="button" class="btn-close btn-close-white ms-auto" data-bs-dismiss="alert"></button>
    </div>
<?php endif; ?>

<?php if (!empty($error)): ?>
    <div class="alert alert-danger alert-dismissible fade show border-0 d-flex align-items-center" style="background: rgba(239, 68, 68, 0.2); color: #FCA5A5; border-radius: 12px;">
        <i class="bi bi-exclamation-triangle-fill me-2 fs-5"></i>
        <div><?= htmlspecialchars($error) ?></div>
        <button type="button" class="btn-close btn-close-white ms-auto" data-bs-dismiss="alert"></button>
    </div>
<?php endif; ?>

<!-- Filter Bar -->
<div class="dm-card p-3 mb-4">
    <form method="GET" class="row g-2 align-items-center">
        <div class="col-md-5">
            <input type="text" name="search" class="form-control form-control-dark" placeholder="Search payment ID, booking, customer, or UTR/Txn..." value="<?= htmlspecialchars($search) ?>">
        </div>
        <div class="col-md-3">
            <select name="status" class="form-select form-select-dark">
                <option value="">All Payment Statuses</option>
                <option value="paid" <?= $statusFilter === 'paid' ? 'selected' : '' ?>>Paid & Verified</option>
                <option value="pending" <?= $statusFilter === 'pending' ? 'selected' : '' ?>>Pending / Unpaid</option>
                <option value="failed" <?= $statusFilter === 'failed' ? 'selected' : '' ?>>Failed Transactions</option>
                <option value="refunded" <?= $statusFilter === 'refunded' ? 'selected' : '' ?>>Refunded</option>
            </select>
        </div>
        <div class="col-md-2">
            <select name="method" class="form-select form-select-dark">
                <option value="">All Methods</option>
                <option value="cash" <?= $methodFilter === 'cash' ? 'selected' : '' ?>>Cash</option>
                <option value="upi" <?= $methodFilter === 'upi' ? 'selected' : '' ?>>UPI / QR</option>
                <option value="card" <?= $methodFilter === 'card' ? 'selected' : '' ?>>Debit/Credit Card</option>
            </select>
        </div>
        <div class="col-md-2 d-flex gap-2">
            <button type="submit" class="btn btn-cyan w-100"><i class="bi bi-funnel-fill me-1"></i> Filter</button>
            <?php if (!empty($search) || !empty($statusFilter) || !empty($methodFilter)): ?>
                <a href="payments.php" class="btn btn-outline-secondary"><i class="bi bi-x-circle"></i></a>
            <?php endif; ?>
        </div>
    </form>
</div>

<!-- Payments Table -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Invoice / ID</th>
                    <th>Booking Ref</th>
                    <th>Customer</th>
                    <th>Amount</th>
                    <th>Method</th>
                    <th>Gateway Txn Ref</th>
                    <th>Date</th>
                    <th>Status</th>
                    <th class="text-end">Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($payments)): ?>
                    <tr>
                        <td colspan="9" class="text-center py-5 text-muted">
                            <i class="bi bi-wallet2 fs-1 d-block mb-2"></i>
                            No payment transactions recorded matching criteria.
                        </td>
                    </tr>
                <?php else: foreach ($payments as $p): ?>
                    <tr>
                        <td>
                            <div class="fw-bold text-cyan">#PAY-<?= $p['id'] ?></div>
                            <small class="text-muted">INV-<?= str_pad($p['id'], 5, '0', STR_PAD_LEFT) ?></small>
                        </td>
                        <td>
                            <a href="bookings.php?search=<?= $p['booking_id'] ?>" class="text-white fw-bold">#BK-<?= $p['booking_id'] ?></a>
                            <div class="small text-muted"><?= strtoupper(str_replace('_', ' ', $p['booking_type'] ?? 'Trip')) ?></div>
                        </td>
                        <td>
                            <div class="fw-semibold text-white"><?= htmlspecialchars($p['customer_name'] ?? 'Customer #' . $p['user_id']) ?></div>
                            <small class="text-muted"><?= htmlspecialchars($p['customer_phone'] ?? '-') ?></small>
                        </td>
                        <td class="fw-bold text-white fs-6">₹<?= number_format($p['amount'], 2) ?></td>
                        <td>
                            <span class="badge bg-dark border text-uppercase" style="border-color: var(--dm-border) !important;">
                                <?= htmlspecialchars($p['payment_method']) ?>
                            </span>
                        </td>
                        <td>
                            <code class="small text-muted"><?= htmlspecialchars($p['transaction_id'] ?: 'CASH_SETTLED') ?></code>
                        </td>
                        <td>
                            <div class="small text-white"><?= date('M d, Y', strtotime($p['created_at'])) ?></div>
                            <small class="text-muted"><?= date('H:i', strtotime($p['created_at'])) ?></small>
                        </td>
                        <td>
                            <?php if ($p['status'] === 'paid'): ?>
                                <span class="badge badge-success-subtle"><i class="bi bi-check-circle-fill me-1"></i>PAID</span>
                            <?php elseif ($p['status'] === 'pending'): ?>
                                <span class="badge badge-warning-subtle"><i class="bi bi-clock me-1"></i>PENDING</span>
                            <?php else: ?>
                                <span class="badge badge-danger-subtle"><?= strtoupper($p['status']) ?></span>
                            <?php endif; ?>
                        </td>
                        <td class="text-end">
                            <div class="d-flex justify-content-end gap-1">
                                <a href="invoice.php?booking_id=<?= $p['booking_id'] ?>" target="_blank" class="btn btn-outline-info btn-sm py-1 px-2" style="font-size: 0.78rem;" title="View / Print Tax Invoice">
                                    <i class="bi bi-printer"></i> Invoice
                                </a>

                                <?php if ($p['status'] !== 'paid'): ?>
                                    <form method="POST" class="d-inline" onsubmit="return confirm('Manually mark payment #PAY-<?= $p['id'] ?> as PAID?');">
                                        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
                                        <input type="hidden" name="payment_id" value="<?= $p['id'] ?>">
                                        <input type="hidden" name="booking_id" value="<?= $p['booking_id'] ?>">
                                        <button type="submit" name="mark_paid" class="btn btn-sm btn-success py-1 px-2" style="font-size: 0.78rem;" title="Mark as Verified Cash/UPI">
                                            <i class="bi bi-check2"></i> Mark Paid
                                        </button>
                                    </form>
                                <?php endif; ?>
                            </div>
                        </td>
                    </tr>
                <?php endforeach; endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require_once __DIR__ . '/footer.php'; ?>
