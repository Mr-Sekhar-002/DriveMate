// lib/config/api_config.dart — Centralized API Base URL & Network Configuration
import 'package:shared_preferences/shared_preferences.dart';

enum ApiEnvironment {
  render,     // Live Render Cloud Server (https://your-app.onrender.com/api)
  lan,        // Real Android phone on same Wi-Fi / LAN testing with XAMPP
  emulator,   // Android Emulator (10.0.2.2)
  local,      // Windows desktop / Web / Unit test runner (localhost)
  production, // Live production server
}

class ApiConfig {
  static const String _prefKeyBaseUrl = 'drivemate_custom_base_url';
  static const String _prefKeyEnv = 'drivemate_api_environment';

  /// Actual physical host IPv4 address from Windows ipconfig
  static const String lanHostIp = '192.168.0.107';

  /// Standard Apache HTTP port
  static const int apachePort = 80;

  /// API route prefix on XAMPP server
  static const String apiPrefix = '/drivemate-api/public/index.php/api';

  /// Default Render cloud URL template for DriveMate
  static const String defaultRenderUrl = 'https://drivemate-vrr6.onrender.com/api';

  /// Active environment setting (Defaults to live Render Cloud backend)
  static ApiEnvironment activeEnvironment = ApiEnvironment.render;

  /// Optional custom override (can be set dynamically in settings or debugging)
  static String? customBaseUrlOverride;

  /// Live production API URL (placeholder for cloud deployment)
  static const String productionBaseUrl = 'https://api.drivemate.in/api';

  /// Loads persisted base URL configuration from SharedPreferences
  static Future<void> loadSavedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefKeyBaseUrl);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        customBaseUrlOverride = savedUrl.trim();
      }
      final savedEnv = prefs.getString(_prefKeyEnv);
      if (savedEnv != null) {
        for (final env in ApiEnvironment.values) {
          if (env.name == savedEnv) {
            activeEnvironment = env;
            break;
          }
        }
      }
    } catch (_) {}
  }

  /// Sets and saves custom base URL override into SharedPreferences
  static Future<void> setCustomBaseUrl(String? url, {ApiEnvironment? env}) async {
    final clean = (url != null && url.trim().isNotEmpty)
        ? url.trim().replaceAll(RegExp(r'/+$'), '')
        : null;
    customBaseUrlOverride = clean;
    if (env != null) activeEnvironment = env;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (clean != null) {
        await prefs.setString(_prefKeyBaseUrl, clean);
      } else {
        await prefs.remove(_prefKeyBaseUrl);
      }
      await prefs.setString(_prefKeyEnv, activeEnvironment.name);
    } catch (_) {}
  }

  /// Returns the single centralized API base URL
  static String get baseUrl {
    if (customBaseUrlOverride != null && customBaseUrlOverride!.trim().isNotEmpty) {
      return customBaseUrlOverride!.trim().replaceAll(RegExp(r'/+$'), '');
    }

    switch (activeEnvironment) {
      case ApiEnvironment.render:
        return defaultRenderUrl;

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
      if (customBaseUrlOverride != null && customBaseUrlOverride!.isNotEmpty)
        customBaseUrlOverride!,
      defaultRenderUrl,
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
