import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  static String get gcpWebClientID {
    final value =
        "876882658891-03jnu0kffvh8jt1184032o9kf9guh035.apps.googleusercontent.com";
    if (value == null) {
      throw Exception('GCP_WEB_CLIENT_ID not found in .env');
    }
    return value;
  }

  static String get gcpIosClientId {
    final value =
        "876882658891-055lem5d8gt8ta09rirgsdqueagij0a7.apps.googleusercontent.com";
    if (value == null) {
      throw Exception('GCP_IOS_CLIENT_ID not found in .env');
    }
    return value;
  }

  // ── RevenueCat ──────────────────────────────────────────────────
  static String get revenueCatAppleApiKey {
    final value = dotenv.env['REVENUECAT_APPLE_API_KEY'];
    if (value == null) {
      throw Exception('REVENUECAT_APPLE_API_KEY not found in .env');
    }
    return value;
  }

  static String get revenueCatGoogleApiKey {
    final value = dotenv.env['REVENUECAT_GOOGLE_API_KEY'];
    if (value == null) {
      throw Exception('REVENUECAT_GOOGLE_API_KEY not found in .env');
    }
    return value;
  }

  // ── Entitlements (must match RevenueCat dashboard exactly) ──────
  static const entitlementPremium = 'Screen sage premium';

  // ── App Group (must match Xcode capability) ──────────────────────
  static const appGroupId = 'group.com.pratham.screensage.data';

  // ── MethodChannel ───────────────────────────────────────────────
  static const screenTimeChannel = 'com.screensage/screentime';

  // ── Session defaults ─────────────────────────────────────────────
  static const defaultSessionMinutes = 25;
  static const minSessionMinutes = 5;
  static const maxSessionMinutes = 180;
}
