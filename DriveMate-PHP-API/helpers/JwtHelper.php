<?php
// helpers/JwtHelper.php — Pure PHP JWT (no library needed)

class JwtHelper {

    private static function base64UrlEncode(string $data): string {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private static function base64UrlDecode(string $data): string {
        return base64_decode(strtr($data, '-_', '+/'));
    }

    // Generate a JWT token
    public static function encode(array $payload): string {
        $secret = $_ENV['JWT_SECRET'] ?? 'drivemate_secret';

        $header  = self::base64UrlEncode(json_encode(['typ' => 'JWT', 'alg' => 'HS256']));
        $payload = self::base64UrlEncode(json_encode($payload));
        $sig     = self::base64UrlEncode(
            hash_hmac('sha256', "$header.$payload", $secret, true)
        );

        return "$header.$payload.$sig";
    }

    // Decode & verify a JWT token — returns payload array or throws
    public static function decode(string $token): array {
        $secret = $_ENV['JWT_SECRET'] ?? 'drivemate_secret';
        $parts  = explode('.', $token);

        if (count($parts) !== 3) {
            throw new Exception('Invalid token format');
        }

        [$header, $payload, $sig] = $parts;

        // Verify signature
        $expectedSig = self::base64UrlEncode(
            hash_hmac('sha256', "$header.$payload", $secret, true)
        );
        if (!hash_equals($expectedSig, $sig)) {
            throw new Exception('Invalid token signature');
        }

        // Decode payload
        $data = json_decode(self::base64UrlDecode($payload), true);

        // Check expiry
        if (isset($data['exp']) && $data['exp'] < time()) {
            throw new Exception('Token has expired');
        }

        return $data;
    }
}
