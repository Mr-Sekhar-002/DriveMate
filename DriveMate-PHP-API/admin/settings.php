<?php
// admin/settings.php — DriveMate System Settings & Pricing Engine
$pageTitle = 'System & Dynamic Pricing Settings';
$activePage = 'settings';
require_once __DIR__ . '/header.php';

$msg = '';
$error = '';

// Handle Settings Update
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['save_settings'])) {
    $token = $_POST['csrf_token'] ?? '';
    if (!verify_csrf_token($token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } else {
        $submittedSettings = $_POST['settings'] ?? [];
        $stmtSet = $db->prepare("INSERT INTO system_settings (setting_key, setting_value, description) 
                                 VALUES (?, ?, '') 
                                 ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = NOW()");
        
        $updatedCount = 0;
        foreach ($submittedSettings as $k => $v) {
            $stmtSet->execute([trim($k), trim($v)]);
            $updatedCount++;
        }

        log_admin_action('update_system_settings', 'system_settings', null, "Updated $updatedCount configuration variables");
        $msg = "System settings and dynamic pricing formulas saved successfully!";
    }
}

// Fetch Existing Settings
$settings = [];
try {
    $rows = $db->query("SELECT * FROM system_settings ORDER BY setting_key ASC")->fetchAll();
    foreach ($rows as $r) {
        $settings[$r['setting_key']] = $r['setting_value'];
    }
} catch (Exception $e) {}

// Default Fallbacks if empty
$defaults = [
    'base_fare'           => '100.00',
    'per_km_rate'         => '18.00',
    'per_min_rate'        => '2.00',
    'min_fare'            => '150.00',
    'platform_commission' => '15.0',
    'gst_percentage'      => '5.0',
    'driver_search_radius'=> '15.0',
    'sos_hotline_number'  => '+91112',
    'customer_helpline'   => '+919876543210',
    'support_email'       => 'support@drivemate.com',
    'app_version_min'     => '1.0.0',
];
$allSettings = array_merge($defaults, $settings);
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white"><i class="bi bi-gear-fill text-cyan me-2"></i>Dynamic Pricing & System Settings</h4>
        <p class="text-muted small mb-0">Changes update Flutter mobile clients and PHP API calculations instantly</p>
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

<form method="POST">
    <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">

    <div class="row g-4">
        <!-- Dynamic Pricing Matrix -->
        <div class="col-lg-6">
            <div class="dm-card p-4 h-100">
                <h5 class="fw-bold text-white mb-3">
                    <i class="bi bi-currency-rupee text-cyan me-2"></i>Fare Estimation & Dynamic Pricing
                </h5>

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Base Fare (₹)</label>
                    <input type="number" step="0.5" name="settings[base_fare]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['base_fare']) ?>" required>
                    <small class="text-muted" style="font-size: 0.75rem;">Initial charge when starting any booking</small>
                </div>

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Rate Per KM (₹/KM)</label>
                    <input type="number" step="0.5" name="settings[per_km_rate]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['per_km_rate']) ?>" required>
                    <small class="text-muted" style="font-size: 0.75rem;">Calculated using actual OSRM road distance</small>
                </div>

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Rate Per Minute (₹/Min)</label>
                    <input type="number" step="0.5" name="settings[per_min_rate]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['per_min_rate']) ?>" required>
                    <small class="text-muted" style="font-size: 0.75rem;">Duration billing rate for city traffic</small>
                </div>

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Minimum Fare Floor (₹)</label>
                    <input type="number" step="1" name="settings[min_fare]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['min_fare']) ?>" required>
                    <small class="text-muted" style="font-size: 0.75rem;">Absolute floor below which rides cannot be booked</small>
                </div>
            </div>
        </div>

        <!-- Commission, Tax & Helpline -->
        <div class="col-lg-6">
            <div class="dm-card p-4 h-100">
                <h5 class="fw-bold text-white mb-3">
                    <i class="bi bi-percent text-cyan me-2"></i>Commission, Tax & Emergency Hotlines
                </h5>

                <div class="row g-2 mb-3">
                    <div class="col-6">
                        <label class="form-label text-light small fw-bold">Platform Fee (%)</label>
                        <input type="number" step="0.5" name="settings[platform_commission]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['platform_commission']) ?>" required>
                    </div>
                    <div class="col-6">
                        <label class="form-label text-light small fw-bold">GST Tax Rate (%)</label>
                        <input type="number" step="0.5" name="settings[gst_percentage]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['gst_percentage']) ?>" required>
                    </div>
                </div>

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Driver Radar Radius (KM)</label>
                    <input type="number" step="1" name="settings[driver_search_radius]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['driver_search_radius']) ?>" required>
                </div>

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Customer Helpline Phone</label>
                    <input type="text" name="settings[customer_helpline]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['customer_helpline']) ?>" required>
                </div>

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Emergency SOS Police Hotline</label>
                    <input type="text" name="settings[sos_hotline_number]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['sos_hotline_number']) ?>" required>
                </div>

                <div class="mb-3">
                    <label class="form-label text-light small fw-bold">Official Support Email</label>
                    <input type="email" name="settings[support_email]" class="form-control form-control-dark" value="<?= htmlspecialchars($allSettings['support_email']) ?>" required>
                </div>
            </div>
        </div>
    </div>

    <div class="text-end mt-4">
        <button type="submit" name="save_settings" class="btn btn-cyan px-4 py-2 fw-bold">
            <i class="bi bi-floppy-fill me-2"></i> Save All Platform Configurations
        </button>
    </div>
</form>

<?php require_once __DIR__ . '/footer.php'; ?>
