<?php
// helpers/Response.php — Standard JSON response helper

class Response {

    private static ?array $cachedBody = null;

    public static function success($data = [], string $message = 'Success', int $code = 200): void {
        http_response_code($code);
        echo json_encode([
            'success' => true,
            'message' => $message,
            'data'    => $data,
        ]);
        exit();
    }

    public static function error(string $message = 'Error', int $code = 400, $errors = null): void {
        http_response_code($code);
        $response = ['success' => false, 'message' => $message];
        if ($errors !== null) $response['errors'] = $errors;
        echo json_encode($response);
        exit();
    }

    public static function body(): array {
        if (self::$cachedBody !== null) {
            return self::$cachedBody;
        }
        $raw = file_get_contents('php://input');
        self::$cachedBody = json_decode($raw, true) ?? [];
        return self::$cachedBody;
    }
}
