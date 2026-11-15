<?php
// admin/reviews.php — Customer Reviews & Rating Moderation
$pageTitle = 'Ratings & Reviews Moderation';
$activePage = 'reviews';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Inappropriate Review Deletion
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_review'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $revId = (int)($_POST['review_id'] ?? 0);
        if ($revId > 0) {
            $rInfo = $db->query("SELECT driver_id FROM reviews WHERE id = $revId")->fetch();
            $db->prepare("DELETE FROM reviews WHERE id = ?")->execute([$revId]);

            // Recalculate Driver avg_rating
            if (!empty($rInfo['driver_id'])) {
                $drvId = (int)$rInfo['driver_id'];
                $avgRow = $db->query("SELECT AVG(rating) AS avg_r, COUNT(*) AS cnt FROM reviews WHERE driver_id = $drvId")->fetch();
                $newAvg = round((float)($avgRow['avg_r'] ?? 0), 2);
                $newCnt = (int)($avgRow['cnt'] ?? 0);
                $db->prepare("UPDATE driver_profile SET avg_rating = ?, total_trips = ? WHERE user_id = ?")->execute([$newAvg, $newCnt, $drvId]);
            }

            log_admin_action('delete_review', 'reviews', $revId, "Admin removed review #$revId");
            $msg = "Review #$revId successfully deleted and driver rating recalculated.";
        }
    }
}

// Filter by Star Rating
$starFilter = (int)($_GET['stars'] ?? 0);

$sql = "SELECT r.*, 
               u_c.name AS customer_name, u_c.phone AS customer_phone,
               u_d.name AS driver_name, u_d.phone AS driver_phone
        FROM reviews r 
        LEFT JOIN users u_c ON r.user_id = u_c.id 
        LEFT JOIN users u_d ON r.driver_id = u_d.id 
        WHERE 1=1";

$params = [];
if ($starFilter > 0) {
    $sql .= " AND r.rating = ?";
    $params[] = $starFilter;
}

$sql .= " ORDER BY r.created_at DESC";
$stmt = $db->prepare($sql);
$stmt->execute($params);
$reviews = $stmt->fetchAll();

// Rating breakdown summary
$ratingStats = $db->query("SELECT rating, COUNT(*) as cnt FROM reviews GROUP BY rating")->fetchAll(PDO::FETCH_KEY_PAIR);
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-star-fill text-warning me-2"></i>Customer Reviews & Ratings Moderation</h4>
        <p class="text-muted small mb-0">Total Reviews: <strong><?= count($reviews) ?></strong> &bull; Authenticated RBAC Feedback Only</p>
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

<!-- Filter Chips -->
<div class="d-flex flex-wrap gap-2 mb-4">
    <a href="reviews.php" class="btn btn-sm <?= $starFilter === 0 ? 'btn-cyan' : 'btn-outline-secondary' ?>">All Ratings (<?= count($reviews) ?>)</a>
    <?php for ($s = 5; $s >= 1; $s--): ?>
        <a href="reviews.php?stars=<?= $s ?>" class="btn btn-sm <?= $starFilter === $s ? 'btn-cyan' : 'btn-outline-secondary' ?>">
            <?= $s ?> <i class="bi bi-star-fill text-warning small"></i> (<?= $ratingStats[$s] ?? 0 ?>)
        </a>
    <?php endfor; ?>
</div>

<!-- Reviews Table -->
<div class="dm-card">
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Review ID</th>
                    <th>Customer</th>
                    <th>Rated Driver</th>
                    <th>Rating Stars</th>
                    <th>Customer Comment</th>
                    <th>Booking Ref</th>
                    <th>Date</th>
                    <th class="text-end">Actions</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($reviews)): ?>
                    <tr>
                        <td colspan="8" class="text-center py-5 text-muted">
                            <i class="bi bi-chat-square-dots fs-1 d-block mb-2"></i>
                            No reviews found matching your filter selection.
                        </td>
                    </tr>
                <?php else: foreach ($reviews as $rev): ?>
                    <tr>
                        <td><span class="fw-bold text-cyan">#REV-<?= $rev['id'] ?></span></td>
                        <td>
                            <div class="fw-semibold text-white"><?= htmlspecialchars($rev['customer_name'] ?? 'Customer #' . $rev['user_id']) ?></div>
                            <small class="text-muted"><?= htmlspecialchars($rev['customer_phone'] ?? '-') ?></small>
                        </td>
                        <td>
                            <div class="fw-semibold text-white"><?= htmlspecialchars($rev['driver_name'] ?? 'Driver #' . $rev['driver_id']) ?></div>
                            <small class="text-muted"><?= htmlspecialchars($rev['driver_phone'] ?? '-') ?></small>
                        </td>
                        <td>
                            <div class="d-flex align-items-center gap-1">
                                <?php for ($i = 1; $i <= 5; $i++): ?>
                                    <i class="bi bi-star-fill <?= $i <= $rev['rating'] ? 'text-warning' : 'text-secondary' ?> small"></i>
                                <?php endfor; ?>
                                <span class="ms-1 fw-bold text-white"><?= $rev['rating'] ?>.0</span>
                            </div>
                        </td>
                        <td style="max-width: 320px;">
                            <div class="text-light small"><?= nl2br(htmlspecialchars($rev['comment'] ?: 'No written remarks provided.')) ?></div>
                        </td>
                        <td>
                            <?php if (!empty($rev['booking_id'])): ?>
                                <a href="bookings.php?search=<?= $rev['booking_id'] ?>" class="text-cyan small fw-bold">#BK-<?= $rev['booking_id'] ?></a>
                            <?php else: ?>
                                <span class="text-muted small">-</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <small class="text-muted"><?= date('M d, Y', strtotime($rev['created_at'])) ?></small>
                        </td>
                        <td class="text-end">
                            <form method="POST" class="d-inline" onsubmit="return confirm('Permanently delete review #<?= $rev['id'] ?>? This cannot be undone.');">
                                <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">
                                <input type="hidden" name="review_id" value="<?= $rev['id'] ?>">
                                <button type="submit" name="delete_review" class="btn btn-outline-danger btn-sm py-1 px-2" style="font-size: 0.8rem;" title="Remove Offensive Review">
                                    <i class="bi bi-trash3"></i> Delete
                                </button>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require_once __DIR__ . '/footer.php'; ?>
