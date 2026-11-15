        </main>

        <!-- Admin Footer -->
        <footer class="py-3 px-4 mt-auto border-top" style="background: rgba(11, 19, 43, 0.7); border-color: var(--dm-border) !important; font-size: 0.8rem; color: #64748B;">
            <div class="d-flex flex-column flex-md-row justify-content-between align-items-center gap-2">
                <div>
                    &copy; <?= date('Y') ?> <strong class="text-white">DriveMate Technologies</strong> &bull; Enterprise Ride & Car Rental Fleet Engine
                </div>
                <div class="d-flex align-items-center gap-3">
                    <span><i class="bi bi-hdd-network text-success me-1"></i> XAMPP Apache/MySQL Connected</span>
                    <span>&bull;</span>
                    <span id="adminLiveClock"></span>
                </div>
            </div>
        </footer>
    </div>
</div>

<!-- Bootstrap 5 Bundle -->
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<!-- Leaflet JS for Maps -->
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>

<script>
    // Sidebar Toggle
    const sidebarToggle = document.getElementById('sidebarToggle');
    const sidebar = document.getElementById('sidebar-wrapper');
    const content = document.getElementById('page-content-wrapper');

    if (sidebarToggle && sidebar && content) {
        sidebarToggle.addEventListener('click', function(e) {
            e.preventDefault();
            if (window.innerWidth <= 992) {
                sidebar.classList.toggle('mobile-show');
            } else {
                sidebar.classList.toggle('collapsed');
                content.classList.toggle('expanded');
            }
        });
    }

    // Live Clock
    function updateClock() {
        const clockEl = document.getElementById('adminLiveClock');
        if (clockEl) {
            const now = new Date();
            clockEl.textContent = now.toLocaleDateString() + ' ' + now.toLocaleTimeString();
        }
    }
    updateClock();
    setInterval(updateClock, 1000);
</script>
</body>
</html>
