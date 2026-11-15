<?php
// admin/header.php — Common Header and Collapsible Navigation Shell
require_once __DIR__ . '/auth_check.php';

$activePage = $activePage ?? 'dashboard';
$adminName  = htmlspecialchars($_SESSION['admin_name'] ?? 'Administrator');
$adminEmail = htmlspecialchars($_SESSION['admin_email'] ?? 'admin@drivemate.com');

// Fast KPI badge counters for header
$headerOnlineDrivers = 0;
$headerOpenTickets   = 0;
try {
    $headerOnlineDrivers = (int)$db->query("SELECT COUNT(*) FROM driver_profile WHERE is_online = 1")->fetchColumn();
    $headerOpenTickets   = (int)$db->query("SELECT COUNT(*) FROM support_tickets WHERE status = 'open'")->fetchColumn();
} catch (Exception $e) {}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($pageTitle ?? 'Admin Portal') ?> — DriveMate</title>
    <!-- Bootstrap 5.3 & Icons -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <!-- Google Fonts -->
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <!-- Leaflet CSS for Live Trip Map -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin=""/>
    
    <style>
        :root {
            --dm-navy: #0B132B;
            --dm-dark: #1C2541;
            --dm-darker: #070B19;
            --dm-card: #151D36;
            --dm-border: rgba(0, 242, 254, 0.15);
            --dm-cyan: #00F2FE;
            --dm-cyan-hover: #4FACFE;
            --dm-text-main: #F8FAFC;
            --dm-text-muted: #94A3B8;
        }

        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: var(--dm-darker);
            color: var(--dm-text-main);
            min-height: 100vh;
            overflow-x: hidden;
        }

        /* Sidebar Styling */
        #sidebar-wrapper {
            width: 270px;
            min-height: 100vh;
            background: linear-gradient(180deg, #0B132B 0%, #070B19 100%);
            border-right: 1px solid var(--dm-border);
            transition: all 0.3s ease;
            position: fixed;
            top: 0;
            bottom: 0;
            left: 0;
            z-index: 1040;
            overflow-y: auto;
        }

        #sidebar-wrapper.collapsed {
            margin-left: -270px;
        }

        .sidebar-brand {
            padding: 24px 20px;
            display: flex;
            align-items: center;
            gap: 12px;
            border-bottom: 1px solid var(--dm-border);
        }

        .sidebar-brand h5 {
            margin: 0;
            font-weight: 800;
            letter-spacing: -0.5px;
            color: #fff;
        }

        .sidebar-brand h5 span {
            color: var(--dm-cyan);
        }

        .sidebar-nav {
            padding: 16px 12px;
            list-style: none;
            margin: 0;
        }

        .sidebar-nav .nav-header {
            font-size: 0.72rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 1.2px;
            color: #64748B;
            padding: 14px 16px 6px 16px;
        }

        .sidebar-nav .nav-link {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 10px 16px;
            color: var(--dm-text-muted);
            font-size: 0.9rem;
            font-weight: 500;
            border-radius: 10px;
            margin-bottom: 4px;
            text-decoration: none;
            transition: all 0.2s ease;
        }

        .sidebar-nav .nav-link i {
            font-size: 1.15rem;
            width: 22px;
            text-align: center;
            color: #64748B;
            transition: color 0.2s ease;
        }

        .sidebar-nav .nav-link:hover {
            color: #fff;
            background: rgba(0, 242, 254, 0.08);
        }

        .sidebar-nav .nav-link:hover i {
            color: var(--dm-cyan);
        }

        .sidebar-nav .nav-link.active {
            color: #0B132B;
            background: linear-gradient(135deg, var(--dm-cyan) 0%, var(--dm-cyan-hover) 100%);
            font-weight: 700;
            box-shadow: 0 4px 15px rgba(0, 242, 254, 0.3);
        }

        .sidebar-nav .nav-link.active i {
            color: #0B132B;
        }

        /* Main Content Layout */
        #page-content-wrapper {
            margin-left: 270px;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            transition: all 0.3s ease;
        }

        #page-content-wrapper.expanded {
            margin-left: 0;
        }

        /* Top Navbar */
        .admin-topbar {
            height: 70px;
            background: rgba(11, 19, 43, 0.9);
            backdrop-filter: blur(12px);
            border-bottom: 1px solid var(--dm-border);
            padding: 0 28px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            position: sticky;
            top: 0;
            z-index: 1020;
        }

        .btn-toggle-sidebar {
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--dm-border);
            color: #fff;
            border-radius: 8px;
            padding: 6px 12px;
        }
        .btn-toggle-sidebar:hover {
            background: rgba(0, 242, 254, 0.15);
            color: var(--dm-cyan);
        }

        /* Premium Dark UI Cards */
        .dm-card {
            background: var(--dm-card);
            border: 1px solid var(--dm-border);
            border-radius: 16px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .dm-card-header {
            padding: 18px 24px;
            border-bottom: 1px solid var(--dm-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .dm-card-header h5 {
            margin: 0;
            font-weight: 700;
            font-size: 1.05rem;
            color: #fff;
        }

        .dm-stat-widget {
            padding: 22px;
            border-radius: 16px;
            background: var(--dm-card);
            border: 1px solid var(--dm-border);
            position: relative;
            overflow: hidden;
        }
        .dm-stat-widget::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background: var(--dm-cyan);
        }

        .dm-table {
            color: #E2E8F0;
            vertical-align: middle;
            margin-bottom: 0;
        }
        .dm-table thead th {
            background: rgba(11, 19, 43, 0.85);
            color: #94A3B8;
            font-size: 0.78rem;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            font-weight: 700;
            border-bottom: 1px solid var(--dm-border);
            padding: 14px 18px;
        }
        .dm-table tbody td {
            background: transparent;
            border-bottom: 1px solid rgba(255, 255, 255, 0.05);
            padding: 14px 18px;
            font-size: 0.9rem;
        }
        .dm-table tbody tr:hover td {
            background: rgba(0, 242, 254, 0.03);
            color: #fff;
        }

        .badge-cyan {
            background: rgba(0, 242, 254, 0.15);
            color: var(--dm-cyan);
            border: 1px solid rgba(0, 242, 254, 0.3);
            font-weight: 600;
        }

        .badge-success-subtle {
            background: rgba(16, 185, 129, 0.15);
            color: #34D399;
            border: 1px solid rgba(16, 185, 129, 0.3);
        }

        .badge-warning-subtle {
            background: rgba(245, 158, 11, 0.15);
            color: #FBBF24;
            border: 1px solid rgba(245, 158, 11, 0.3);
        }

        .badge-danger-subtle {
            background: rgba(239, 68, 68, 0.15);
            color: #F87171;
            border: 1px solid rgba(239, 68, 68, 0.3);
        }

        .btn-cyan {
            background: linear-gradient(135deg, var(--dm-cyan) 0%, var(--dm-cyan-hover) 100%);
            color: #0B132B;
            font-weight: 700;
            border: none;
            border-radius: 8px;
            padding: 8px 16px;
            transition: all 0.2s ease;
        }
        .btn-cyan:hover {
            color: #000;
            box-shadow: 0 4px 15px rgba(0, 242, 254, 0.4);
            transform: translateY(-1px);
        }

        .form-control-dark, .form-select-dark {
            background: rgba(11, 19, 43, 0.8) !important;
            border: 1px solid var(--dm-border) !important;
            color: #fff !important;
            border-radius: 10px;
        }
        .form-control-dark:focus, .form-select-dark:focus {
            border-color: var(--dm-cyan) !important;
            box-shadow: 0 0 0 3px rgba(0, 242, 254, 0.2) !important;
        }

        @media (max-width: 992px) {
            #sidebar-wrapper {
                margin-left: -270px;
            }
            #sidebar-wrapper.mobile-show {
                margin-left: 0;
            }
            #page-content-wrapper {
                margin-left: 0;
            }
        }
    </style>
