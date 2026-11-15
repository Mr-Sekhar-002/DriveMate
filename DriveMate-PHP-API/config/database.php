<?php
// config/database.php — MySQL PDO connection

class Database {
    private static $instance = null;

    private string $host;
    private string $dbName;
    private string $user;
    private string $pass;

    private function __construct() {
        $this->host   = $_ENV['DB_HOST'] ?? getenv('DB_HOST') ?: 'localhost';
        $this->dbName = $_ENV['DB_NAME'] ?? getenv('DB_NAME') ?: 'drivemate';
        $this->user   = $_ENV['DB_USER'] ?? getenv('DB_USER') ?: 'root';
        $this->pass   = $_ENV['DB_PASS'] ?? getenv('DB_PASS') ?: '';
    }

    public static function getInstance(): PDO {
        if (self::$instance === null) {
            $db = new self();
            $port = $_ENV['DB_PORT'] ?? getenv('DB_PORT') ?: '3306';
            try {
                self::$instance = new PDO(
                    "mysql:host={$db->host};port={$port};dbname={$db->dbName};charset=utf8mb4",
                    $db->user,
                    $db->pass,
                    [
                        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                        PDO::ATTR_EMULATE_PREPARES   => false,
                    ]
                );
            } catch (PDOException $e) {
                http_response_code(500);
                $isDev = (getenv('APP_ENV') !== 'production');
                echo json_encode([
                    'success' => false,
                    'message' => 'Database connection failed',
                    'detail'  => $isDev ? $e->getMessage() : null
                ]);
                exit();
            }
        }
        return self::$instance;
    }
}
