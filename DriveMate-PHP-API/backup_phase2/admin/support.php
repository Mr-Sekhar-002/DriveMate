<?php
// admin/support.php — DriveMate Help & Support Ticket Desk
$pageTitle = 'Help & Support Desk';
$activePage = 'support';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Admin Reply to Support Ticket
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['reply_ticket'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $ticketId = (int)($_POST['ticket_id'] ?? 0);
        $replyText = trim($_POST['reply_text'] ?? '');
        $status = $_POST['ticket_status'] ?? 'resolved';

        if ($ticketId > 0 && !empty($replyText)) {
            $stmt = $db->prepare("UPDATE support_tickets SET admin_reply = ?, status = ?, resolved_at = " . ($status === 'resolved' ? 'NOW()' : 'NULL') . " WHERE id = ?");
            $stmt->execute([$replyText, $status, $ticketId]);

            // Notify the user via in-app notifications
            $tInfo = $db->query("SELECT user_id, subject FROM support_tickets WHERE id = $ticketId")->fetch();
            if ($tInfo) {
                $uid = (int)$tInfo['user_id'];
                $subj = $tInfo['subject'];
                $notifTitle = "Support Update: Ticket #$ticketId";
                $notifMsg = "Support team replied to: \"$subj\". Check Help & Support in your app.";
                try {
                    $db->prepare("INSERT INTO notifications (user_id, type, title, message, is_read, created_at) VALUES (?, 'system', ?, ?, 0, NOW())")
                       ->execute([$uid, $notifTitle, $notifMsg]);
                } catch (Exception $e) {}
            }

            log_admin_action('reply_support_ticket', 'support_tickets', $ticketId, "Replied with status: $status");
            $msg = "Ticket #$ticketId updated and user notified.";
        }
    }
}

// Search & Filter
$categoryFilter = trim($_GET['category'] ?? '');
$statusFilter   = trim($_GET['status'] ?? '');
$search         = trim($_GET['search'] ?? '');

$sql = "SELECT st.*, 
               u.name AS user_name, u.phone AS user_phone, u.role AS user_role, u.email AS user_email,
               b.pickup_location, b.destination
        FROM support_tickets st 
        JOIN users u ON st.user_id = u.id 
        LEFT JOIN bookings b ON st.booking_id = b.id 
        WHERE 1=1";

$params = [];
if (!empty($categoryFilter)) {
    $sql .= " AND st.category = ?";
    $params[] = $categoryFilter;
}
if (!empty($statusFilter)) {
    $sql .= " AND st.status = ?";
    $params[] = $statusFilter;
}
if (!empty($search)) {
    $sql .= " AND (st.id = ? OR st.subject LIKE ? OR st.message LIKE ? OR u.name LIKE ? OR u.phone LIKE ?)";
    $num = (int)$search;
    $term = "%$search%";
    $params[] = $num;
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
    $params[] = $term;
}

$sql .= " ORDER BY (st.status = 'open') DESC, st.created_at DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$tickets = $stmt->fetchAll();
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-headset text-cyan me-2"></i>Help & Support Ticket Management</h4>
        <p class="text-muted small mb-0">Total Inquiries & Complaints: <strong><?= count($tickets) ?></strong> &bull; Direct App Synchronization</p>
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
            <input type="text" name="search" class="form-control form-control-dark" placeholder="Search ticket subject, user name, or message..." value="<?= htmlspecialchars($search) ?>">
        </div>
        <div class="col-md-3">
            <select name="category" class="form-select form-select-dark">
                <option value="">All Categories</option>
                <option value="booking" <?= $categoryFilter === 'booking' ? 'selected' : '' ?>>Booking Related</option>
                <option value="payment" <?= $categoryFilter === 'payment' ? 'selected' : '' ?>>Payment & Invoices</option>
                <option value="trip" <?= $categoryFilter === 'trip' ? 'selected' : '' ?>>Active Trip Issues</option>
                <option value="driver" <?= $categoryFilter === 'driver' ? 'selected' : '' ?>>Driver Behavior</option>
                <option value="vehicle" <?= $categoryFilter === 'vehicle' ? 'selected' : '' ?>>Vehicle Quality</option>
                <option value="app" <?= $categoryFilter === 'app' ? 'selected' : '' ?>>App Bugs / Tech</option>
                <option value="other" <?= $categoryFilter === 'other' ? 'selected' : '' ?>>General Inquiries</option>
            </select>
        </div>
        <div class="col-md-2">
            <select name="status" class="form-select form-select-dark">
                <option value="">All Statuses</option>
                <option value="open" <?= $statusFilter === 'open' ? 'selected' : '' ?>>Open Tickets</option>
                <option value="in_progress" <?= $statusFilter === 'in_progress' ? 'selected' : '' ?>>In Progress</option>
                <option value="resolved" <?= $statusFilter === 'resolved' ? 'selected' : '' ?>>Resolved</option>
            </select>
        </div>
        <div class="col-md-2 d-flex gap-2">
            <button type="submit" class="btn btn-cyan w-100"><i class="bi bi-funnel-fill me-1"></i> Filter</button>
            <?php if (!empty($search) || !empty($categoryFilter) || !empty($statusFilter)): ?>
                <a href="support.php" class="btn btn-outline-secondary"><i class="bi bi-x-circle"></i></a>
            <?php endif; ?>
        </div>
    </form>
</div>

