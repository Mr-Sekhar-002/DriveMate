<?php
// admin/drivers.php — DriveMate Driver Fleet Management
$pageTitle = 'Driver Fleet Management';
$activePage = 'drivers';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Driver Verification / Suspension
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action_driver'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $driverProfileId = (int)($_POST['driver_profile_id'] ?? 0);
        $action = $_POST['action_driver']; // 'verify' or 'suspend'
        $newStatus = ($action === 'verify') ? 'verified' : 'rejected';

        if ($driverProfileId > 0) {
            $stmt = $db->prepare("UPDATE driver_profile SET status = ? WHERE id = ?");
            $stmt->execute([$newStatus, $driverProfileId]);
            log_admin_action('update_driver_status', 'driver_profile', $driverProfileId, "Status set to $newStatus");
            $msg = "Driver profile #$driverProfileId updated to " . strtoupper($newStatus);
        }
    }
}

// Search & Filter
$search = trim($_GET['search'] ?? '');
$statusFilter = trim($_GET['status'] ?? '');
$onlineFilter = trim($_GET['online'] ?? '');

$sql = "SELECT dp.*, u.name, u.email, u.phone, u.created_at AS user_created_at 
        FROM driver_profile dp 
        JOIN users u ON dp.user_id = u.id 
        WHERE 1=1";

$params = [];
if (!empty($search)) {
    $sql .= " AND (u.name LIKE ? OR u.phone LIKE ? OR dp.license_number LIKE ? OR dp.vehicle_model LIKE ?)";
    $term = "%$search%";
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
}
if (!empty($statusFilter)) {
    $sql .= " AND dp.status = ?";
    $params[] = $statusFilter;
}
if ($onlineFilter !== '') {
    $sql .= " AND dp.is_online = ?";
    $params[] = (int)$onlineFilter;
}

$sql .= " ORDER BY dp.created_at DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$drivers = $stmt->fetchAll();
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-person-badge-fill text-cyan me-2"></i>Driver Fleet Management</h4>
        <p class="text-muted small mb-0">Total Fleet Drivers: <strong><?= count($drivers) ?></strong> &bull; Integrated KYC & Live Telemetry</p>
    </div>
    <div class="mt-3 mt-md-0">
        <a href="kyc.php" class="btn btn-cyan btn-sm d-flex align-items-center gap-2">
            <i class="bi bi-file-earmark-check-fill"></i> Review Driver KYC Documents &rarr;
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

<!-- Search and Filters -->
<div class="dm-card p-3 mb-4">
    <form method="GET" class="row g-2 align-items-center">
        <div class="col-md-5">
            <div class="input-group">
                <span class="input-group-text bg-dark border-0 text-cyan"><i class="bi bi-search"></i></span>
                <input type="text" name="search" class="form-control form-control-dark" placeholder="Search driver name, phone, license..." value="<?= htmlspecialchars($search) ?>">
            </div>
        </div>
        <div class="col-md-3">
            <select name="status" class="form-select form-select-dark">
                <option value="">All Verification Statuses</option>
                <option value="verified" <?= $statusFilter === 'verified' ? 'selected' : '' ?>>Verified Drivers</option>
                <option value="pending" <?= $statusFilter === 'pending' ? 'selected' : '' ?>>Pending Approval</option>
                <option value="rejected" <?= $statusFilter === 'rejected' ? 'selected' : '' ?>>Rejected / Suspended</option>
            </select>
        </div>
        <div class="col-md-2">
            <select name="online" class="form-select form-select-dark">
                <option value="">Any Telemetry</option>
                <option value="1" <?= $onlineFilter === '1' ? 'selected' : '' ?>>Online Now</option>
                <option value="0" <?= $onlineFilter === '0' ? 'selected' : '' ?>>Offline</option>
            </select>
        </div>
        <div class="col-md-2 d-flex gap-2">
            <button type="submit" class="btn btn-cyan w-100"><i class="bi bi-funnel-fill me-1"></i> Filter</button>
            <?php if (!empty($search) || !empty($statusFilter) || $onlineFilter !== ''): ?>
                <a href="drivers.php" class="btn btn-outline-secondary"><i class="bi bi-x-circle"></i></a>
            <?php endif; ?>
        </div>
    </form>
