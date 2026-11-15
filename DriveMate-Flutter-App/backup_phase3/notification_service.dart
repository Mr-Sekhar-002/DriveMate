import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

typedef NotificationTapCallback = void Function(String? payload);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const String channelId = 'drivemate_booking_channel';
  static const String channelName = 'DriveMate Booking Alerts';
  static const String channelDesc = 'High priority alerts for incoming customer ride and chauffeur bookings';

  NotificationTapCallback? onNotificationTap;
  final Map<String, int> _recentAlertTimestamps = {};
  bool _isInitialized = false;

  Future<void> initialize({NotificationTapCallback? onSelectNotification}) async {
    if (_isInitialized) return;
    onNotificationTap = onSelectNotification;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && onNotificationTap != null) {
          onNotificationTap!(response.payload);
        }
      },
    );

    // Create High-Priority Notification Channel for Android
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await androidPlugin.createNotificationChannel(channel);

      // Request notification permissions for Android 13+ (TIRAMISU)
      try {
        await androidPlugin.requestNotificationsPermission();
      } catch (e) {
        debugPrint('[NotificationService] Permission request notice: $e');
      }
    }

    _isInitialized = true;
    debugPrint('[NotificationService] DriveMate notification channel initialized.');
  }

  /// Displays high-priority booking notification with sound, vibration, and lock screen visibility
  Future<void> showBookingNotification({
    required String bookingId,
    required String customerName,
    required String pickup,
    required String destination,
    required double fare,
  }) async {
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

  /// Registers driver device token with the PHP backend MySQL database
  Future<bool> registerDeviceTokenWithBackend({
    required int driverId,
    String? fcmToken,
    String? deviceModel,
  }) async {
    final token = fcmToken ?? 'fcm_${driverId}_dev_${DateTime.now().millisecondsSinceEpoch}';
    final model = deviceModel ?? 'Android Smartphone';

    try {
      final response = await http.post(
        Uri.parse('http://localhost/drivemate-api/public/index.php/api/notifications/save-token'),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Role': 'driver',
          'X-User-Id': driverId.toString(),
        },
        body: jsonEncode({
          'fcm_token': token,
          'device_model': model,
          'device_os': 'Android',
          'app_version': '1.0.0',
          'user_role': 'driver',
          'user_id': driverId,
        }),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        debugPrint('[NotificationService] Driver device token registered in backend successfully.');
        return true;
      }
    } catch (e) {
      debugPrint('[NotificationService] Backend token sync notice: $e');
    }
    return false;
  }
}