</head>
<body>

<div class="d-flex" id="wrapper">
    <!-- Sidebar -->
    <div id="sidebar-wrapper">
        <div class="sidebar-brand">
            <div style="background: linear-gradient(135deg, #00F2FE 0%, #4FACFE 100%); width: 38px; height: 38px; border-radius: 10px; display: flex; align-items: center; justify-content: center; color: #0B132B; font-weight: 800; font-size: 1.2rem;">
                D
            </div>
            <div>
                <h5>Drive<span>Mate</span></h5>
                <small style="font-size: 0.72rem; color: #94A3B8; text-transform: uppercase; letter-spacing: 1px;">Admin Console</small>
            </div>
        </div>

        <ul class="sidebar-nav">
            <li class="nav-header">Analytics & Operations</li>
            <li>
                <a href="index.php" class="nav-link <?= $activePage === 'dashboard' ? 'active' : '' ?>">
                    <i class="bi bi-grid-1x2-fill"></i>
                    <span>Dashboard</span>
                </a>
            </li>
            <li>
                <a href="trips.php" class="nav-link <?= $activePage === 'trips' ? 'active' : '' ?>">
                    <i class="bi bi-geo-alt-fill"></i>
                    <span>Live Trip Monitor</span>
                </a>
            </li>
            <li>
                <a href="bookings.php" class="nav-link <?= $activePage === 'bookings' ? 'active' : '' ?>">
                    <i class="bi bi-calendar-check-fill"></i>
                    <span>Booking Management</span>
                </a>
            </li>

            <li class="nav-header">Users & Fleet</li>
            <li>
                <a href="customers.php" class="nav-link <?= $activePage === 'customers' ? 'active' : '' ?>">
                    <i class="bi bi-people-fill"></i>
                    <span>Customer Desk</span>
                </a>
            </li>
            <li>
                <a href="drivers.php" class="nav-link <?= $activePage === 'drivers' ? 'active' : '' ?>">
                    <i class="bi bi-person-badge-fill"></i>
                    <span>Driver Fleet</span>
                </a>
            </li>
            <li>
                <a href="kyc.php" class="nav-link <?= $activePage === 'kyc' ? 'active' : '' ?>">
                    <i class="bi bi-file-earmark-check-fill"></i>
                    <span>Driver KYC & Docs</span>
                </a>
            </li>
            <li>
                <a href="owners.php" class="nav-link <?= $activePage === 'owners' ? 'active' : '' ?>">
                    <i class="bi bi-building-fill"></i>
                    <span>Car Owners</span>
                </a>
            </li>
            <li>
                <a href="vehicles.php" class="nav-link <?= $activePage === 'vehicles' ? 'active' : '' ?>">
                    <i class="bi bi-car-front-fill"></i>
                    <span>Vehicle Approvals</span>
                </a>
            </li>

            <li class="nav-header">Financials & Support</li>
            <li>
                <a href="payments.php" class="nav-link <?= $activePage === 'payments' ? 'active' : '' ?>">
                    <i class="bi bi-credit-card-2-front-fill"></i>
                    <span>Payments & Invoices</span>
                </a>
            </li>
            <li>
                <a href="reports.php" class="nav-link <?= $activePage === 'reports' ? 'active' : '' ?>">
                    <i class="bi bi-graph-up-arrow"></i>
                    <span>Revenue Reports</span>
                </a>
            </li>
            <li>
                <a href="reviews.php" class="nav-link <?= $activePage === 'reviews' ? 'active' : '' ?>">
                    <i class="bi bi-star-fill"></i>
                    <span>Ratings & Reviews</span>
                </a>
            </li>
            <li>
                <a href="support.php" class="nav-link <?= $activePage === 'support' ? 'active' : '' ?>">
                    <i class="bi bi-headset"></i>
                    <span>Support Tickets</span>
                    <?php if ($headerOpenTickets > 0): ?>
                        <span class="badge bg-danger ms-auto rounded-pill" style="font-size: 0.7rem;"><?= $headerOpenTickets ?></span>
                    <?php endif; ?>
                </a>
            </li>

            <li class="nav-header">System & Security</li>
            <li>
                <a href="notifications.php" class="nav-link <?= $activePage === 'notifications' ? 'active' : '' ?>">
                    <i class="bi bi-bell-fill"></i>
                    <span>Push Notifications</span>
                </a>
            </li>
            <li>
                <a href="settings.php" class="nav-link <?= $activePage === 'settings' ? 'active' : '' ?>">
                    <i class="bi bi-gear-fill"></i>
                    <span>System Settings</span>
                </a>
            </li>
            <li>
                <a href="audit_logs.php" class="nav-link <?= $activePage === 'audit_logs' ? 'active' : '' ?>">
                    <i class="bi bi-shield-shaded"></i>
                    <span>Security Audit Logs</span>
                </a>
            </li>
        </ul>

        <div class="p-3 mt-4 border-top" style="border-color: var(--dm-border) !important;">
            <a href="logout.php" class="btn btn-outline-danger w-100 btn-sm rounded-pill d-flex align-items-center justify-content-center gap-2">
                <i class="bi bi-power"></i> Sign Out
            </a>
        </div>
    </div>

    <!-- Page Content Wrapper -->
    <div id="page-content-wrapper">
        <!-- Top Navbar -->
        <nav class="admin-topbar">
            <div class="d-flex align-items-center gap-3">
                <button class="btn btn-toggle-sidebar" id="sidebarToggle" title="Toggle Sidebar">
                    <i class="bi bi-list fs-5"></i>
                </button>
                <div class="d-none d-md-block">
                    <h6 class="mb-0 fw-bold"><?= htmlspecialchars($pageTitle ?? 'Admin Dashboard') ?></h6>
                    <small class="text-muted" style="font-size: 0.75rem;">Database: <code>drivemate</code> &bull; Local API</small>
                </div>
            </div>

            <div class="d-flex align-items-center gap-3">
                <div class="d-none d-sm-flex align-items-center gap-2 px-3 py-1 rounded-pill" style="background: rgba(0, 242, 254, 0.08); border: 1px solid var(--dm-border);">
                    <span class="badge rounded-pill bg-success" style="width: 8px; height: 8px; padding: 0;">&nbsp;</span>
                    <small style="font-size: 0.8rem; color: var(--dm-cyan);">Drivers Online: <strong><?= $headerOnlineDrivers ?></strong></small>
                </div>

                <!-- Admin Profile Dropdown -->
                <div class="dropdown">
                    <button class="btn btn-dark dropdown-toggle d-flex align-items-center gap-2 border-0 px-2 py-1 rounded-pill" type="button" data-bs-toggle="dropdown" style="background: rgba(28, 37, 65, 0.9);">
                        <div class="rounded-circle d-flex align-items-center justify-content-center text-dark fw-bold" style="background: var(--dm-cyan); width: 32px; height: 32px; font-size: 0.85rem;">
                            <?= strtoupper(substr($adminName, 0, 1)) ?>
                        </div>
                        <div class="text-start d-none d-md-block pe-1">
                            <div class="small fw-bold text-white lh-1"><?= $adminName ?></div>
                            <small class="text-muted" style="font-size: 0.68rem;">Super Admin</small>
                        </div>
                    </button>
                    <ul class="dropdown-menu dropdown-menu-end shadow border-0" style="background: var(--dm-card); border: 1px solid var(--dm-border) !important;">
                        <li><h6 class="dropdown-header text-muted small"><?= $adminEmail ?></h6></li>
                        <li><a class="dropdown-item text-light small py-2" href="settings.php"><i class="bi bi-sliders me-2 text-cyan"></i> Platform Settings</a></li>
                        <li><a class="dropdown-item text-light small py-2" href="audit_logs.php"><i class="bi bi-shield-check me-2 text-cyan"></i> My Activity Logs</a></li>
                        <li><hr class="dropdown-divider" style="border-color: var(--dm-border);"></li>
                        <li><a class="dropdown-item text-danger small py-2" href="logout.php"><i class="bi bi-power me-2"></i> Log Out</a></li>
                    </ul>
                </div>
            </div>
        </nav>

        <!-- Main Body Container -->
        <main class="flex-grow-1 p-4">
