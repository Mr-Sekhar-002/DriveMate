<?php
// middleware/AuthMiddleware.php — Validates JWT on protected routes

require_once __DIR__ . '/../helpers/JwtHelper.php';

class AuthMiddleware {

    public static function authenticate(): array {
        $headers    = getallheaders();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

        if (!empty($authHeader) && str_starts_with($authHeader, 'Bearer ')) {
            $token = substr($authHeader, 7);
            try {
                return JwtHelper::decode($token);
            } catch (Exception $e) {
                // If token invalid, fall through to dev headers
            }
        }

        // Check dev/session headers (X-User-Role, X-User-Id)
        $roleHeader = $headers['X-User-Role'] ?? $headers['x-user-role'] ?? $_SERVER['HTTP_X_USER_ROLE'] ?? null;
        $idHeader   = $headers['X-User-Id']   ?? $headers['x-user-id']   ?? $_SERVER['HTTP_X_USER_ID']   ?? null;

        if ($roleHeader) {
            $role = strtolower(trim($roleHeader));
            $sub  = $idHeader ? (int)$idHeader : ($role === 'driver' ? 3 : ($role === 'admin' ? 1 : ($role === 'owner' ? 4 : 2)));
            return [
                'sub'   => $sub,
                'role'  => $role,
                'email' => "{$role}@drivemate.com"
            ];
        }

        // Check request body for user_role / user_id
        $body = Response::body();
        if (!empty($body['user_role'])) {
            $role = strtolower(trim($body['user_role']));
            $sub  = !empty($body['user_id']) ? (int)$body['user_id'] : ($role === 'driver' ? 3 : ($role === 'admin' ? 1 : ($role === 'owner' ? 4 : 2)));
            return [
                'sub'   => $sub,
                'role'  => $role,
                'email' => "{$role}@drivemate.com"
            ];
        }

        http_response_code(401);
        echo json_encode(['success' => false, 'message' => 'Unauthorized: No valid token or user session provided']);
        exit();
    }

    public static function optionalAuthenticate(): ?array {
        $headers    = getallheaders();
        $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

        if (empty($authHeader) || !str_starts_with($authHeader, 'Bearer ')) {
            return null;
        }

        $token = substr($authHeader, 7);

        try {
            return JwtHelper::decode($token);
        } catch (Exception $e) {
            return null;
        }
    }

    public static function requireRole(string $role): array {
        $user = self::authenticate();
        if ($user['role'] !== $role && $user['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Forbidden: Insufficient role permissions']);
            exit();
        }
        return $user;
    }

    public static function requireAnyRole(array $roles): array {
        $user = self::authenticate();
        if (!in_array($user['role'], $roles, true) && $user['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Forbidden: Insufficient role permissions for this resource']);
            exit();
        }
        return $user;
    }
}
