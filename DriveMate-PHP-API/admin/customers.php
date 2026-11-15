<?php
// admin/customers.php — DriveMate Customer Management
$pageTitle = 'Customer Management';
$activePage = 'customers';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Customer Status Toggle (Active / Suspended)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['toggle_status'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $userId = (int)($_POST['user_id'] ?? 0);
        $newStatus = ($_POST['status'] === 'active') ? 'inactive' : 'active';
        if ($userId > 0) {
            $stmt = $db->prepare("UPDATE users SET status = ? WHERE id = ? AND role = 'customer'");
            $stmt->execute([$newStatus, $userId]);
            log_admin_action('toggle_customer_status', 'user', $userId, "Changed customer status to $newStatus");
            $msg = "Customer #$userId status updated to " . strtoupper($newStatus);
        }
    }
}

// Search & Filter
$search = trim($_GET['search'] ?? '');
$statusFilter = trim($_GET['status'] ?? '');

$sql = "SELECT u.*, 
               COUNT(b.id) AS total_bookings,
               COALESCE(SUM(CASE WHEN b.payment_status = 'paid' THEN b.total_amount ELSE 0 END), 0) AS total_spent
        FROM users u 
        LEFT JOIN bookings b ON u.id = b.user_id 
        WHERE u.role = 'customer'";

$params = [];
if (!empty($search)) {
    $sql .= " AND (u.name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)";
    $term = "%$search%";
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
}
if (!empty($statusFilter) && in_array($statusFilter, ['active', 'inactive'])) {
    $sql .= " AND u.status = ?";
    $params[] = $statusFilter;
}

$sql .= " GROUP BY u.id ORDER BY u.created_at DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$customers = $stmt->fetchAll();
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-people-fill text-cyan me-2"></i>Customer Management</h4>
        <p class="text-muted small mb-0">Total Registered Customers: <strong><?= count($customers) ?></strong> &bull; Live MySQL Records</p>
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

<!-- Search and Filters -->
<div class="dm-card p-3 mb-4">
    <form method="GET" class="row g-2 align-items-center">
        <div class="col-md-6">
            <div class="input-group">
                <span class="input-group-text bg-dark border-0 text-cyan"><i class="bi bi-search"></i></span>
                <input type="text" name="search" class="form-control form-control-dark" placeholder="Search by customer name, phone, or email..." value="<?= htmlspecialchars($search) ?>">
            </div>
        </div>
        <div class="col-md-3">
            <select name="status" class="form-select form-select-dark">
                <option value="">All Statuses</option>
                <option value="active" <?= $statusFilter === 'active' ? 'selected' : '' ?>>Active Only</option>
                <option value="inactive" <?= $statusFilter === 'inactive' ? 'selected' : '' ?>>Suspended / Inactive</option>
            </select>
        </div>
        <div class="col-md-3 d-flex gap-2">
            <button type="submit" class="btn btn-cyan w-100"><i class="bi bi-funnel-fill me-1"></i> Filter</button>
            <?php if (!empty($search) || !empty($statusFilter)): ?>
                <a href="customers.php" class="btn btn-outline-secondary" title="Reset Filters"><i class="bi bi-x-circle"></i></a>
            <?php endif; ?>
        </div>
    </form>
</div>

<!-- Customers Table -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Customer</th>
                    <th>Contact Info</th>
                    <th>Total Rides</th>
                    <th>Total Spent</th>
                    <th>Joined Date</th>
                    <th>Status</th>
                    <th class="text-end">Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($customers)): ?>
                    <tr>
                        <td colspan="7" class="text-center py-5 text-muted">
                            <i class="bi bi-person-x fs-1 d-block mb-2"></i>
                            No customer records found matching your query.
                        </td>
                    </tr>
                <?php else: foreach ($customers as $c): ?>
                    <tr>
                        <td>
                            <div class="d-flex align-items-center gap-3">
                                <div class="rounded-circle d-flex align-items-center justify-content-center text-dark fw-bold" style="background: rgba(0, 242, 254, 0.2); color: var(--dm-cyan); width: 38px; height: 38px; border: 1px solid var(--dm-border);">
                                    <?= strtoupper(substr($c['name'], 0, 1)) ?>
                                </div>
                                <div>
                                    <div class="fw-bold text-white"><?= htmlspecialchars($c['name']) ?></div>
                                    <small class="text-muted">UID: #CST-<?= $c['id'] ?></small>
                                </div>
                            </div>
                        </td>
                        <td>
                            <div><i class="bi bi-telephone text-muted me-1 small"></i> <?= htmlspecialchars($c['phone'] ?? '-') ?></div>
                            <small class="text-muted"><i class="bi bi-envelope text-muted me-1 small"></i> <?= htmlspecialchars($c['email'] ?? '-') ?></small>
                        </td>
                        <td>
                            <span class="badge bg-dark border" style="border-color: var(--dm-border) !important;">
                                <?= $c['total_bookings'] ?> Bookings
                            </span>
                        </td>
                        <td class="fw-bold text-cyan">₹<?= number_format($c['total_spent'], 2) ?></td>
                        <td><small class="text-muted"><?= date('M d, Y', strtotime($c['created_at'])) ?></small></td>
                        <td>
                            <?php if ($c['status'] === 'active'): ?>
                                <span class="badge badge-success-subtle"><i class="bi bi-check-circle-fill me-1"></i>ACTIVE</span>
                            <?php else: ?>
                                <span class="badge badge-danger-subtle"><i class="bi bi-slash-circle-fill me-1"></i>SUSPENDED</span>
                            <?php endif; ?>
                        </td>
                        <td class="text-end">
                            <div class="d-flex justify-content-end gap-2">
                                <a href="bookings.php?search=<?= urlencode($c['name']) ?>" class="btn btn-outline-info btn-sm py-1 px-2" style="font-size: 0.8rem;" title="View Bookings">
                                    <i class="bi bi-journal-text"></i> Rides
                                </a>
                                <form method="POST" onsubmit="return confirm('Are you sure you want to change status of <?= addslashes($c['name']) ?>?');" class="d-inline">
                                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
                                    <input type="hidden" name="user_id" value="<?= $c['id'] ?>">
                                    <input type="hidden" name="status" value="<?= $c['status'] ?>">
                                    <?php if ($c['status'] === 'active'): ?>
                                        <button type="submit" name="toggle_status" class="btn btn-outline-danger btn-sm py-1 px-2" style="font-size: 0.8rem;" title="Suspend Customer">
                                            <i class="bi bi-person-x"></i> Suspend
                                        </button>
                                    <?php else: ?>
                                        <button type="submit" name="toggle_status" class="btn btn-outline-success btn-sm py-1 px-2" style="font-size: 0.8rem;" title="Activate Customer">
                                            <i class="bi bi-person-check"></i> Activate
                                        </button>
                                    <?php endif; ?>
                                </form>
                            </div>
                        </td>
                    </tr>
                <?php endforeach; endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require_once __DIR__ . '/footer.php'; ?>
