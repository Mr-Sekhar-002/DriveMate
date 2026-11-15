import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

typedef NotificationTapCallback = void Function(String? payload);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String channelId = 'drivemate_booking_channel';
  static const String channelName = 'DriveMate Booking Alerts';
  static const String channelDesc = 'High priority alerts for incoming customer ride and chauffeur bookings';

  static const String tripChannelId = 'drivemate_trip_channel';
  static const String tripChannelName = 'DriveMate Trip Lifecycle';
  static const String tripChannelDesc = 'Status updates for driver arrival, trip progress and journey completion';

  NotificationTapCallback? onNotificationTap;
  final Map<String, int> _recentAlertTimestamps = {};
  bool _isInitialized = false;

  Future<void> initialize({NotificationTapCallback? onSelectNotification}) async {
    if (_isInitialized) return;
    onNotificationTap = onSelectNotification;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && onNotificationTap != null) {
            onNotificationTap!(response.payload);
          }
        },
      );

      // Create Android Notification Channels
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // High-Priority Booking Alert Channel
        const bookingChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        // Trip Lifecycle Channel (Arrival, Start, Completed)
        const tripChannel = AndroidNotificationChannel(
          tripChannelId,
          tripChannelName,
          description: tripChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await androidPlugin.createNotificationChannel(bookingChannel);
        await androidPlugin.createNotificationChannel(tripChannel);

        // Request notification permissions for Android 13+ (TIRAMISU)
        try {
          await androidPlugin.requestNotificationsPermission();
        } catch (e) {
          debugPrint('[NotificationService] Permission request notice: $e');
        }
      }

      _isInitialized = true;
      debugPrint('[NotificationService] DriveMate notification channels initialized.');
    } catch (e) {
      debugPrint('[NotificationService] Initialization deferred or headless test environment: $e');
    }
  }

  /// Displays high-priority booking notification with sound, vibration, and lock screen visibility
  Future<void> showBookingNotification({
    required String bookingId,
    required String customerName,
    required String pickup,
    required String destination,
    required double fare,
  }) async {
    if (!_isInitialized) {
      debugPrint('[NotificationService] Notification not displayed: plugin uninitialized or headless test environment.');
      return;
    }

    // 1. Prevent duplicate sound/alerts for the same booking within 15 seconds
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _recentAlertTimestamps[bookingId];
    if (lastTime != null && (now - lastTime) < 15000) {
      debugPrint('[NotificationService] Skipped duplicate alert for booking #$bookingId');
      return;
    }
    _recentAlertTimestamps[bookingId] = now;

    // 2. Play system alert sound & haptic feedback for foreground alert
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.vibrate();
    } catch (_) {}

    // 3. Prepare Notification Content & Android Channel Details
    const title = 'New Booking Request!';
    const body = 'A customer has requested a car booking. Tap to view details.';

    final bigTextStyle = BigTextStyleInformation(
      'Customer: $customerName • Fare: ₹${fare.toInt()}\nPickup: $pickup\nDestination: $destination',
      htmlFormatBigText: false,
      contentTitle: title,
      summaryText: 'DriveMate Immediate Ride Dispatch',
    );

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      styleInformation: bigTextStyle,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    final payload = jsonEncode({
      'type': 'booking_request',
      'booking_id': bookingId,
      'customer_name': customerName,
      'fare': fare,
    });

    final id = int.tryParse(bookingId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 101;

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error displaying native notification: $e');
    }
  }

  /// Displays trip lifecycle notification (Driver Arrived, Trip Started, Trip Completed)
  Future<void> showTripNotification({
    required String bookingId,
    required String title,
    required String message,
    String eventType = 'trip_event',
  }) async {
    if (!_isInitialized) {
      debugPrint('[NotificationService] Trip notification deferred: plugin uninitialized or headless test environment.');
      return;
    }

    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        tripChannelId,
        tripChannelName,
        channelDescription: tripChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
      ),
    );
    final payload = jsonEncode({
      'type': eventType,
      'booking_id': bookingId,
    });

    final id = (int.tryParse(bookingId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 201) + 1000;

    try {
      await _notificationsPlugin.show(
        id,
        title,
        message,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error displaying trip notification: $e');
    }
  }

  /// Registers user device token with the PHP backend MySQL database
  Future<bool> registerDeviceTokenWithBackend({
    required int driverId,
    String? fcmToken,
    String? deviceModel,
    String? authToken,
  }) async {
    final token = fcmToken ?? 'fcm_${driverId}_dev_${DateTime.now().millisecondsSinceEpoch}';
    final model = deviceModel ?? 'Android Smartphone';

    try {
      final uri = ApiConfig.getUri('/notifications/save-token');
      final response = await http.post(
        uri,
        headers: ApiConfig.getHeaders(token: authToken),
        body: jsonEncode({
          'fcm_token': token,
          'device_model': model,
          'device_os': 'Android',
          'app_version': '1.0.0',
        }),
      ).timeout(ApiConfig.requestTimeout);

      if (ApiConfig.isSuccessStatus(response.statusCode)) {
        debugPrint('[NotificationService] Device token registered in backend successfully.');
        return true;
      }
    } catch (e) {
      debugPrint('[NotificationService] Backend token sync notice: $e');
    }
    return false;
  }

  /// Deactivates device token on logout
  Future<bool> removeDeviceToken({
    required String authToken,
    String? fcmToken,
  }) async {
    try {
      final uri = ApiConfig.getUri('/notifications/remove-token');
      final response = await http.post(
        uri,
        headers: ApiConfig.getHeaders(token: authToken),
        body: jsonEncode({
          if (fcmToken != null) 'fcm_token': fcmToken,
        }),
      ).timeout(ApiConfig.requestTimeout);

      return ApiConfig.isSuccessStatus(response.statusCode);
    } catch (e) {
      debugPrint('[NotificationService] Remove token notice: $e');
    }
    return false;
  }

  /// Fetches in-app notification records for the authenticated user from MySQL
  Future<List<Map<String, dynamic>>> fetchMyNotifications({required String authToken}) async {
    try {
      final uri = ApiConfig.getUri('/notifications/my');
      final response = await http.get(
        uri,
        headers: ApiConfig.getHeaders(token: authToken),
      ).timeout(ApiConfig.requestTimeout);

      if (ApiConfig.isSuccessStatus(response.statusCode)) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] is List) {
          return List<Map<String, dynamic>>.from(json['data']);
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] fetchMyNotifications error: $e');
    }
    return [];
  }

  /// Marks notification as read in MySQL backend
  Future<bool> markNotificationAsRead({
    required String authToken,
    int? notificationId,
  }) async {
    try {
      final uri = ApiConfig.getUri('/notifications/mark-read');
      final response = await http.put(
        uri,
        headers: ApiConfig.getHeaders(token: authToken),
        body: jsonEncode({
          if (notificationId != null) 'notification_id': notificationId,
        }),
      ).timeout(ApiConfig.requestTimeout);

      return ApiConfig.isSuccessStatus(response.statusCode);
    } catch (e) {
      debugPrint('[NotificationService] markNotificationAsRead error: $e');
    }
    return false;
  }
}