<!-- Support Tickets Table -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Ticket ID</th>
                    <th>User & Role</th>
                    <th>Category</th>
                    <th>Subject & Message</th>
                    <th>Date</th>
                    <th>Status</th>
                    <th class="text-end">Resolution</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($tickets)): ?>
                    <tr>
                        <td colspan="7" class="text-center py-5 text-muted">
                            <i class="bi bi-inbox fs-1 d-block mb-2"></i>
                            No support tickets filed in the system matching criteria.
                        </td>
                    </tr>
                <?php else: foreach ($tickets as $t): ?>
                    <tr>
                        <td><span class="fw-bold text-cyan">#TCK-<?= $t['id'] ?></span></td>
                        <td>
                            <div class="fw-semibold text-white"><?= htmlspecialchars($t['user_name']) ?></div>
                            <small class="text-muted"><i class="bi bi-telephone me-1"></i><?= htmlspecialchars($t['user_phone'] ?? '-') ?> &bull; <?= strtoupper($t['user_role']) ?></small>
                        </td>
                        <td>
                            <span class="badge bg-dark border text-uppercase" style="border-color: var(--dm-border) !important; font-size: 0.75rem;">
                                <?= htmlspecialchars($t['category']) ?>
                            </span>
                        </td>
                        <td style="max-width: 320px;">
                            <div class="fw-bold text-white"><?= htmlspecialchars($t['subject']) ?></div>
                            <p class="small text-muted mb-1"><?= nl2br(htmlspecialchars($t['message'])) ?></p>
                            <?php if (!empty($t['booking_id'])): ?>
                                <small class="text-cyan"><i class="bi bi-link-45deg"></i> Booking Ref: #BK-<?= $t['booking_id'] ?></small>
                            <?php endif; ?>
                            <?php if (!empty($t['admin_reply'])): ?>
                                <div class="mt-2 p-2 rounded-2 small" style="background: rgba(16, 185, 129, 0.1); border-left: 3px solid #10B981; color: #A7F3D0;">
                                    <strong>Admin Reply:</strong> <?= nl2br(htmlspecialchars($t['admin_reply'])) ?>
                                </div>
                            <?php endif; ?>
                        </td>
                        <td>
                            <small class="text-muted"><?= date('M d, Y H:i', strtotime($t['created_at'])) ?></small>
                        </td>
                        <td>
                            <?php if ($t['status'] === 'resolved'): ?>
                                <span class="badge badge-success-subtle"><i class="bi bi-check-circle-fill me-1"></i>RESOLVED</span>
                            <?php elseif ($t['status'] === 'in_progress'): ?>
                                <span class="badge badge-warning-subtle"><i class="bi bi-arrow-repeat me-1"></i>IN PROGRESS</span>
                            <?php else: ?>
                                <span class="badge badge-danger-subtle"><i class="bi bi-exclamation-circle-fill me-1"></i>OPEN</span>
                            <?php endif; ?>
                        </td>
                        <td class="text-end">
                            <button class="btn btn-sm btn-cyan py-1 px-3" data-bs-toggle="modal" data-bs-target="#replyModal<?= $t['id'] ?>">
                                <i class="bi bi-reply-fill"></i> Reply
                            </button>

                            <!-- Reply Modal -->
                            <div class="modal fade" id="replyModal<?= $t['id'] ?>" tabindex="-1">
                                <div class="modal-dialog modal-dialog-centered">
                                    <div class="modal-content" style="background: var(--dm-card); border: 1px solid var(--dm-border);">
                                        <form method="POST">
                                            <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
                                            <input type="hidden" name="ticket_id" value="<?= $t['id'] ?>">
                                            <div class="modal-header border-0 pb-0">
                                                <h5 class="modal-title text-white">Reply to Ticket #TCK-<?= $t['id'] ?></h5>
                                                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                                            </div>
                                            <div class="modal-body text-start">
                                                <div class="mb-3">
                                                    <label class="form-label small text-muted">Customer Subject:</label>
                                                    <div class="fw-bold text-white"><?= htmlspecialchars($t['subject']) ?></div>
                                                    <p class="small text-muted mt-1"><?= htmlspecialchars($t['message']) ?></p>
                                                </div>
                                                <div class="mb-3">
                                                    <label class="form-label small text-light fw-bold">Official Admin Response:</label>
                                                    <textarea name="reply_text" class="form-control form-control-dark" rows="4" placeholder="Write resolution or instructions..." required><?= htmlspecialchars($t['admin_reply'] ?? '') ?></textarea>
                                                </div>
                                                <div class="mb-3">
                                                    <label class="form-label small text-light fw-bold">Update Ticket Status:</label>
                                                    <select name="ticket_status" class="form-select form-select-dark">
                                                        <option value="resolved" <?= $t['status'] === 'resolved' ? 'selected' : '' ?>>Resolved & Closed</option>
                                                        <option value="in_progress" <?= $t['status'] === 'in_progress' ? 'selected' : '' ?>>In Progress / Investigating</option>
                                                        <option value="open" <?= $t['status'] === 'open' ? 'selected' : '' ?>>Keep Open</option>
                                                    </select>
                                                </div>
                                            </div>
                                            <div class="modal-footer border-0 pt-0">
                                                <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancel</button>
                                                <button type="submit" name="reply_ticket" class="btn btn-cyan btn-sm">Send Official Response</button>
                                            </div>
                                        </form>
                                    </div>
                                </div>
                            </div>
                        </td>
                    </tr>
                <?php endforeach; endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require_once __DIR__ . '/footer.php'; ?>