</div>

<!-- Driver Fleet Table -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Driver Profile</th>
                    <th>Telemetry</th>
                    <th>License / Vehicle</th>
                    <th>Rating</th>
                    <th>Completed Rides</th>
                    <th>Earnings</th>
                    <th>KYC Status</th>
                    <th class="text-end">Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($drivers)): ?>
                    <tr>
                        <td colspan="8" class="text-center py-5 text-muted">
                            <i class="bi bi-person-x fs-1 d-block mb-2"></i>
                            No drivers found matching your filter criteria.
                        </td>
                    </tr>
                <?php else: foreach ($drivers as $d): ?>
                    <tr>
                        <td>
                            <div class="d-flex align-items-center gap-3">
                                <div class="rounded-circle d-flex align-items-center justify-content-center text-dark fw-bold" style="background: linear-gradient(135deg, #00F2FE 0%, #4FACFE 100%); width: 38px; height: 38px;">
                                    <?= strtoupper(substr($d['name'], 0, 1)) ?>
                                </div>
                                <div>
                                    <div class="fw-bold text-white"><?= htmlspecialchars($d['name']) ?></div>
                                    <small class="text-muted"><i class="bi bi-telephone me-1"></i><?= htmlspecialchars($d['phone']) ?></small>
                                </div>
                            </div>
                        </td>
                        <td>
                            <?php if (!empty($d['is_online'])): ?>
                                <span class="badge badge-success-subtle d-inline-flex align-items-center gap-1">
                                    <span class="spinner-grow spinner-grow-sm text-success" style="width: 6px; height: 6px;"></span> ONLINE
                                </span>
                            <?php else: ?>
                                <span class="badge bg-secondary">OFFLINE</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <div class="text-white small fw-semibold"><?= htmlspecialchars($d['license_number'] ?: 'Not Provided') ?></div>
                            <small class="text-muted"><?= htmlspecialchars($d['vehicle_model'] ?: 'Generic Car') ?></small>
                        </td>
                        <td>
                            <div class="d-flex align-items-center gap-1">
                                <i class="bi bi-star-fill text-warning small"></i>
                                <span class="fw-bold text-white"><?= number_format($d['avg_rating'], 1) ?></span>
                            </div>
                        </td>
                        <td><span class="badge bg-dark border" style="border-color: var(--dm-border) !important;"><?= $d['total_trips'] ?> Trips</span></td>
                        <td class="fw-bold text-cyan">₹<?= number_format($d['earnings'], 2) ?></td>
                        <td>
                            <?php if ($d['status'] === 'verified'): ?>
                                <span class="badge badge-success-subtle"><i class="bi bi-check-circle-fill me-1"></i>VERIFIED</span>
                            <?php elseif ($d['status'] === 'pending'): ?>
                                <span class="badge badge-warning-subtle"><i class="bi bi-clock-history me-1"></i>PENDING</span>
                            <?php else: ?>
                                <span class="badge badge-danger-subtle"><i class="bi bi-x-circle-fill me-1"></i>SUSPENDED</span>
                            <?php endif; ?>
                        </td>
                        <td class="text-end">
                            <div class="d-flex justify-content-end gap-2">
                                <a href="kyc.php?user_id=<?= $d['user_id'] ?>" class="btn btn-outline-info btn-sm py-1 px-2" style="font-size: 0.8rem;" title="View Documents">
                                    <i class="bi bi-files"></i> KYC
                                </a>
                                <form method="POST" class="d-inline" onsubmit="return confirm('Change status for driver <?= addslashes($d['name']) ?>?');">
                                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
                                    <input type="hidden" name="driver_profile_id" value="<?= $d['id'] ?>">
                                    <?php if ($d['status'] !== 'verified'): ?>
                                        <button type="submit" name="action_driver" value="verify" class="btn btn-success btn-sm py-1 px-2" style="font-size: 0.8rem;">
                                            <i class="bi bi-check-lg"></i> Verify
                                        </button>
                                    <?php else: ?>
                                        <button type="submit" name="action_driver" value="suspend" class="btn btn-outline-danger btn-sm py-1 px-2" style="font-size: 0.8rem;">
                                            <i class="bi bi-ban"></i> Suspend
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
