import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneDialerHelper {
  /// Opens genuine Android telephone dialer using the "tel:" URI
  /// and LaunchMode.externalApplication.
  ///
  /// DOES NOT use CALL_PHONE permission and does NOT automatically place a call.
  /// The user manually confirms the call inside the external dialer.
  static Future<bool> makePhoneCall(BuildContext context, String? phone) async {
    final rawPhone = phone?.trim();

    // 1. Missing phone number validation
    if (rawPhone == null || rawPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer phone number not available for this booking.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    // 2. Sanitize number: keep only digits and leading '+'
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final digitsOnly = cleanPhone.replaceAll(RegExp(r'[^0-9]'), '');

    // 3. Minimum length validation for genuine phone numbers (minimum 3 digits for emergency helplines like 112, 108, 1091)
    if (digitsOnly.length < 3) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid phone number: "$rawPhone"'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final Uri telUri = Uri(scheme: 'tel', path: cleanPhone);

    // 4. Launch external dialer with error handling
    try {
      final canLaunch = await canLaunchUrl(telUri);
      if (canLaunch) {
        final launched = await launchUrl(
          telUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open Android phone dialer for $cleanPhone'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return launched;
      } else {
        // Fallback attempt: some Android devices succeed with direct external application launch
        try {
          final launched = await launchUrl(
            telUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (_) {}

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open phone dialer for $cleanPhone. No dialer app found.'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching phone dialer: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }
}
