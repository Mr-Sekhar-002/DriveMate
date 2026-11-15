<?php
// admin/login.php — DriveMate Dedicated Admin Web Portal Login
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once __DIR__ . '/../config/database.php';
$db = Database::getInstance();

// If already authenticated as admin, redirect to dashboard
if (!empty($_SESSION['admin_logged_in']) && $_SESSION['admin_logged_in'] === true && ($_SESSION['admin_role'] ?? '') === 'admin') {
    header("Location: index.php");
    exit();
}

// Generate CSRF token for login
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

$error = '';
$redirect = $_GET['redirect'] ?? 'index.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email    = trim($_POST['email'] ?? '');
    $password = $_POST['password'] ?? '';
    $token    = $_POST['csrf_token'] ?? '';

    if (empty($_SESSION['csrf_token']) || !hash_equals($_SESSION['csrf_token'], $token)) {
        $error = 'Security session expired. Please refresh and try again.';
    } elseif (empty($email) || empty($password)) {
        $error = 'Please enter both email and password.';
    } else {
        $stmt = $db->prepare("SELECT * FROM users WHERE email = ? LIMIT 1");
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if ($user && password_verify($password, $user['password'])) {
            if ($user['role'] !== 'admin') {
                $error = 'Access Denied: This account does not possess Administrative privileges.';
            } elseif ($user['status'] !== 'active') {
                $error = 'Your admin account has been suspended or deactivated.';
            } else {
                // Successful login: regenerate session ID to prevent fixation
                session_regenerate_id(true);
                $_SESSION['admin_logged_in'] = true;
                $_SESSION['admin_user_id']   = (int)$user['id'];
                $_SESSION['admin_name']      = $user['name'];
                $_SESSION['admin_email']     = $user['email'];
                $_SESSION['admin_role']      = 'admin';

                // Audit log login
                try {
                    $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
                    $logStmt = $db->prepare("INSERT INTO admin_audit_logs (admin_id, action, target_type, target_id, details, ip_address, created_at) VALUES (?, 'login', 'admin', ?, 'Admin logged into web panel', ?, NOW())");
                    $logStmt->execute([$user['id'], $user['id'], $ip]);
                } catch (Exception $e) {}

                $target = (!empty($redirect) && strpos($redirect, 'login.php') === false) ? $redirect : 'index.php';
                header("Location: " . $target);
                exit();
            }
        } else {
            $error = 'Invalid email address or password.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DriveMate Admin Portal — Sign In</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --dm-navy: #0B132B;
            --dm-dark: #1C2541;
            --dm-cyan: #00F2FE;
            --dm-cyan-glow: rgba(0, 242, 254, 0.35);
        }
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background: linear-gradient(135deg, #070B19 0%, #0B132B 50%, #111D3E 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0;
            padding: 20px;
            color: #fff;
        }
        .login-card {
            background: rgba(28, 37, 65, 0.75);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid rgba(0, 242, 254, 0.2);
            border-radius: 20px;
            box-shadow: 0 20px 45px rgba(0, 0, 0, 0.5), 0 0 25px rgba(0, 242, 254, 0.1);
            max-width: 440px;
            width: 100%;
            padding: 40px 35px;
        }
        .brand-badge {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            background: rgba(0, 242, 254, 0.1);
            border: 1px solid rgba(0, 242, 254, 0.3);
            border-radius: 30px;
            padding: 6px 16px;
            color: var(--dm-cyan);
            font-size: 0.82rem;
            font-weight: 700;
            letter-spacing: 1px;
            text-transform: uppercase;
            margin-bottom: 20px;
        }
        .form-control {
            background: rgba(11, 19, 43, 0.8);
            border: 1px solid rgba(164, 176, 203, 0.25);
            color: #fff;
            padding: 12px 16px;
            border-radius: 10px;
            font-size: 0.95rem;
            transition: all 0.25s ease;
        }
        .form-control:focus {
            background: rgba(11, 19, 43, 0.95);
            border-color: var(--dm-cyan);
            box-shadow: 0 0 0 3px var(--dm-cyan-glow);
            color: #fff;
        }
        .form-control::placeholder {
            color: #6C7D93;
        }
        .input-group-text {
            background: rgba(11, 19, 43, 0.8);
            border: 1px solid rgba(164, 176, 203, 0.25);
            border-right: none;
            color: var(--dm-cyan);
            border-radius: 10px 0 0 10px;
        }
        .input-group .form-control {
            border-radius: 0 10px 10px 0;
            border-left: none;
        }
        .btn-dm-primary {
            background: linear-gradient(135deg, #00C6FF 0%, #0072FF 100%);
            border: none;
            color: #fff;
            padding: 12px 24px;
            border-radius: 10px;
            font-weight: 700;
            font-size: 1rem;
            letter-spacing: 0.5px;
            transition: all 0.3s ease;
            box-shadow: 0 6px 18px rgba(0, 114, 255, 0.35);
        }
        .btn-dm-primary:hover {
            background: linear-gradient(135deg, #00F2FE 0%, #00C6FF 100%);
            color: #0B132B;
            box-shadow: 0 8px 24px rgba(0, 242, 254, 0.45);
            transform: translateY(-1px);
        }
        .credentials-pill {
            background: rgba(0, 242, 254, 0.05);
            border: 1px dashed rgba(0, 242, 254, 0.3);
            border-radius: 10px;
            padding: 12px 14px;
            font-size: 0.82rem;
            color: #A4B0CB;
            margin-top: 25px;
        }
        .credentials-pill code {
            color: var(--dm-cyan);
            background: rgba(0, 0, 0, 0.3);
            padding: 2px 6px;
            border-radius: 4px;
        }
    </style>
</head>
<body>

<div class="login-card">
    <div class="text-center">
        <div class="brand-badge">
            <i class="bi bi-shield-lock-fill"></i> Secure Administration
        </div>
        <h2 class="fw-bold mb-1" style="color: #fff;">Drive<span style="color: var(--dm-cyan);">Mate</span></h2>
        <p class="text-muted small mb-4">Enterprise Fleet & Ride Management Portal</p>
    </div>

    <?php if (!empty($error)): ?>
        <div class="alert alert-danger alert-dismissible fade show d-flex align-items-center py-2 px-3 small border-0" style="background: rgba(239, 68, 68, 0.2); color: #FCA5A5; border-radius: 10px;" role="alert">
            <i class="bi bi-exclamation-octagon-fill me-2 fs-6"></i>
            <div><?= htmlspecialchars($error) ?></div>
            <button type="button" class="btn-close btn-close-white ms-auto" data-bs-dismiss="alert"></button>
        </div>
    <?php endif; ?>

    <form method="POST" autocomplete="off">
        <input type="hidden" name="csrf_token" value="<?= htmlspecialchars($_SESSION['csrf_token']) ?>">

        <div class="mb-3">
            <label class="form-label small fw-semibold text-light mb-1">Admin Email Address</label>
            <div class="input-group">
                <span class="input-group-text"><i class="bi bi-envelope-at-fill"></i></span>
                <input type="email" name="email" class="form-control" placeholder="admin@drivemate.com" value="<?= htmlspecialchars($_POST['email'] ?? (getenv('APP_ENV') !== 'production' ? 'admin@drivemate.com' : '')) ?>" required autofocus>
            </div>
        </div>

        <div class="mb-4">
            <label class="form-label small fw-semibold text-light mb-1">Secret Key / Password</label>
            <div class="input-group">
                <span class="input-group-text"><i class="bi bi-key-fill"></i></span>
                <input type="password" name="password" class="form-control" placeholder="••••••••••••" required>
            </div>
        </div>

        <button type="submit" class="btn btn-dm-primary w-100 mb-2">
            <i class="bi bi-box-arrow-in-right me-2"></i> Access Admin Dashboard
        </button>
    </form>

    <?php if (getenv('APP_ENV') !== 'production'): ?>
    <div class="credentials-pill text-center">
        <i class="bi bi-info-circle me-1 text-cyan"></i> [Development Sandbox Only] Credentials: <br>
        Email: <code>admin@drivemate.com</code> | Password: <code>password123</code>
    </div>
    <?php endif; ?>

    <div class="text-center mt-4">
        <small class="text-muted" style="font-size: 0.75rem;">
            &copy; <?= date('Y') ?> DriveMate Technologies &bull; Single-Sign-On Server Ver 2.4
        </small>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
