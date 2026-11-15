// lib/config/api_config.dart — Centralized API Base URL & Network Configuration

enum ApiEnvironment {
  lan,        // Real Android phone on same Wi-Fi / LAN testing with XAMPP
  emulator,   // Android Emulator (10.0.2.2)
  local,      // Windows desktop / Web / Unit test runner (localhost)
  production, // Live production server
}

class ApiConfig {
  /// Actual physical host IPv4 address from Windows ipconfig
  static const String lanHostIp = '10.22.118.96';

  /// Standard Apache HTTP port
  static const int apachePort = 80;

  /// API route prefix on XAMPP server
  static const String apiPrefix = '/drivemate-api/public/index.php/api';

  /// Active environment setting (Defaults to LAN for genuine Android device testing)
  static ApiEnvironment activeEnvironment = ApiEnvironment.lan;

  /// Optional custom override (can be set dynamically in settings or debugging)
  static String? customBaseUrlOverride;

  /// Live production API URL (placeholder for cloud deployment)
  static const String productionBaseUrl = 'https://api.drivemate.in/api';

  /// Returns the single centralized API base URL
  static String get baseUrl {
    if (customBaseUrlOverride != null && customBaseUrlOverride!.trim().isNotEmpty) {
      return customBaseUrlOverride!.trim().replaceAll(RegExp(r'/+$'), '');
    }

    switch (activeEnvironment) {
      case ApiEnvironment.production:
        return productionBaseUrl;

      case ApiEnvironment.lan:
        return 'http://$lanHostIp:$apachePort$apiPrefix';

      case ApiEnvironment.emulator:
        return 'http://10.0.2.2:$apachePort$apiPrefix';

      case ApiEnvironment.local:
        return 'http://localhost:$apachePort$apiPrefix';
    }
  }

  /// Ordered candidate base URLs for auto-probing connection
  static List<String> get candidateBaseUrls {
    return [
      'http://$lanHostIp:$apachePort$apiPrefix',
      'http://localhost:$apachePort$apiPrefix',
      'http://10.0.2.2:$apachePort$apiPrefix',
    ];
  }

  /// Builds a Uri for the given endpoint path
  static Uri getUri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final base = baseUrl;
    final fullUrl = '$base$cleanEndpoint';
    final uri = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(queryParameters: queryParameters);
    }
    return uri;
  }

  /// Returns standard headers with JWT Bearer token authentication
  static Map<String, String> getHeaders({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  /// Timeout for all backend HTTP requests
  static const Duration requestTimeout = Duration(seconds: 12);

  /// Helper to safely determine if HTTP status indicates success
  static bool isSuccessStatus(int statusCode) => statusCode >= 200 && statusCode < 300;
}
