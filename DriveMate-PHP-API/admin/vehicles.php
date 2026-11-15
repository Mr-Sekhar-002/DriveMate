<?php
// admin/vehicles.php — DriveMate Vehicle & Rental Listing Approvals
$pageTitle = 'Vehicle & Rental Approvals';
$activePage = 'vehicles';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Vehicle Approval / Deactivation
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action_vehicle'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $vehicleId = (int)($_POST['vehicle_id'] ?? 0);
        $action = $_POST['action_vehicle']; // 'activate' or 'deactivate'
        $newStatus = ($action === 'activate') ? 'active' : 'inactive';

        if ($vehicleId > 0) {
            $stmt = $db->prepare("UPDATE vehicles SET status = ? WHERE id = ?");
            $stmt->execute([$newStatus, $vehicleId]);
            // Also update associated car_listings if any
            $db->prepare("UPDATE car_listings SET status = ? WHERE vehicle_id = ?")->execute([$newStatus, $vehicleId]);

            log_admin_action('update_vehicle_status', 'vehicles', $vehicleId, "Status updated to $newStatus");
            $msg = "Vehicle #$vehicleId status set to " . strtoupper($newStatus);
        }
    }
}

// Search & Filter
$ownerFilter = (int)($_GET['owner_id'] ?? 0);
$statusFilter = trim($_GET['status'] ?? '');
$search = trim($_GET['search'] ?? '');

$sql = "SELECT v.*, u.name AS owner_name, u.phone AS owner_phone,
               cl.id AS listing_id, cl.type AS listing_type, cl.daily_rate, cl.hourly_rate, cl.file_url 
        FROM vehicles v 
        JOIN users u ON v.owner_id = u.id 
        LEFT JOIN car_listings cl ON v.id = cl.vehicle_id 
        WHERE 1=1";

$params = [];
if ($ownerFilter > 0) {
    $sql .= " AND v.owner_id = ?";
    $params[] = $ownerFilter;
}
if (!empty($statusFilter)) {
    $sql .= " AND v.status = ?";
    $params[] = $statusFilter;
}
if (!empty($search)) {
    $sql .= " AND (v.model LIKE ? OR v.number_plate LIKE ? OR u.name LIKE ?)";
    $term = "%$search%";
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
}

$sql .= " ORDER BY v.created_at DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$vehicles = $stmt->fetchAll();
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-car-front-fill text-cyan me-2"></i>Vehicle & Fleet Approvals</h4>
        <p class="text-muted small mb-0">Total Fleet Vehicles Listed: <strong><?= count($vehicles) ?></strong> &bull; Self-Drive & Chauffeur Fleet</p>
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

<!-- Search Bar -->
<div class="dm-card p-3 mb-4">
    <form method="GET" class="row g-2 align-items-center">
        <div class="col-md-6">
            <input type="text" name="search" class="form-control form-control-dark" placeholder="Search model, registration number, or owner name..." value="<?= htmlspecialchars($search) ?>">
        </div>
        <div class="col-md-4">
            <select name="status" class="form-select form-select-dark">
                <option value="">All Statuses</option>
                <option value="active" <?= $statusFilter === 'active' ? 'selected' : '' ?>>Active Fleet</option>
                <option value="inactive" <?= $statusFilter === 'inactive' ? 'selected' : '' ?>>Inactive / Under Review</option>
            </select>
        </div>
        <div class="col-md-2 d-flex gap-2">
            <button type="submit" class="btn btn-cyan w-100"><i class="bi bi-funnel-fill me-1"></i> Filter</button>
            <?php if (!empty($search) || !empty($statusFilter) || $ownerFilter > 0): ?>
                <a href="vehicles.php" class="btn btn-outline-secondary"><i class="bi bi-x-circle"></i></a>
            <?php endif; ?>
        </div>
    </form>
</div>

<!-- Vehicles Table -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Vehicle Details</th>
                    <th>Number Plate</th>
                    <th>Partner / Owner</th>
                    <th>Capacity / Color</th>
                    <th>Rental Rates</th>
                    <th>Status</th>
                    <th class="text-end">Approval Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($vehicles)): ?>
                    <tr>
                        <td colspan="7" class="text-center py-5 text-muted">
                            <i class="bi bi-car-front fs-1 d-block mb-2"></i>
                            No vehicles listed in the system matching criteria.
                        </td>
                    </tr>
                <?php else: foreach ($vehicles as $v): ?>
                    <tr>
                        <td>
                            <div class="d-flex align-items-center gap-3">
                                <div class="rounded-3 p-2" style="background: rgba(0, 242, 254, 0.1); color: var(--dm-cyan);">
                                    <i class="bi bi-car-front-fill fs-4"></i>
                                </div>
                                <div>
                                    <div class="fw-bold text-white"><?= htmlspecialchars($v['model']) ?></div>
                                    <small class="text-muted"><?= strtoupper(htmlspecialchars($v['type'])) ?></small>
                                </div>
                            </div>
                        </td>
                        <td>
                            <span class="badge bg-dark border text-warning fw-bold px-2 py-1" style="letter-spacing: 1px;">
                                <?= htmlspecialchars($v['number_plate']) ?>
                            </span>
                        </td>
                        <td>
                            <div class="fw-semibold text-white"><?= htmlspecialchars($v['owner_name']) ?></div>
                            <small class="text-muted"><?= htmlspecialchars($v['owner_phone']) ?></small>
                        </td>
                        <td>
                            <span class="text-white"><?= $v['capacity'] ?> Seater</span> &bull; 
                            <span class="text-muted"><?= htmlspecialchars($v['color'] ?: 'Standard') ?></span>
                        </td>
                        <td>
                            <?php if (!empty($v['daily_rate'])): ?>
                                <span class="fw-bold text-cyan">₹<?= number_format($v['daily_rate'], 0) ?></span>/day
                            <?php else: ?>
                                <span class="text-muted small">Not Listed</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <?php if ($v['status'] === 'active'): ?>
                                <span class="badge badge-success-subtle"><i class="bi bi-check-circle-fill me-1"></i>ACTIVE</span>
                            <?php else: ?>
                                <span class="badge badge-warning-subtle"><i class="bi bi-clock-history me-1"></i>INACTIVE</span>
                            <?php endif; ?>
                        </td>
                        <td class="text-end">
                            <form method="POST" class="d-inline" onsubmit="return confirm('Update status for vehicle <?= addslashes($v['model']) ?>?');">
                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
                                <input type="hidden" name="vehicle_id" value="<?= $v['id'] ?>">
                                <?php if ($v['status'] !== 'active'): ?>
                                    <button type="submit" name="action_vehicle" value="activate" class="btn btn-sm btn-success py-1 px-2" style="font-size: 0.8rem;">
                                        <i class="bi bi-check-lg"></i> Approve
                                    </button>
                                <?php else: ?>
                                    <button type="submit" name="action_vehicle" value="deactivate" class="btn btn-sm btn-outline-danger py-1 px-2" style="font-size: 0.8rem;">
                                        <i class="bi bi-slash-circle"></i> Suspend
                                    </button>
                                <?php endif; ?>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require_once __DIR__ . '/footer.php'; ?>
