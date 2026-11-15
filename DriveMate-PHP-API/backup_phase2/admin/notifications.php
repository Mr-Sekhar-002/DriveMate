<?php
// admin/notifications.php — DriveMate System & Broadcast Notification Center
$pageTitle = 'Broadcast & Push Notifications';
$activePage = 'notifications';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Dispatch Notification Broadcast
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['send_broadcast'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $title    = trim($_POST['title'] ?? '');
        $content  = trim($_POST['message'] ?? '');
        $audience = $_POST['audience'] ?? 'all';

        if (empty($title) || empty($content)) {
            $error = 'Both notification title and message are required.';
        } else {
            // Find target users
            $userQuery = "SELECT id FROM users WHERE status = 'active'";
            $params = [];
            if ($audience !== 'all') {
                $userQuery .= " AND role = ?";
                $params[] = $audience;
            }
            $targetUsers = $db->prepare($userQuery);
            $targetUsers->execute($params);
            $userIds = $targetUsers->fetchAll(PDO::FETCH_COLUMN);

            $sentCount = 0;
            if (!empty($userIds)) {
                $insStmt = $db->prepare("INSERT INTO notifications (user_id, type, title, message, is_read, created_at) VALUES (?, 'system', ?, ?, 0, NOW())");
                foreach ($userIds as $uid) {
                    $insStmt->execute([$uid, $title, $content]);
                    $sentCount++;
                }
            }

            log_admin_action('send_broadcast_notification', 'notifications', null, "Dispatched to $sentCount users ($audience): $title");
            $msg = "Broadcast successfully delivered to $sentCount users (" . strtoupper($audience) . ")!";
        }
    }
}

// Fetch Recent Notifications History
$recentNotifs = [];
try {
    $stmt = $db->query("SELECT n.*, u.name AS recipient_name, u.role AS recipient_role 
                        FROM notifications n 
                        LEFT JOIN users u ON n.user_id = u.id 
                        ORDER BY n.created_at DESC LIMIT 20");
    $recentNotifs = $stmt->fetchAll();
} catch (Exception $e) {}
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-bell-fill text-cyan me-2"></i>Push & In-App Notification Center</h4>
        <p class="text-muted small mb-0">Broadcast Platform Announcements &bull; Real-time Delivery to Flutter Mobile App</p>
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

<div class="row g-4">
    <!-- Send Broadcast Form -->
    <div class="col-lg-5">
        <div class="dm-card p-4">
            <h5 class="fw-bold text-white mb-3"><i class="bi bi-send-fill text-cyan me-2"></i>Send New Broadcast</h5>
            <form method="POST">
                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Target Audience</label>
                    <select name="audience" class="form-select form-select-dark" required>
                        <option value="all">All Registered Users (Customers, Drivers, Owners)</option>
                        <option value="customer">Customers Only</option>
                        <option value="driver">Fleet Drivers Only</option>
                        <option value="owner">Car Owners Only</option>
                    </select>
                </div>

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Notification Title</label>
                    <input type="text" name="title" class="form-control form-control-dark" placeholder="e.g., Festive Offer, Weather Advisory, Platform Update" required>
                </div>

                <div class="mb-4">
                    <label class="form-label text-light small fw-bold">Message Content</label>
                    <textarea name="message" class="form-control form-control-dark" rows="4" placeholder="Type notification content that appears on mobile screens..." required></textarea>
                </div>

                <button type="submit" name="send_broadcast" class="btn btn-cyan w-100 py-2">
                    <i class="bi bi-megaphone-fill me-2"></i> Dispatch Notification Now
                </button>
            </form>
        </div>
    </div>

    <!-- Notification Feed -->
    <div class="col-lg-7">
        <div class="dm-card h-100">
            <div class="dm-card-header">
                <h5>Recent Dispatched Notifications</h5>
                <span class="badge badge-cyan"><?= count($recentNotifs) ?> Delivered</span>
            </div>
            <div class="table-responsive">
                <table class="table dm-table">
                    <thead>
                        <tr>
                            <th>Recipient</th>
                            <th>Title & Message</th>
                            <th>Status</th>
                            <th>Time</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (empty($recentNotifs)): ?>
                            <tr>
                                <td colspan="4" class="text-center py-5 text-muted">
                                    <i class="bi bi-bell-slash fs-1 d-block mb-2"></i>
                                    No broadcast notifications logged yet.
                                </td>
                            </tr>
                        <?php else: foreach ($recentNotifs as $n): ?>
                            <tr>
                                <td>
                                    <div class="fw-semibold text-white"><?= htmlspecialchars($n['recipient_name'] ?? 'User #' . $n['user_id']) ?></div>
                                    <span class="badge bg-dark border text-uppercase" style="border-color: var(--dm-border) !important; font-size: 0.68rem;">
                                        <?= htmlspecialchars($n['recipient_role'] ?? 'user') ?>
                                    </span>
                                </td>
                                <td style="max-width: 280px;">
                                    <div class="fw-bold text-white small"><?= htmlspecialchars($n['title']) ?></div>
                                    <small class="text-muted d-block text-truncate"><?= htmlspecialchars($n['message']) ?></small>
                                </td>
                                <td>
                                    <?php if (!empty($n['is_read'])): ?>
                                        <span class="badge badge-success-subtle">READ</span>
                                    <?php else: ?>
                                        <span class="badge badge-warning-subtle">DELIVERED</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <small class="text-muted"><?= date('M d, H:i', strtotime($n['created_at'])) ?></small>
                                </td>
                            </tr>
                        <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/footer.php'; ?>
