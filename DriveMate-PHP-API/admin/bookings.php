<?php
// admin/bookings.php — DriveMate Booking & Reservation Operations
$pageTitle = 'Booking Management';
$activePage = 'bookings';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Admin Cancellation Override
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['cancel_booking'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $bId = (int)($_POST['booking_id'] ?? 0);
        $reason = trim($_POST['cancel_reason'] ?? 'Admin Override');
        if ($bId > 0) {
            $stmt = $db->prepare("UPDATE bookings SET status = 'cancelled', notes = CONCAT(COALESCE(notes, ''), ' [Cancelled by Admin: ', ?, ']') WHERE id = ?");
            $stmt->execute([$reason, $bId]);
            // Also cancel linked trip if active
            $db->prepare("UPDATE trips SET status = 'cancelled' WHERE booking_id = ? AND status = 'ongoing'")->execute([$bId]);
            log_admin_action('admin_cancel_booking', 'bookings', $bId, "Booking cancelled: $reason");
            $msg = "Booking #$bId cancelled successfully.";
        }
    }
}

// Search & Filter
$statusFilter = trim($_GET['status'] ?? '');
$typeFilter   = trim($_GET['type'] ?? '');
$search       = trim($_GET['search'] ?? '');

$sql = "SELECT b.*, 
               u_c.name AS customer_name, u_c.phone AS customer_phone,
               u_d.name AS driver_name, u_d.phone AS driver_phone
        FROM bookings b 
        LEFT JOIN users u_c ON b.user_id = u_c.id 
        LEFT JOIN users u_d ON b.driver_id = u_d.id 
        WHERE 1=1";

$params = [];
if (!empty($statusFilter)) {
    $sql .= " AND b.status = ?";
    $params[] = $statusFilter;
}
if (!empty($typeFilter)) {
    $sql .= " AND b.type = ?";
    $params[] = $typeFilter;
}
if (!empty($search)) {
    $sql .= " AND (b.id = ? OR u_c.name LIKE ? OR u_c.phone LIKE ? OR b.pickup_location LIKE ? OR b.destination LIKE ?)";
    $numId = (int)$search;
    $term = "%$search%";
    $params[] = $numId;
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
}

$sql .= " ORDER BY b.created_at DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$bookings = $stmt->fetchAll();
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-calendar-check-fill text-cyan me-2"></i>Booking Management</h4>
        <p class="text-muted small mb-0">Total Bookings Recorded: <strong><?= count($bookings) ?></strong> &bull; Complete Audit Trail</p>
    </div>
    <div class="mt-3 mt-md-0">
        <a href="trips.php" class="btn btn-cyan btn-sm d-flex align-items-center gap-2">
            <i class="bi bi-geo-alt-fill"></i> Track Live Rides Map &rarr;
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

<!-- Filter & Search Bar -->
<div class="dm-card p-3 mb-4">
    <form method="GET" class="row g-2 align-items-center">
        <div class="col-md-5">
            <input type="text" name="search" class="form-control form-control-dark" placeholder="Search Booking ID, Customer name, phone, or location..." value="<?= htmlspecialchars($search) ?>">
        </div>
        <div class="col-md-3">
            <select name="status" class="form-select form-select-dark">
                <option value="">All Trip Statuses</option>
                <option value="pending" <?= $statusFilter === 'pending' ? 'selected' : '' ?>>Pending Driver</option>
                <option value="confirmed" <?= $statusFilter === 'confirmed' ? 'selected' : '' ?>>Confirmed / Accepted</option>
                <option value="arrived" <?= $statusFilter === 'arrived' ? 'selected' : '' ?>>Driver Arrived</option>
                <option value="ongoing" <?= $statusFilter === 'ongoing' ? 'selected' : '' ?>>Ongoing Trip</option>
                <option value="completed" <?= $statusFilter === 'completed' ? 'selected' : '' ?>>Completed Trips</option>
                <option value="cancelled" <?= $statusFilter === 'cancelled' ? 'selected' : '' ?>>Cancelled</option>
            </select>
        </div>
        <div class="col-md-2">
            <select name="type" class="form-select form-select-dark">
                <option value="">All Services</option>
                <option value="hire_driver" <?= $typeFilter === 'hire_driver' ? 'selected' : '' ?>>Hire Driver</option>
                <option value="rent_car" <?= $typeFilter === 'rent_car' ? 'selected' : '' ?>>Rent Car</option>
                <option value="rent_car_driver" <?= $typeFilter === 'rent_car_driver' ? 'selected' : '' ?>>Car + Chauffeur</option>
            </select>
        </div>
        <div class="col-md-2 d-flex gap-2">
            <button type="submit" class="btn btn-cyan w-100"><i class="bi bi-funnel-fill me-1"></i> Filter</button>
            <?php if (!empty($search) || !empty($statusFilter) || !empty($typeFilter)): ?>
                <a href="bookings.php" class="btn btn-outline-secondary"><i class="bi bi-x-circle"></i></a>
            <?php endif; ?>
        </div>
    </form>
</div>

