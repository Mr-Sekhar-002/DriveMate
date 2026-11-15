<?php
// admin/index.php — DriveMate Executive Admin Dashboard & Real-Time Analytics
$pageTitle = 'Dashboard & Real-Time Analytics';
$activePage = 'dashboard';
require_once __DIR__ . '/header.php';

// Fetch Actual Database Statistics (Strict Real MySQL Data Only)
$stats = [
    'total_customers'   => 0,
    'total_drivers'     => 0,
    'online_drivers'    => 0,
    'total_vehicles'    => 0,
    'total_bookings'    => 0,
    'active_trips'      => 0,
    'completed_trips'   => 0,
    'cancelled_bookings'=> 0,
    'verified_payments' => 0,
    'total_revenue'     => 0.00,
];

try {
    $stats['total_customers']    = (int)$db->query("SELECT COUNT(*) FROM users WHERE role = 'customer'")->fetchColumn();
    $stats['total_drivers']      = (int)$db->query("SELECT COUNT(*) FROM users WHERE role = 'driver'")->fetchColumn();
    $stats['online_drivers']     = (int)$db->query("SELECT COUNT(*) FROM driver_profile WHERE is_online = 1")->fetchColumn();
    $stats['total_vehicles']     = (int)$db->query("SELECT (SELECT COUNT(*) FROM vehicles) + (SELECT COUNT(*) FROM car_listings)")->fetchColumn();
    $stats['total_bookings']     = (int)$db->query("SELECT COUNT(*) FROM bookings")->fetchColumn();
    $stats['active_trips']       = (int)$db->query("SELECT COUNT(*) FROM trips WHERE status = 'ongoing'")->fetchColumn();
    $stats['completed_trips']    = (int)$db->query("SELECT COUNT(*) FROM bookings WHERE status = 'completed'")->fetchColumn();
    $stats['cancelled_bookings'] = (int)$db->query("SELECT COUNT(*) FROM bookings WHERE status = 'cancelled'")->fetchColumn();
    $stats['verified_payments']  = (int)$db->query("SELECT COUNT(*) FROM payments WHERE status = 'paid'")->fetchColumn();
    $stats['total_revenue']      = (float)$db->query("SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'paid'")->fetchColumn();
} catch (Exception $e) {
    error_log("Dashboard stats query error: " . $e->getMessage());
}

