<?php
// admin/kyc.php — Driver KYC & Verification Center
$pageTitle = 'Driver KYC & Document Verification';
$activePage = 'kyc';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Document Approval / Rejection
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action_doc'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $docId = (int)($_POST['doc_id'] ?? 0);
        $action = $_POST['action_doc']; // 'verify' or 'reject'
        $newStatus = ($action === 'verify') ? 'verified' : 'rejected';

        if ($docId > 0) {
            $stmt = $db->prepare("UPDATE documents SET status = ?, verified_at = " . ($newStatus === 'verified' ? 'NOW()' : 'NULL') . " WHERE id = ?");
            $stmt->execute([$newStatus, $docId]);

            // Check if document belongs to a driver, and if all required docs are verified, auto-verify driver profile
            $docStmt = $db->prepare("SELECT user_id, type FROM documents WHERE id = ?");
            $docStmt->execute([$docId]);
            $docInfo = $docStmt->fetch();
            if ($docInfo && $newStatus === 'verified') {
                $uid = (int)$docInfo['user_id'];
                $cntStmt = $db->prepare("SELECT COUNT(*) FROM documents WHERE user_id = ? AND status != 'verified'");
                $cntStmt->execute([$uid]);
                $pendingCount = (int)$cntStmt->fetchColumn();
                if ($pendingCount === 0) {
                    $db->prepare("UPDATE driver_profile SET status = 'verified' WHERE user_id = ?")->execute([$uid]);
                    log_admin_action('auto_verify_driver', 'driver_profile', $uid, "All KYC documents approved");
                }
            }

            log_admin_action('verify_document', 'documents', $docId, "Document status updated to $newStatus");
            $msg = "Document #$docId marked as " . strtoupper($newStatus);
        }
    }
}

// Search & Filter
$userIdFilter = (int)($_GET['user_id'] ?? 0);
$statusFilter = trim($_GET['status'] ?? '');
$typeFilter = trim($_GET['type'] ?? '');

$sql = "SELECT d.*, u.name AS user_name, u.phone AS user_phone, u.role AS user_role, u.email AS user_email 
        FROM documents d 
        JOIN users u ON d.user_id = u.id 
        WHERE 1=1";

$params = [];
if ($userIdFilter > 0) {
    $sql .= " AND d.user_id = ?";
    $params[] = $userIdFilter;
}
if (!empty($statusFilter)) {
    $sql .= " AND d.status = ?";
    $params[] = $statusFilter;
}
if (!empty($typeFilter)) {
    $sql .= " AND d.type = ?";
    $params[] = $typeFilter;
}

$sql .= " ORDER BY (d.status = 'pending') DESC, d.created_at DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$documents = $stmt->fetchAll();
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-file-earmark-check-fill text-cyan me-2"></i>Driver KYC & Document Verification</h4>
        <p class="text-muted small mb-0">Total Documents: <strong><?= count($documents) ?></strong> &bull; Verification Workflow & Audit Enforcement</p>
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

<!-- Search and Filter Bar -->
<div class="dm-card p-3 mb-4">
    <form method="GET" class="row g-2 align-items-center">
        <div class="col-md-4">
            <select name="status" class="form-select form-select-dark">
                <option value="">All Document Statuses</option>
                <option value="pending" <?= $statusFilter === 'pending' ? 'selected' : '' ?>>Pending Review Only</option>
                <option value="verified" <?= $statusFilter === 'verified' ? 'selected' : '' ?>>Approved / Verified</option>
                <option value="rejected" <?= $statusFilter === 'rejected' ? 'selected' : '' ?>>Rejected Documents</option>
            </select>
        </div>
        <div class="col-md-4">
            <select name="type" class="form-select form-select-dark">
                <option value="">All Document Types</option>
                <option value="dl" <?= $typeFilter === 'dl' ? 'selected' : '' ?>>Driving License (DL)</option>
                <option value="rc" <?= $typeFilter === 'rc' ? 'selected' : '' ?>>Registration Certificate (RC)</option>
                <option value="kyc" <?= $typeFilter === 'kyc' ? 'selected' : '' ?>>Government ID / Aadhaar</option>
                <option value="insurance" <?= $typeFilter === 'insurance' ? 'selected' : '' ?>>Vehicle Insurance</option>
                <option value="photo" <?= $typeFilter === 'photo' ? 'selected' : '' ?>>Profile Photo</option>
            </select>
        </div>
        <div class="col-md-4 d-flex gap-2">
            <button type="submit" class="btn btn-cyan w-100"><i class="bi bi-funnel-fill me-1"></i> Apply Filters</button>
            <?php if (!empty($statusFilter) || !empty($typeFilter) || $userIdFilter > 0): ?>
                <a href="kyc.php" class="btn btn-outline-secondary"><i class="bi bi-x-circle"></i></a>
            <?php endif; ?>
        </div>
    </form>