<!-- Bookings Table -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>ID / Type</th>
                    <th>Customer</th>
                    <th>Assigned Driver</th>
                    <th>Pickup & Destination</th>
                    <th>Distance</th>
                    <th>Agreed Fare</th>
                    <th>Payment</th>
                    <th>Trip Status</th>
                    <th class="text-end">Action</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($bookings)): ?>
                    <tr>
                        <td colspan="9" class="text-center py-5 text-muted">
                            <i class="bi bi-calendar-x fs-1 d-block mb-2"></i>
                            No bookings recorded matching filter criteria.
                        </td>
                    </tr>
                <?php else: foreach ($bookings as $b): ?>
                    <tr>
                        <td>
                            <div class="fw-bold text-cyan">#BK-<?= $b['id'] ?></div>
                            <span class="badge bg-dark border" style="border-color: var(--dm-border) !important; font-size: 0.7rem;">
                                <?= strtoupper(str_replace('_', ' ', $b['type'])) ?>
                            </span>
                        </td>
                        <td>
                            <div class="fw-semibold text-white"><?= htmlspecialchars($b['customer_name'] ?? 'Guest Customer') ?></div>
                            <small class="text-muted"><i class="bi bi-telephone me-1"></i><?= htmlspecialchars($b['customer_phone'] ?? '-') ?></small>
                        </td>
                        <td>
                            <?php if (!empty($b['driver_name'])): ?>
                                <div class="fw-semibold text-white"><?= htmlspecialchars($b['driver_name']) ?></div>
                                <small class="text-muted"><?= htmlspecialchars($b['driver_phone'] ?? '-') ?></small>
                            <?php else: ?>
                                <span class="badge bg-secondary">Unassigned</span>
                            <?php endif; ?>
                        </td>
                        <td style="max-width: 250px;">
                            <div class="text-truncate small text-muted"><i class="bi bi-circle-fill text-cyan me-1" style="font-size: 0.5rem;"></i> <?= htmlspecialchars($b['pickup_location'] ?? 'Not set') ?></div>
                            <div class="text-truncate small text-white"><i class="bi bi-geo-alt-fill text-danger me-1"></i> <?= htmlspecialchars($b['destination'] ?? 'Not set') ?></div>
                        </td>
                        <td>
                            <div class="text-white small fw-bold"><?= $b['distance_km'] ? $b['distance_km'] . ' km' : '-' ?></div>
                            <small class="text-muted"><?= $b['duration_minutes'] ? $b['duration_minutes'] . ' mins' : '' ?></small>
                        </td>
                        <td>
                            <div class="fw-bold text-white">₹<?= number_format($b['total_amount'], 2) ?></div>
                            <?php if (!empty($b['start_otp_verified_at'])): ?>
                                <small class="text-success d-block"><i class="bi bi-shield-check me-1"></i>OTP Verified</small>
                            <?php elseif (!empty($b['start_otp'])): ?>
                                <small class="text-info d-block"><i class="bi bi-shield-lock me-1"></i>OTP Active</small>
                            <?php endif; ?>
                        </td>
                        <td>
                            <?php if ($b['payment_status'] === 'paid'): ?>
                                <span class="badge badge-success-subtle">PAID</span>
                            <?php else: ?>
                                <span class="badge badge-warning-subtle">UNPAID</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <?php
                            $st = $b['status'];
                            $badge = 'bg-secondary';
                            if ($st === 'completed') $badge = 'badge-success-subtle';
                            elseif ($st === 'ongoing' || $st === 'arrived') $badge = 'badge-cyan';
                            elseif ($st === 'cancelled') $badge = 'badge-danger-subtle';
                            elseif ($st === 'confirmed' || $st === 'pending') $badge = 'badge-warning-subtle';
                            ?>
                            <span class="badge <?= $badge ?>"><?= strtoupper($st) ?></span>
                        </td>
                        <td class="text-end">
                            <div class="d-flex justify-content-end gap-1">
                                <?php if ($b['status'] === 'completed' && $b['payment_status'] === 'paid'): ?>
                                    <a href="invoice.php?booking_id=<?= $b['id'] ?>" target="_blank" class="btn btn-outline-info btn-sm py-1 px-2" style="font-size: 0.75rem;" title="View Invoice">
                                        <i class="bi bi-receipt"></i>
                                    </a>
                                <?php endif; ?>

                                <?php if ($b['status'] !== 'completed' && $b['status'] !== 'cancelled'): ?>
                                    <button class="btn btn-outline-danger btn-sm py-1 px-2" style="font-size: 0.75rem;" data-bs-toggle="modal" data-bs-target="#cancelModal<?= $b['id'] ?>" title="Cancel Booking">
                                        <i class="bi bi-x-circle"></i>
                                    </button>

                                    <!-- Cancellation Modal -->
                                    <div class="modal fade" id="cancelModal<?= $b['id'] ?>" tabindex="-1">
                                        <div class="modal-dialog modal-dialog-centered">
                                            <div class="modal-content" style="background: var(--dm-card); border: 1px solid var(--dm-border);">
                                                <form method="POST">
                                                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
                                                    <input type="hidden" name="booking_id" value="<?= $b['id'] ?>">
                                                    <div class="modal-header border-0 pb-0">
                                                        <h5 class="modal-title text-white">Cancel Booking #BK-<?= $b['id'] ?></h5>
                                                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                                                    </div>
                                                    <div class="modal-body text-start">
                                                        <p class="text-muted small">Please specify the administrative reason for terminating this booking:</p>
                                                        <textarea name="cancel_reason" class="form-control form-control-dark" rows="3" placeholder="e.g., Customer request, driver breakdown, security review..." required></textarea>
                                                    </div>
                                                    <div class="modal-footer border-0 pt-0">
                                                        <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Close</button>
                                                        <button type="submit" name="cancel_booking" class="btn btn-danger btn-sm">Confirm Cancellation</button>
                                                    </div>
                                                </form>
                                            </div>
                                        </div>
                                    </div>
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
