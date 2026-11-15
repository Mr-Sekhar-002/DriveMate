<?php
// middleware/AuthMiddleware.php — Validates JWT and enforces server-side RBAC on protected routes

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../helpers/JwtHelper.php';

class AuthMiddleware {

    /**
     * Extract Bearer token from HTTP headers.
     * Supports standard getallheaders(), Apache HTTP_AUTHORIZATION, and REDIRECT_HTTP_AUTHORIZATION.
     */
    private static function extractBearerToken(): ?string {
        $authHeader = '';

        if (function_exists('getallheaders')) {
            $headers = getallheaders();
            $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';
        }

        if (empty($authHeader)) {
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        }

        if (!empty($authHeader) && preg_match('/Bearer\s+(\S+)/i', $authHeader, $matches)) {
            return trim($matches[1]);
        }

        return null;
    }

    /**
     * Authenticate request using cryptographically verified JWT.
     * Rejects all unverified headers and POST/GET parameter fallbacks.
     *
     * @return array Decoded & verified user claims [sub, role, email, ...]
     */
    public static function authenticate(): array {
        $token = self::extractBearerToken();

        if (empty($token)) {
            http_response_code(401);
            echo json_encode([
                'success' => false,
                'message' => 'Unauthorized: Valid Bearer JWT token required'
            ]);
            exit();
        }

        try {
            $payload = JwtHelper::decode($token);
        } catch (Exception $e) {
            http_response_code(401);
            echo json_encode([
                'success' => false,
                'message' => 'Unauthorized: ' . $e->getMessage()
            ]);
            exit();
        }

        // Validate required claims
        if (empty($payload['sub']) || !is_numeric($payload['sub']) || empty($payload['role'])) {
            http_response_code(401);
            echo json_encode([
                'success' => false,
                'message' => 'Unauthorized: Invalid token claims'
            ]);
            exit();
        }

        // Verify user exists in database and account is in active standing
        try {
            $db = Database::getInstance();
            $stmt = $db->prepare("SELECT id, name, email, role, status FROM users WHERE id = ?");
            $stmt->execute([(int)$payload['sub']]);
            $user = $stmt->fetch();

            if (!$user) {
                http_response_code(401);
                echo json_encode([
                    'success' => false,
                    'message' => 'Unauthorized: User account does not exist'
                ]);
                exit();
            }

            if (isset($user['status']) && $user['status'] === 'banned') {
                http_response_code(403);
                echo json_encode([
                    'success' => false,
                    'message' => 'Forbidden: User account is suspended or banned'
                ]);
                exit();
            }

            // Enforce database-authoritative role and ID
            $payload['sub']   = (int)$user['id'];
            $payload['role']  = $user['role'];
            $payload['name']  = $user['name'] ?? ($payload['name'] ?? '');
            $payload['email'] = $user['email'] ?? ($payload['email'] ?? '');

            return $payload;
        } catch (PDOException $e) {
            http_response_code(500);
            echo json_encode([
                'success' => false,
                'message' => 'Authentication service unavailable'
            ]);
            exit();
        }
    }

    /**
     * Optional authentication: returns payload if valid Bearer token provided, or null if unauthenticated.
     */
    public static function optionalAuthenticate(): ?array {
        $token = self::extractBearerToken();
        if (empty($token)) {
            return null;
        }

        try {
            $payload = JwtHelper::decode($token);
            if (empty($payload['sub']) || !is_numeric($payload['sub']) || empty($payload['role'])) {
                return null;
            }

            $db = Database::getInstance();
            $stmt = $db->prepare("SELECT id, name, email, role, status FROM users WHERE id = ?");
            $stmt->execute([(int)$payload['sub']]);
            $user = $stmt->fetch();

            if (!$user || (isset($user['status']) && $user['status'] === 'banned')) {
                return null;
            }

            $payload['sub']   = (int)$user['id'];
            $payload['role']  = $user['role'];
            $payload['name']  = $user['name'] ?? ($payload['name'] ?? '');
            $payload['email'] = $user['email'] ?? ($payload['email'] ?? '');
            return $payload;
        } catch (Exception $e) {
            return null;
        }
    }

    /**
     * Enforce strict role authorization server-side. Admin role retains administrative access.
     */
    public static function requireRole(string $role): array {
        $user = self::authenticate();
        if ($user['role'] !== $role && $user['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode([
                'success' => false,
                'message' => 'Forbidden: Insufficient role permissions for this resource'
            ]);
            exit();
        }
        return $user;
    }

    /**
     * Enforce strictly Admin role authorization.
     */
    public static function requireAdmin(): array {
        $user = self::authenticate();
        if ($user['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode([
                'success' => false,
                'message' => 'Forbidden: Administrative access required'
            ]);
            exit();
        }
        return $user;
    }

    /**
     * Enforce that user has at least one of the permitted roles (or admin).
     */
    public static function requireAnyRole(array $roles): array {
        $user = self::authenticate();
        if (!in_array($user['role'], $roles, true) && $user['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode([
                'success' => false,
                'message' => 'Forbidden: Insufficient role permissions for this resource'
            ]);
            exit();
        }
        return $user;
    }
}
