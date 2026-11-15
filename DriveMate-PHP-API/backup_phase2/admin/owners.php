<?php
// admin/owners.php — DriveMate Car Owner Management
$pageTitle = 'Car Owner Management';
$activePage = 'owners';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Owner Status Toggle
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['toggle_owner'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $ownerId = (int)($_POST['owner_id'] ?? 0);
        $newStatus = ($_POST['status'] === 'active') ? 'inactive' : 'active';
        if ($ownerId > 0) {
            $stmt = $db->prepare("UPDATE users SET status = ? WHERE id = ? AND role = 'owner'");
            $stmt->execute([$newStatus, $ownerId]);
            log_admin_action('toggle_owner_status', 'user', $ownerId, "Owner status changed to $newStatus");
            $msg = "Owner #$ownerId status updated to " . strtoupper($newStatus);
        }
    }
}

// Search
$search = trim($_GET['search'] ?? '');
$sql = "SELECT u.*, 
               COUNT(DISTINCT v.id) AS total_vehicles,
               COUNT(DISTINCT cl.id) AS total_listings
        FROM users u 
        LEFT JOIN vehicles v ON u.id = v.owner_id 
        LEFT JOIN car_listings cl ON u.id = cl.owner_id 
        WHERE u.role = 'owner'";

$params = [];
if (!empty($search)) {
    $sql .= " AND (u.name LIKE ? OR u.email LIKE ? OR u.phone LIKE ?)";
    $term = "%$search%";
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
}

$sql .= " GROUP BY u.id ORDER BY u.created_at DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$owners = $stmt->fetchAll();
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-building-fill text-cyan me-2"></i>Car Owner Management</h4>
        <p class="text-muted small mb-0">Total Fleet Partners / Car Owners: <strong><?= count($owners) ?></strong></p>
    </div>
    <div class="mt-3 mt-md-0">
        <a href="vehicles.php" class="btn btn-cyan btn-sm d-flex align-items-center gap-2">
            <i class="bi bi-car-front-fill"></i> View Listed Vehicles &rarr;
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

<!-- Owners List Table -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Owner Profile</th>
                    <th>Contact Information</th>
                    <th>Registered Vehicles</th>
                    <th>Active Rental Listings</th>
                    <th>Partner Since</th>
                    <th>Status</th>
                    <th class="text-end">Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($owners)): ?>
                    <tr>
                        <td colspan="7" class="text-center py-5 text-muted">
                            <i class="bi bi-person-x fs-1 d-block mb-2"></i>
                            No car owner records found in the database.
                        </td>
                    </tr>
                <?php else: foreach ($owners as $o): ?>
                    <tr>
                        <td>
                            <div class="d-flex align-items-center gap-3">
                                <div class="rounded-circle d-flex align-items-center justify-content-center text-dark fw-bold" style="background: linear-gradient(135deg, #00C6FF 0%, #0072FF 100%); width: 38px; height: 38px;">
                                    <?= strtoupper(substr($o['name'], 0, 1)) ?>
                                </div>
                                <div>
                                    <div class="fw-bold text-white"><?= htmlspecialchars($o['name']) ?></div>
                                    <small class="text-muted">ID: #OWN-<?= $o['id'] ?></small>
                                </div>
                            </div>
                        </td>
                        <td>
                            <div><i class="bi bi-telephone text-muted me-1 small"></i> <?= htmlspecialchars($o['phone'] ?? '-') ?></div>
                            <small class="text-muted"><i class="bi bi-envelope text-muted me-1 small"></i> <?= htmlspecialchars($o['email'] ?? '-') ?></small>
                        </td>
                        <td>
                            <span class="badge bg-dark border" style="border-color: var(--dm-border) !important;">
                                <?= $o['total_vehicles'] ?> Registered
                            </span>
                        </td>
                        <td>
                            <span class="badge bg-dark border" style="border-color: var(--dm-border) !important;">
                                <?= $o['total_listings'] ?> Rental Ads
                            </span>
                        </td>
                        <td><small class="text-muted"><?= date('M d, Y', strtotime($o['created_at'])) ?></small></td>
                        <td>
                            <?php if ($o['status'] === 'active'): ?>
                                <span class="badge badge-success-subtle"><i class="bi bi-check-circle-fill me-1"></i>ACTIVE</span>
                            <?php else: ?>
                                <span class="badge badge-danger-subtle"><i class="bi bi-ban me-1"></i>SUSPENDED</span>
                            <?php endif; ?>
                        </td>
                        <td class="text-end">
                            <div class="d-flex justify-content-end gap-2">
                                <a href="vehicles.php?owner_id=<?= $o['id'] ?>" class="btn btn-outline-info btn-sm py-1 px-2" style="font-size: 0.8rem;" title="View Vehicles">
                                    <i class="bi bi-car-front"></i> Fleet
                                </a>
                                <form method="POST" class="d-inline" onsubmit="return confirm('Change status for owner <?= addslashes($o['name']) ?>?');">
                                    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
                                    <input type="hidden" name="owner_id" value="<?= $o['id'] ?>">
                                    <input type="hidden" name="status" value="<?= $o['status'] ?>">
                                    <?php if ($o['status'] === 'active'): ?>
                                        <button type="submit" name="toggle_owner" class="btn btn-outline-danger btn-sm py-1 px-2" style="font-size: 0.8rem;" title="Suspend Partner">
                                            <i class="bi bi-slash-circle"></i> Suspend
                                        </button>
                                    <?php else: ?>
                                        <button type="submit" name="toggle_owner" class="btn btn-outline-success btn-sm py-1 px-2" style="font-size: 0.8rem;" title="Activate Partner">
                                            <i class="bi bi-check-circle"></i> Activate
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
