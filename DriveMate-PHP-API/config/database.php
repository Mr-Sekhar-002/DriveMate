<?php
// config/database.php — MySQL PDO connection with Cloud (Aiven, Render, Railway) & Local support

class Database {
    private static ?PDO $instance = null;

    private string $host;
    private string $dbName;
    private string $user;
    private string $pass;
    private string $port;

    private function __construct() {
        // Check for complete connection URL (e.g. from Aiven, Railway, or Render)
        $connUrl = $_ENV['DATABASE_URL'] ?? getenv('DATABASE_URL') ?: ($_ENV['MYSQL_URL'] ?? getenv('MYSQL_URL') ?: null);
        if ($connUrl) {
            $parsed = parse_url($connUrl);
            if ($parsed && isset($parsed['host'])) {
                $this->host   = $parsed['host'];
                $this->port   = (string)($parsed['port'] ?? 3306);
                $this->user   = $parsed['user'] ?? 'root';
                $this->pass   = $parsed['pass'] ?? '';
                $this->dbName = isset($parsed['path']) ? ltrim($parsed['path'], '/') : 'drivemate';
                return;
            }
        }

        // Standard individual environment variables
        $this->host   = $_ENV['DB_HOST'] ?? getenv('DB_HOST') ?: 'localhost';
        $this->port   = (string)($_ENV['DB_PORT'] ?? getenv('DB_PORT') ?: '3306');
        $this->dbName = $_ENV['DB_NAME'] ?? getenv('DB_NAME') ?: 'drivemate';
        $this->user   = $_ENV['DB_USER'] ?? getenv('DB_USER') ?: 'root';
        $this->pass   = $_ENV['DB_PASS'] ?? getenv('DB_PASS') ?? $_ENV['DB_PASSWORD'] ?? getenv('DB_PASSWORD') ?: '';
    }

    public static function getInstance(): PDO {
        if (self::$instance === null) {
            $db = new self();
            
            $options = [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ];

            // Enable SSL for cloud database providers (Aiven, TiDB, Clever Cloud, etc.)
            $isCloudDb = str_contains($db->host, 'aivencloud.com') 
                      || str_contains($db->host, 'tidbcloud.com')
                      || str_contains($db->host, 'clever-cloud.com')
                      || filter_var($_ENV['DB_SSL'] ?? getenv('DB_SSL') ?? false, FILTER_VALIDATE_BOOLEAN);

            if ($isCloudDb && defined('PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT')) {
                $options[PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT] = false;
            }

            try {
                self::$instance = new PDO(
                    "mysql:host={$db->host};port={$db->port};dbname={$db->dbName};charset=utf8mb4",
                    $db->user,
                    $db->pass,
                    $options
                );
            } catch (PDOException $e) {
                http_response_code(500);
                $isDev = (getenv('APP_ENV') !== 'production');
                echo json_encode([
                    'success' => false,
                    'message' => 'Database connection failed',
                    'detail'  => $isDev ? $e->getMessage() : 'Could not connect to database server. Check DB host, port, credentials, and network permissions.'
                ]);
                exit();
            }
        }
        return self::$instance;
    }
}
