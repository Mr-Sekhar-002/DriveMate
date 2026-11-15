<?php
// admin/trips.php — DriveMate Real-Time Live Trip Monitoring & GPS Fleet Map
$pageTitle = 'Live Trip Monitoring';
$activePage = 'trips';
require_once __DIR__ . '/header.php';

// Fetch Active Ongoing Trips
$ongoingTrips = [];
try {
    $stmt = $db->query("SELECT t.*, 
                               b.pickup_location, b.pickup_lat, b.pickup_lng, 
                               b.destination, b.dest_lat, b.dest_lng, 
                               b.total_amount, b.start_otp, b.type AS service_type,
                               u_c.name AS customer_name, u_c.phone AS customer_phone,
                               u_d.name AS driver_name, u_d.phone AS driver_phone,
                               dp.vehicle_model, dp.license_number
                        FROM trips t 
                        JOIN bookings b ON t.booking_id = b.id 
                        LEFT JOIN users u_c ON b.user_id = u_c.id 
                        LEFT JOIN users u_d ON t.driver_id = u_d.id 
                        LEFT JOIN driver_profile dp ON t.driver_id = dp.user_id 
                        WHERE t.status = 'ongoing' 
                        ORDER BY t.updated_at DESC");
    $ongoingTrips = $stmt->fetchAll();
} catch (Exception $e) {
    error_log("Trips monitor query error: " . $e->getMessage());
}

// Fallback to latest trips for map display if no trip is currently active
$displayTrips = $ongoingTrips;
$isLiveOnly = true;
if (empty($displayTrips)) {
    $isLiveOnly = false;
    try {
        $stmt = $db->query("SELECT t.*, 
                                   b.pickup_location, b.pickup_lat, b.pickup_lng, 
                                   b.destination, b.dest_lat, b.dest_lng, 
                                   b.total_amount, b.start_otp, b.type AS service_type,
                                   u_c.name AS customer_name, u_c.phone AS customer_phone,
                                   u_d.name AS driver_name, u_d.phone AS driver_phone,
                                   dp.vehicle_model, dp.license_number
                            FROM trips t 
                            JOIN bookings b ON t.booking_id = b.id 
                            LEFT JOIN users u_c ON b.user_id = u_c.id 
                            LEFT JOIN users u_d ON t.driver_id = u_d.id 
                            LEFT JOIN driver_profile dp ON t.driver_id = dp.user_id 
                            ORDER BY t.updated_at DESC LIMIT 5");
        $displayTrips = $stmt->fetchAll();
    } catch (Exception $e) {}
}

$focusTripId = (int)($_GET['focus_trip'] ?? 0);
?>

<!-- Action Bar -->
<div class="d-flex flex-column flex-md-row align-items-md-center justify-content-between pb-3 mb-4 border-bottom" style="border-color: var(--dm-border) !important;">
    <div>
        <h4 class="fw-bold mb-1 text-white">
            <i class="bi bi-geo-alt-fill text-cyan me-2"></i>Live Trip & Fleet GPS Telemetry
        </h4>
        <p class="text-muted small mb-0">
            <?php if ($isLiveOnly): ?>
                <span class="text-success fw-bold"><span class="spinner-grow spinner-grow-sm text-success" style="width: 8px; height: 8px;"></span> <?= count($ongoingTrips) ?> Active Trips in Motion</span> &bull; OpenStreetMap Radar View
            <?php else: ?>
                <span class="text-muted">No trips currently ongoing &bull; Showing recent completed route history</span>
            <?php endif; ?>
        </p>
    </div>
    <div class="d-flex align-items-center gap-2 mt-3 mt-md-0">
        <span class="badge bg-dark border text-muted px-3 py-2" id="autoRefreshStatus">
            <i class="bi bi-arrow-repeat spin-icon"></i> Auto-refresh: 10s
        </span>
        <button class="btn btn-cyan btn-sm d-flex align-items-center gap-1" onclick="window.location.reload();">
            <i class="bi bi-arrow-clockwise"></i> Refresh Now
        </button>
    </div>
</div>

<div class="row g-4">
    <!-- Map Container -->
    <div class="col-lg-8">
        <div class="dm-card p-2" style="height: 620px;">
            <div id="fleetMap" style="width: 100%; height: 100%; border-radius: 12px; z-index: 10;"></div>
        </div>
    </div>

    <!-- Active Trips List Sidebar -->
    <div class="col-lg-4">
        <div class="dm-card h-100 d-flex flex-column" style="max-height: 620px;">
            <div class="dm-card-header">
                <h5>Active Vehicles & Trips</h5>
                <span class="badge badge-cyan"><?= count($displayTrips) ?> Vehicles</span>
            </div>
            <div class="p-3 flex-grow-1 overflow-y-auto">
                <?php if (empty($displayTrips)): ?>
                    <div class="text-center py-5 text-muted">
                        <i class="bi bi-radar fs-1 d-block mb-2 text-cyan"></i>
                        <h6 class="text-white">Waiting for Active Trips</h6>
                        <p class="small mb-0">When drivers start a ride, live GPS telemetry and routes will stream here in real-time.</p>
                    </div>
                <?php else: foreach ($displayTrips as $tr): 
                    $isFocus = ($focusTripId === (int)$tr['id']);
                ?>
                    <div class="p-3 mb-3 rounded-3 trip-card-item <?= $isFocus ? 'border-cyan' : '' ?>" 
                         style="background: rgba(11, 19, 43, 0.7); border: 1px solid <?= $isFocus ? 'var(--dm-cyan)' : 'var(--dm-border)' ?>; cursor: pointer;"
                         onclick="focusOnTrip(<?= $tr['id'] ?>, <?= $tr['current_lat'] ?? $tr['pickup_lat'] ?? 21.8767 ?>, <?= $tr['current_lng'] ?? $tr['pickup_lng'] ?? 88.1912 ?>)">
                        
                        <div class="d-flex justify-content-between align-items-start mb-2">
                            <div>
                                <span class="badge bg-dark border text-cyan fw-bold">#TRP-<?= $tr['id'] ?></span>
                                <span class="badge <?= $tr['status'] === 'ongoing' ? 'badge-success-subtle' : 'bg-secondary' ?> ms-1">
                                    <?= strtoupper($tr['status']) ?>
                                </span>
                            </div>
                            <span class="fw-bold text-white">₹<?= number_format($tr['total_amount'] ?? $tr['fare'], 2) ?></span>
                        </div>

                        <div class="mb-2">
                            <div class="fw-bold text-white"><i class="bi bi-person-fill text-muted me-1"></i> <?= htmlspecialchars($tr['customer_name'] ?? 'Guest Customer') ?></div>
                            <small class="text-muted"><i class="bi bi-steering text-cyan me-1"></i> Driver: <?= htmlspecialchars($tr['driver_name'] ?? 'Driver Assigned') ?> (<?= htmlspecialchars($tr['vehicle_model'] ?? 'Car') ?>)</small>
                        </div>

                        <div class="small text-muted border-top pt-2" style="border-color: rgba(255,255,255,0.05) !important;">
                            <div class="text-truncate mb-1"><i class="bi bi-record-circle text-cyan me-1"></i> <?= htmlspecialchars($tr['pickup_location'] ?? '-') ?></div>
                            <div class="text-truncate"><i class="bi bi-geo-alt-fill text-danger me-1"></i> <?= htmlspecialchars($tr['destination'] ?? '-') ?></div>
                        </div>

                        <div class="d-flex justify-content-between align-items-center mt-3 pt-2 border-top" style="border-color: rgba(255,255,255,0.05) !important;">
                            <small class="text-muted" style="font-size: 0.75rem;">
                                <?php if (!empty($tr['current_lat'])): ?>
                                    <code>GPS: <?= round($tr['current_lat'], 4) ?>, <?= round($tr['current_lng'], 4) ?></code>
                                <?php else: ?>
                                    <code>Stationary</code>
                                <?php endif; ?>
                            </small>
                            <button class="btn btn-sm btn-cyan py-0 px-2" style="font-size: 0.75rem;">
                                <i class="bi bi-crosshair"></i> Focus
                            </button>
                        </div>
                    </div>
                <?php endforeach; endif; ?>
            </div>
        </div>
    </div>
</div>

<!-- Map Script -->
<script>
    document.addEventListener("DOMContentLoaded", function () {
        // Initialize Leaflet Map
        const map = L.map('fleetMap').setView([21.8767, 88.1912], 12);

        // Dark-styled map tiles from CartoDB or OpenStreetMap
        L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/">CARTO</a>',
            maxZoom: 19
        }).addTo(map);

        const markers = [];
        const tripData = <?= json_encode($displayTrips) ?>;

        // Custom Icon Factory
        function createIcon(color, iconHtml) {
            return L.divIcon({
                className: 'custom-map-icon',
                html: `<div style="background: ${color}; width: 34px; height: 34px; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; box-shadow: 0 4px 12px rgba(0,0,0,0.4); border: 2px solid #fff; font-size: 14px;">${iconHtml}</div>`,
                iconSize: [34, 34],
                iconAnchor: [17, 17]
            });
        }

        const bounds = [];

        tripData.forEach(function (tr) {
            const pLat = parseFloat(tr.pickup_lat);
            const pLng = parseFloat(tr.pickup_lng);
            const dLat = parseFloat(tr.dest_lat);
            const dLng = parseFloat(tr.dest_lng);
            const cLat = parseFloat(tr.current_lat) || pLat;
            const cLng = parseFloat(tr.current_lng) || pLng;

            // Pickup Marker
            if (!isNaN(pLat) && !isNaN(pLng) && pLat !== 0) {
                const pMarker = L.marker([pLat, pLng], { icon: createIcon('#00F2FE', '🟢') })
                    .bindPopup(`<b>Trip #${tr.id} Pickup</b><br>${tr.pickup_location}<br>Customer: ${tr.customer_name}`)
                    .addTo(map);
                bounds.push([pLat, pLng]);
            }

            // Destination Marker
            if (!isNaN(dLat) && !isNaN(dLng) && dLat !== 0) {
                const dMarker = L.marker([dLat, dLng], { icon: createIcon('#EF4444', '🏁') })
                    .bindPopup(`<b>Trip #${tr.id} Destination</b><br>${tr.destination}`)
                    .addTo(map);
                bounds.push([dLat, dLng]);
            }

            // Driver Current GPS Marker
            if (!isNaN(cLat) && !isNaN(cLng) && cLat !== 0) {
                const carMarker = L.marker([cLat, cLng], { icon: createIcon('#3B82F6', '🚗') })
                    .bindPopup(`<b>Trip #${tr.id} Driver</b><br>${tr.driver_name}<br>Vehicle: ${tr.vehicle_model || 'Car'}`)
                    .addTo(map);
                bounds.push([cLat, cLng]);

                // Polyline Route from Pickup to Current to Destination
                if (!isNaN(pLat) && !isNaN(pLng) && !isNaN(dLat) && !isNaN(dLng)) {
                    L.polyline([[pLat, pLng], [cLat, cLng], [dLat, dLng]], {
                        color: '#00F2FE',
                        weight: 4,
                        opacity: 0.8,
                        dashArray: '6, 8'
                    }).addTo(map);
                }
            }
        });

        // Fit map bounds if markers exist
        if (bounds.length > 0) {
            map.fitBounds(bounds, { padding: [50, 50], maxZoom: 15 });
        }

        // Window function to focus on specific trip
        window.focusOnTrip = function (tripId, lat, lng) {
            if (lat && lng) {
                map.flyTo([lat, lng], 15, { duration: 1.2 });
            }
        };

        // Auto Refresh every 10 seconds
        setTimeout(function() {
            window.location.reload();
        }, 10000);
    });
</script>

<?php require_once __DIR__ . '/footer.php'; ?>
