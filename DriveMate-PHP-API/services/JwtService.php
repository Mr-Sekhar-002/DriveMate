<?php
// services/JwtService.php — Enterprise JWT Service with HS256 Signature Verification

require_once __DIR__ . '/../helpers/JwtHelper.php';

class JwtService {

    /**
     * Generate standard JWT token for authenticated user
     */
    public static function generate(array $user): string {
        $expiration = (int)($_ENV['JWT_EXPIRATION'] ?? 86400 * 7); // 7 days default
        $issuedAt   = time();

        $payload = [
            'iss'  => $_ENV['BASE_URL'] ?? 'http://localhost/drivemate-api',
            'sub'  => $user['id'],
            'name' => $user['name'] ?? '',
            'email'=> $user['email'] ?? '',
            'role' => $user['role'] ?? 'customer',
            'iat'  => $issuedAt,
            'exp'  => $issuedAt + $expiration
        ];

        return JwtHelper::encode($payload);
    }

    /**
     * Verify and decode JWT token
     */
    public static function verify(string $token): array {
        return JwtHelper::decode($token);
    }
}
