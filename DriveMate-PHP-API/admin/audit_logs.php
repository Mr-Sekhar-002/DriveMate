<?php
// admin/audit_logs.php — DriveMate Security & Administrative Audit Trail
$pageTitle = 'Security & Audit Logs';
$activePage = 'audit_logs';
require_once __DIR__ . '/header.php';

// Filter by Action
$actionFilter = trim($_GET['action_filter'] ?? '');

$sql = "SELECT a.*, u.name AS admin_name, u.email AS admin_email 
        FROM admin_audit_logs a 
        LEFT JOIN users u ON a.admin_id = u.id 
        WHERE 1=1";

$params = [];
if (!empty($actionFilter)) {
    $sql .= " AND a.action = ?";
    $params[] = $actionFilter;
}

$sql .= " ORDER BY a.created_at DESC LIMIT 100";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$logs = $stmt->fetchAll();

// Distinct actions for dropdown
$actions = $db->query("SELECT DISTINCT action FROM admin_audit_logs ORDER BY action ASC")->fetchAll(PDO::FETCH_COLUMN);
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-shield-shaded text-cyan me-2"></i>Security & Administrative Audit Logs</h4>
        <p class="text-muted small mb-0">Immutable records of all administrator actions, approvals, pricing modifications, and logins</p>
    </div>
</div>

<!-- Filter Bar -->
<div class="dm-card p-3 mb-4">
    <form method="GET" class="row g-2 align-items-center">
        <div class="col-md-9">
            <select name="action_filter" class="form-select form-select-dark">
                <option value="">All Administrative Action Types</option>
                <?php foreach ($actions as $act): ?>
                    <option value="<?= htmlspecialchars($act) ?>" <?= $actionFilter === $act ? 'selected' : '' ?>>
                        <?= strtoupper(str_replace('_', ' ', $act)) ?>
                    </option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="col-md-3 d-flex gap-2">
            <button type="submit" class="btn btn-cyan w-100"><i class="bi bi-funnel-fill me-1"></i> Filter Logs</button>
            <?php if (!empty($actionFilter)): ?>
                <a href="audit_logs.php" class="btn btn-outline-secondary"><i class="bi bi-x-circle"></i></a>
            <?php endif; ?>
        </div>
    </form>
</div>

<!-- Logs Table -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Log ID</th>
                    <th>Administrator</th>
                    <th>Action</th>
                    <th>Target Scope</th>
                    <th>Action Details</th>
                    <th>Origin IP</th>
                    <th>Timestamp</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($logs)): ?>
                    <tr>
                        <td colspan="7" class="text-center py-5 text-muted">
                            <i class="bi bi-shield-check fs-1 d-block mb-2 text-success"></i>
                            No administrative audit records logged yet.
                        </td>
                    </tr>
                <?php else: foreach ($logs as $l): ?>
                    <tr>
                        <td><span class="fw-bold text-cyan">#LOG-<?= $l['id'] ?></span></td>
                        <td>
                            <div class="fw-semibold text-white"><?= htmlspecialchars($l['admin_name'] ?? 'Super Admin') ?></div>
                            <small class="text-muted"><?= htmlspecialchars($l['admin_email'] ?? 'admin@drivemate.com') ?></small>
                        </td>
                        <td>
                            <span class="badge bg-dark border text-uppercase" style="border-color: var(--dm-border) !important; font-size: 0.72rem;">
                                <?= htmlspecialchars(str_replace('_', ' ', $l['action'])) ?>
                            </span>
                        </td>
                        <td>
                            <code class="text-cyan small"><?= htmlspecialchars($l['target_type']) ?><?= $l['target_id'] ? ' #' . $l['target_id'] : '' ?></code>
                        </td>
                        <td style="max-width: 320px;">
                            <span class="text-light small"><?= htmlspecialchars($l['details'] ?? '-') ?></span>
                        </td>
                        <td>
                            <small class="text-muted"><code><?= htmlspecialchars($l['ip_address'] ?? '127.0.0.1') ?></code></small>
                        </td>
                        <td>
                            <div class="small text-white"><?= date('M d, Y', strtotime($l['created_at'])) ?></div>
                            <small class="text-muted"><?= date('H:i:s', strtotime($l['created_at'])) ?></small>
                        </td>
                    </tr>
                <?php endforeach; endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require_once __DIR__ . '/footer.php'; ?>
