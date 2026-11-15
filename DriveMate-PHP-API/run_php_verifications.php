<?php
// C:\xampp\htdocs\drivemate-api\run_php_verifications.php
$baseDir = __DIR__;

echo "=== 1. PHP LINT (php -l) CHECK ===\n";
$dirsToScan = [
    $baseDir . '/admin',
    $baseDir . '/config',
    $baseDir . '/controllers',
    $baseDir . '/helpers',
    $baseDir . '/middleware',
    $baseDir . '/routes',
    $baseDir . '/public'
];
$phpFiles = glob($baseDir . '/*.php');
foreach ($dirsToScan as $dir) {
    if (is_dir($dir)) {
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir));
        foreach ($it as $f) {
            if ($f->isFile() && $f->getExtension() === 'php' && strpos($f->getPathname(), 'backup_') === false) {
                $phpFiles[] = $f->getPathname();
            }
        }
    }
}
$phpFiles = array_unique($phpFiles);
sort($phpFiles);
$lintErrors = 0;
foreach ($phpFiles as $file) {
    $out = [];
    $ret = 0;
    exec("C:\\xampp\\php\\php.exe -l \"$file\" 2>&1", $out, $ret);
    if ($ret !== 0) {
        echo "FAIL: $file\n" . implode("\n", $out) . "\n";
        $lintErrors++;
    }
}
echo "PHP Lint check complete: " . count($phpFiles) . " source files checked, $lintErrors syntax errors.\n\n";

echo "=== 2. API ROUTE RESOLUTION CHECK ===\n";
require_once $baseDir . '/config/database.php';

// Mock request to prevent route dispatcher exit
$_SERVER['REQUEST_URI'] = '/drivemate-api/public/index.php/api/auth/login';
$_SERVER['REQUEST_METHOD'] = 'POST';

// Extract route definitions from routes/api.php
$routeContent = file_get_contents($baseDir . '/routes/api.php');
preg_match('/\$routes\s*=\s*\[(.*?)\];/s', $routeContent, $matches);
if (empty($matches[1])) {
    echo "FAIL: Could not extract route array\n";
    $routeErrors = 1;
} else {
    // Evaluate just the array
    $routes = eval("return [" . $matches[1] . "];");
    $routeErrors = 0;
    foreach ($routes as $route => $handler) {
        [$class, $method] = $handler;
        $classFile = $baseDir . '/controllers/' . $class . '.php';
        if (!file_exists($classFile)) {
            echo "FAIL Route $route: Controller file $classFile not found\n";
            $routeErrors++;
            continue;
        }
        require_once $classFile;
        if (!class_exists($class)) {
            echo "FAIL Route $route: Class $class not defined\n";
            $routeErrors++;
            continue;
        }
        if (!method_exists($class, $method)) {
            echo "FAIL Route $route: Method $class::$method not found\n";
            $routeErrors++;
            continue;
        }
    }
    echo "API Route check complete: " . count($routes) . " routes validated, $routeErrors errors.\n\n";
}

echo "=== 3. MYSQL DATABASE SCHEMA INTEGRITY CHECK ===\n";
$pdo = Database::getInstance();
$requiredTables = [
    'users', 'driver_profile', 'car_listings', 'vehicles', 'bookings',
    'trips', 'payments', 'reviews', 'fare_negotiations', 'notifications',
    'driver_device_tokens', 'support_tickets', 'admin_audit_logs', 'system_settings',
    'wallets', 'wallet_transactions', 'trip_status_history', 'otp_verifications'
];
$schemaErrors = 0;
foreach ($requiredTables as $t) {
    $res = $pdo->query("SHOW TABLES LIKE '$t'")->fetch();
    if (!$res) {
        echo "FAIL Table missing: $t\n";
        $schemaErrors++;
    } else {
        $cnt = $pdo->query("SELECT COUNT(*) FROM `$t`")->fetchColumn();
        echo "  [OK] Table '$t' present ($cnt rows)\n";
    }
}

// Check critical columns
$checkCols = [
    'bookings' => ['start_otp', 'start_otp_verified_at', 'start_otp_expires_at', 'negotiated_fare', 'negotiation_status'],
    'users'    => ['role', 'password', 'status'],
    'trips'    => ['fare', 'distance_km', 'status'],
    'payments' => ['transaction_id', 'payment_method', 'status', 'amount'],
    'reviews'  => ['booking_id', 'driver_id', 'user_id', 'rating', 'comment'],
    'support_tickets' => ['subject', 'category', 'message', 'admin_reply', 'status', 'resolved_at'],
];
foreach ($checkCols as $table => $cols) {
    $existing = [];
    foreach ($pdo->query("DESCRIBE `$table`") as $row) {
        $existing[] = $row['Field'];
    }
    foreach ($cols as $col) {
        if (!in_array($col, $existing)) {
            echo "FAIL Missing column: $table.$col\n";
            $schemaErrors++;
        }
    }
}
echo "MySQL schema check complete: $schemaErrors column errors.\n\n";

if ($lintErrors === 0 && $routeErrors === 0 && $schemaErrors === 0) {
    echo "=== ALL PHP & DATABASE CHECKS PASSED SUCCESSFULLY ===\n";
} else {
    echo "=== SOME CHECKS FAILED ===\n";
    exit(1);
}
