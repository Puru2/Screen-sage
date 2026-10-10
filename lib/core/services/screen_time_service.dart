import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenTimeService {
  static const _channel = MethodChannel('com.screensage/screentime');

  // ── Authorization ─────────────────────────────────────────────
  static Future<String> getAuthorizationStatus() async {
    if (!_isIOS) return 'approved'; // Android stub
    try {
      final status =
          await _channel.invokeMethod<String>('getAuthorizationStatus');
      debugPrint('📱 Auth status: $status');
      return status ?? 'notDetermined';
    } catch (e) {
      debugPrint('❌ getAuthorizationStatus: $e');
      return 'notDetermined';
    }
  }

  static Future<bool> requestAuthorization() async {
    if (!_isIOS) return true; // Android stub
    try {
      final granted = await _channel.invokeMethod<bool>('requestAuthorization');
      debugPrint('📱 Authorization granted: $granted');
      return granted ?? false;
    } catch (e) {
      debugPrint('❌ requestAuthorization: $e');
      return false;
    }
  }

  // ── App Picker ────────────────────────────────────────────────
  static Future<void> showAppPicker() async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('showAppPicker');
    } catch (e) {
      debugPrint('❌ showAppPicker: $e');
    }
  }

  // Returns list of selected app tokens (for display only)
  static Future<List<String>> getSelectedAppNames() async {
    if (!_isIOS) return [];
    try {
      final apps = await _channel.invokeMethod<List>('getSelectedAppNames');
      return apps?.cast<String>() ?? [];
    } catch (e) {
      debugPrint('❌ getSelectedAppNames: $e');
      return [];
    }
  }

  static Future<int> getSelectedAppCount() async {
    if (!_isIOS) return 0;
    try {
      final count = await _channel.invokeMethod<int>('getSelectedAppCount');
      return count ?? 0;
    } catch (e) {
      debugPrint('❌ getSelectedAppCount: $e');
      return 0;
    }
  }

  // ── Session Control ───────────────────────────────────────────
  static Future<bool> startSession({required int durationMinutes}) async {
    if (!_isIOS) return true; // Android: timer only, no blocking
    try {
      final started = await _channel.invokeMethod<bool>(
        'startSession',
        {'durationMinutes': durationMinutes},
      );
      debugPrint('📱 startSession: $started');
      return started ?? false;
    } catch (e) {
      debugPrint('❌ startSession: $e');
      return false;
    }
  }

  static Future<void> endSession() async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('endSession');
    } catch (e) {
      debugPrint('❌ endSession: $e');
    }
  }

  static Future<void> scheduleFreeSession({required int minutes}) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('scheduleFreeSession', {
        'durationMinutes': minutes,
      });
    } catch (e) {
      debugPrint('❌ scheduleFreeSession: $e');
    }
  }

  static Future<void> reApplyShields() async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('reApplyShields');
    } catch (e) {
      debugPrint('❌ reApplyShields: $e');
    }
  }

  // ── Override Tracking ─────────────────────────────────────────
  static Future<void> resetOverrideCount() async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('resetOverrideCount');
    } catch (e) {
      debugPrint('❌ resetOverrideCount: $e');
    }
  }

  static Future<int> getOverrideCount() async {
    if (!_isIOS) return 0;
    try {
      final count = await _channel.invokeMethod<int>('getOverrideCount');
      return count ?? 0;
    } catch (e) {
      debugPrint('❌ getOverrideCount: $e');
      return 0;
    }
  }

  static Future<void> openSettings() async {
    if (!_isIOS) return;

    try {
      await _channel.invokeMethod('openSettings');
    } catch (e) {
      debugPrint('❌ openSettings: $e');
    }
  }

  // ── Daily Block Windows (scheduled downtime) ─────────────────
  /// Mirrors the user's downtime windows to the iOS App Group and
  /// (re)registers the repeating DeviceActivity schedules natively.
  static Future<void> setBlockWindows(
    List<Map<String, dynamic>> windows,
  ) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('setBlockWindows', {'windows': windows});
      debugPrint('📱 setBlockWindows: ${windows.length} window(s) synced');
    } catch (e) {
      debugPrint('❌ setBlockWindows: $e');
    }
  }

  // ── Deep links (shield CTA → app) ────────────────────────────
  /// Registers a listener for URLs opened natively (e.g. the block-screen
  /// CTA opening `screensage://earned`).
  static void setDeepLinkListener(void Function(String url) listener) {
    if (!_isIOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink' && call.arguments is String) {
        listener(call.arguments as String);
      }
      return null;
    });
  }

  /// Returns a deep link that arrived before Flutter was ready (cold start),
  /// consuming it so it only fires once.
  static Future<String?> getPendingDeepLink() async {
    if (!_isIOS) return null;
    try {
      return await _channel.invokeMethod<String>('getPendingDeepLink');
    } catch (e) {
      debugPrint('❌ getPendingDeepLink: $e');
      return null;
    }
  }

  /// One-shot check for the block-screen CTA handoff: true when the user
  /// recently tapped "Use Earned Minutes" on the shield. Consumes the flag.
  static Future<bool> consumePendingUnlock() async {
    if (!_isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('consumePendingUnlock') ?? false;
    } catch (e) {
      debugPrint('❌ consumePendingUnlock: $e');
      return false;
    }
  }

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
}