</div>

<!-- Documents List -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Doc ID</th>
                    <th>Applicant</th>
                    <th>Type</th>
                    <th>File / Preview</th>
                    <th>Submitted</th>
                    <th>Status</th>
                    <th class="text-end">Verification Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($documents)): ?>
                    <tr>
                        <td colspan="7" class="text-center py-5 text-muted">
                            <i class="bi bi-file-earmark-x fs-1 d-block mb-2"></i>
                            No documents found matching the filter criteria.
                        </td>
                    </tr>
                <?php else: foreach ($documents as $doc): ?>
                    <tr>
                        <td><span class="fw-bold text-cyan">#DOC-<?= $doc['id'] ?></span></td>
                        <td>
                            <div class="fw-bold text-white"><?= htmlspecialchars($doc['user_name']) ?></div>
                            <small class="text-muted"><?= htmlspecialchars($doc['user_phone']) ?> &bull; <?= strtoupper($doc['user_role']) ?></small>
                        </td>
                        <td>
                            <span class="badge bg-dark border" style="border-color: var(--dm-border) !important; font-size: 0.8rem;">
                                <?= strtoupper($doc['type']) ?>
                            </span>
                        </td>
                        <td>
                            <?php if (!empty($doc['file_url'])): ?>
                                <a href="<?= htmlspecialchars($doc['file_url']) ?>" target="_blank" class="btn btn-sm btn-outline-info py-1 px-2" style="font-size: 0.78rem;">
                                    <i class="bi bi-box-arrow-up-right me-1"></i> Open Document
                                </a>
                            <?php else: ?>
                                <span class="text-muted small">No File Attached</span>
                            <?php endif; ?>
                        </td>
                        <td><small class="text-muted"><?= date('M d, Y H:i', strtotime($doc['created_at'])) ?></small></td>
                        <td>
                            <?php if ($doc['status'] === 'verified'): ?>
                                <span class="badge badge-success-subtle"><i class="bi bi-check-circle-fill me-1"></i>VERIFIED</span>
                            <?php elseif ($doc['status'] === 'pending'): ?>
                                <span class="badge badge-warning-subtle"><i class="bi bi-clock me-1"></i>PENDING</span>
                            <?php else: ?>
                                <span class="badge badge-danger-subtle"><i class="bi bi-x-circle me-1"></i>REJECTED</span>
                            <?php endif; ?>
                        </td>
                        <td class="text-end">
                            <form method="POST" class="d-inline-flex gap-2">
                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
                                <input type="hidden" name="doc_id" value="<?= $doc['id'] ?>">
                                
                                <?php if ($doc['status'] !== 'verified'): ?>
                                    <button type="submit" name="action_doc" value="verify" class="btn btn-sm btn-success py-1 px-2" style="font-size: 0.8rem;" title="Approve Document">
                                        <i class="bi bi-check-lg"></i> Approve
                                    </button>
                                <?php endif; ?>

                                <?php if ($doc['status'] !== 'rejected'): ?>
                                    <button type="submit" name="action_doc" value="reject" class="btn btn-sm btn-outline-danger py-1 px-2" style="font-size: 0.8rem;" title="Reject Document">
                                        <i class="bi bi-x-lg"></i> Reject
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