// Recent Bookings (Last 6)
$recentBookings = [];
try {
    $stmt = $db->query("SELECT b.*, u.name AS customer_name, u.phone AS customer_phone 
                        FROM bookings b 
                        LEFT JOIN users u ON b.user_id = u.id 
                        ORDER BY b.created_at DESC LIMIT 6");
    $recentBookings = $stmt->fetchAll();
} catch (Exception $e) {}

// Pending KYC Documents (Last 5)
$pendingDocs = [];
try {
    $stmt = $db->query("SELECT d.*, u.name AS user_name, u.role AS user_role, u.phone AS user_phone 
                        FROM documents d 
                        JOIN users u ON d.user_id = u.id 
                        WHERE d.status = 'pending' 
                        ORDER BY d.created_at ASC LIMIT 5");
    $pendingDocs = $stmt->fetchAll();
} catch (Exception $e) {}

// Active Ongoing Trips
$activeOngoingTrips = [];
try {
    $stmt = $db->query("SELECT t.*, b.pickup_location, b.destination, 
                               u_c.name AS customer_name, u_d.name AS driver_name 
                        FROM trips t 
                        JOIN bookings b ON t.booking_id = b.id 
                        LEFT JOIN users u_c ON b.user_id = u_c.id 
                        LEFT JOIN users u_d ON t.driver_id = u_d.id 
                        WHERE t.status = 'ongoing' 
                        ORDER BY t.updated_at DESC LIMIT 4");
    $activeOngoingTrips = $stmt->fetchAll();
} catch (Exception $e) {}
?>

<!-- Welcome Banner -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-4 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white">System Operations & Intelligence</h4>
        <p class="text-muted small mb-0">Live feed connected to MySQL database &bull; Real-time fleet metrics</p>
    </div>
    <div class="d-flex align-items-center gap-2 mt-3 mt-md-0">
        <a href="trips.php" class="btn btn-cyan btn-sm d-flex align-items-center gap-2">
            <i class="bi bi-geo-alt-fill"></i> View Live Trips Map
        </a>
        <a href="kyc.php" class="btn btn-outline-light btn-sm d-flex align-items-center gap-2" style="border-color: var(--dm-border);">
            <i class="bi bi-file-earmark-check"></i> Pending KYC
            <?php if (count($pendingDocs) > 0): ?>
                <span class="badge bg-danger rounded-pill"><?= count($pendingDocs) ?></span>
            <?php endif; ?>
        </a>
    </div>
</div>

<!-- Real Database KPI Metric Cards (10 Core Metrics Required) -->
<div class="row g-3 mb-4">
    <!-- Total Revenue -->
    <div class="col-sm-6 col-xl-3">
        <div class="dm-stat-widget">
            <div class="d-flex align-items-center justify-content-between mb-2">
                <span class="text-muted small fw-bold text-uppercase">Total Revenue</span>
                <div class="rounded-3 p-2" style="background: rgba(0, 242, 254, 0.1); color: var(--dm-cyan);">
                    <i class="bi bi-currency-rupee fs-5"></i>
                </div>
            </div>
            <h3 class="fw-bold mb-1" style="color: #fff;">₹<?= number_format($stats['total_revenue'], 2) ?></h3>
            <small class="text-success small d-flex align-items-center gap-1">
                <i class="bi bi-check-circle-fill"></i> <?= $stats['verified_payments'] ?> Verified Invoices
            </small>
        </div>
    </div>

    <!-- Total Bookings -->
    <div class="col-sm-6 col-xl-3">
        <div class="dm-stat-widget">
            <div class="d-flex align-items-center justify-content-between mb-2">
                <span class="text-muted small fw-bold text-uppercase">Total Bookings</span>
                <div class="rounded-3 p-2" style="background: rgba(59, 130, 246, 0.1); color: #60A5FA;">
                    <i class="bi bi-calendar-event fs-5"></i>
                </div>
            </div>
            <h3 class="fw-bold mb-1 text-white"><?= $stats['total_bookings'] ?></h3>
            <small class="text-muted small">
                <span class="text-success"><?= $stats['completed_trips'] ?> Completed</span> &bull; 
                <span class="text-danger"><?= $stats['cancelled_bookings'] ?> Cancelled</span>
            </small>
        </div>
    </div>

    <!-- Active Trips -->
    <div class="col-sm-6 col-xl-3">
        <div class="dm-stat-widget" style="border-left-color: #10B981;">
            <div class="d-flex align-items-center justify-content-between mb-2">
                <span class="text-muted small fw-bold text-uppercase">Active Trips</span>
                <div class="rounded-3 p-2" style="background: rgba(16, 185, 129, 0.1); color: #34D399;">
                    <i class="bi bi-radar fs-5"></i>
                </div>
            </div>
            <h3 class="fw-bold mb-1 text-white"><?= $stats['active_trips'] ?></h3>
            <small class="text-success small d-flex align-items-center gap-1">
                <span class="spinner-grow spinner-grow-sm text-success" style="width: 8px; height: 8px;"></span> Live GPS navigation ongoing
            </small>
        </div>
    </div>

    <!-- Drivers Fleet -->
    <div class="col-sm-6 col-xl-3">
        <div class="dm-stat-widget" style="border-left-color: #8B5CF6;">
            <div class="d-flex align-items-center justify-content-between mb-2">
                <span class="text-muted small fw-bold text-uppercase">Driver Fleet</span>
                <div class="rounded-3 p-2" style="background: rgba(139, 92, 246, 0.1); color: #A78BFA;">
                    <i class="bi bi-person-badge fs-5"></i>
                </div>
            </div>
            <h3 class="fw-bold mb-1 text-white"><?= $stats['total_drivers'] ?></h3>
            <small class="text-cyan small fw-semibold">
                <i class="bi bi-broadcast"></i> <?= $stats['online_drivers'] ?> Currently Online
            </small>
        </div>
    </div>
</div>

<!-- Secondary Stats Row (Customers, Vehicles, Verified Payments) -->
<div class="row g-3 mb-4">
    <div class="col-6 col-md-3">
        <div class="dm-card p-3 text-center">
            <small class="text-muted text-uppercase fw-bold" style="font-size: 0.72rem;">Registered Customers</small>
            <h4 class="fw-bold mb-0 mt-1 text-white"><?= $stats['total_customers'] ?></h4>
        </div>
    </div>
    <div class="col-6 col-md-3">
        <div class="dm-card p-3 text-center">
            <small class="text-muted text-uppercase fw-bold" style="font-size: 0.72rem;">Total Fleet Vehicles</small>
            <h4 class="fw-bold mb-0 mt-1 text-white"><?= $stats['total_vehicles'] ?></h4>
        </div>
    </div>
    <div class="col-6 col-md-3">
        <div class="dm-card p-3 text-center">
            <small class="text-muted text-uppercase fw-bold" style="font-size: 0.72rem;">Completed Rides</small>
            <h4 class="fw-bold mb-0 mt-1 text-success"><?= $stats['completed_trips'] ?></h4>
        </div>
    </div>
    <div class="col-6 col-md-3">
        <div class="dm-card p-3 text-center">
            <small class="text-muted text-uppercase fw-bold" style="font-size: 0.72rem;">Paid Invoices</small>
            <h4 class="fw-bold mb-0 mt-1 text-cyan"><?= $stats['verified_payments'] ?></h4>
        </div>
    </div>
</div>

<!-- Active Trips Live Feed (If any) -->
<?php if (!empty($activeOngoingTrips)): ?>
<div class="dm-card mb-4">
    <div class="dm-card-header">
        <div class="d-flex align-items-center gap-2">
            <span class="spinner-grow spinner-grow-sm text-danger"></span>
            <h5>Active Live Trips Under Monitoring</h5>
        </div>
        <a href="trips.php" class="btn btn-outline-light btn-sm" style="border-color: var(--dm-border);">Interactive Map &rarr;</a>
    </div>
    <div class="table-responsive">
        <table class="table dm-table">
            <thead>
                <tr>
                    <th>Trip ID</th>
                    <th>Customer</th>
                    <th>Assigned Driver</th>
                    <th>Route (From &rarr; To)</th>
                    <th>GPS Coords</th>
                    <th>Status</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($activeOngoingTrips as $tr): ?>
                    <tr>
                        <td><span class="fw-bold text-cyan">#TRP-<?= $tr['id'] ?></span></td>
                        <td><?= htmlspecialchars($tr['customer_name'] ?? 'Guest Customer') ?></td>
                        <td><span class="badge bg-secondary"><?= htmlspecialchars($tr['driver_name'] ?? 'Driver Assigned') ?></span></td>
                        <td style="max-width: 280px;" class="text-truncate">
                            <span class="text-muted"><?= htmlspecialchars($tr['pickup_location'] ?? '-') ?></span> &rarr; 
                            <span class="text-light"><?= htmlspecialchars($tr['destination'] ?? '-') ?></span>
                        </td>
                        <td><code><?= $tr['current_lat'] ? round($tr['current_lat'], 4) . ', ' . round($tr['current_lng'], 4) : 'Pending Fix' ?></code></td>
                        <td><span class="badge badge-success-subtle">ONGOING</span></td>
                        <td>
                            <a href="trips.php?focus_trip=<?= $tr['id'] ?>" class="btn btn-cyan btn-sm py-1 px-2" style="font-size: 0.75rem;">
                                <i class="bi bi-geo-alt"></i> Track
                            </a>
                        </td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>
<?php endif; ?>

<!-- Two-Column Grid: Recent Bookings & Pending KYC -->
<div class="row g-4">
    <!-- Recent Bookings Table -->
    <div class="col-lg-8">
        <div class="dm-card h-100">
            <div class="dm-card-header">
                <h5>Recent Booking Activity</h5>
                <a href="bookings.php" class="btn btn-outline-light btn-sm" style="border-color: var(--dm-border);">View All Bookings &rarr;</a>
            </div>
            <div class="table-responsive">
                <table class="table dm-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Customer</th>
                            <th>Type</th>
                            <th>Amount</th>
                            <th>Payment</th>
                            <th>Trip Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (empty($recentBookings)): ?>
                            <tr><td colspan="6" class="text-center py-4 text-muted">No booking records found in database</td></tr>
                        <?php else: foreach ($recentBookings as $b): ?>
                            <tr>
                                <td><span class="fw-bold text-cyan">#<?= $b['id'] ?></span></td>
                                <td>
                                    <div class="fw-semibold text-white"><?= htmlspecialchars($b['customer_name'] ?? 'Customer #' . $b['user_id']) ?></div>
                                    <small class="text-muted"><?= htmlspecialchars($b['customer_phone'] ?? '-') ?></small>
                                </td>
                                <td>
                                    <span class="badge bg-dark border" style="border-color: var(--dm-border) !important; font-size: 0.75rem;">
                                        <?= strtoupper(str_replace('_', ' ', $b['type'])) ?>
                                    </span>
                                </td>
                                <td class="fw-bold text-white">₹<?= number_format($b['total_amount'], 2) ?></td>
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
                            </tr>
                        <?php endforeach; endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- Pending Document Approvals (KYC) -->
    <div class="col-lg-4">
        <div class="dm-card h-100">
            <div class="dm-card-header">
                <h5>Pending KYC Review</h5>
                <a href="kyc.php" class="btn btn-outline-light btn-sm" style="border-color: var(--dm-border);">Inspect &rarr;</a>
            </div>
            <div class="p-3">
                <?php if (empty($pendingDocs)): ?>
                    <div class="text-center py-4 text-muted">
                        <i class="bi bi-shield-check fs-2 d-block mb-2 text-success"></i>
                        <p class="small mb-0">All uploaded driver/user documents are up-to-date and verified!</p>
                    </div>
                <?php else: foreach ($pendingDocs as $doc): ?>
                    <div class="p-3 mb-2 rounded-3" style="background: rgba(11, 19, 43, 0.6); border: 1px solid var(--dm-border);">
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <div>
                                <h6 class="mb-0 fw-bold text-white"><?= htmlspecialchars($doc['user_name']) ?></h6>
                                <small class="text-muted"><?= htmlspecialchars($doc['user_phone']) ?></small>
                            </div>
                            <span class="badge badge-warning-subtle"><?= strtoupper($doc['type']) ?></span>
                        </div>
                        <div class="d-flex align-items-center justify-content-between mt-2 pt-2 border-top" style="border-color: rgba(255,255,255,0.05) !important;">
                            <small class="text-muted" style="font-size: 0.72rem;"><?= date('M d, H:i', strtotime($doc['created_at'])) ?></small>
                            <a href="kyc.php" class="btn btn-sm btn-cyan py-0 px-2" style="font-size: 0.75rem;">Review &rarr;</a>
                        </div>
                    </div>
                <?php endforeach; endif; ?>
            </div>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/footer.php'; ?>
