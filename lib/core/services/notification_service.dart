import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // ask separately
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(iOS: ios),
    );
    _initialized = true;
    debugPrint('✅ Notifications initialized');
  }

  static Future<bool> requestPermission() async {
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return result ?? false;
  }

  // ── Daily focus reminder ─────────────────────────────────
  // Fires every day at the user's preferred time
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String name,
  }) async {
    await _plugin.cancelAll(); // clear old schedules

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      1,
      'Time to focus, $name 🌿',
      'Your streak is waiting. Start a session now.',
      scheduled,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    debugPrint('✅ Daily reminder set for $hour:$minute');
  }

  // ── Streak at risk — fires at 8pm if no session today ────
  static Future<void> scheduleStreakRisk({required String name}) async {
    final now = tz.TZDateTime.now(tz.local);
    var fireAt = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
    if (fireAt.isBefore(now)) {
      fireAt = fireAt.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      2,
      "Don't break the chain 🔥",
      'Focus for even 10 minutes to keep your streak alive.',
      fireAt,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ── Cancel all ───────────────────────────────────────────
  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Cancel streak risk (call when session completes) ─────
  static Future<void> cancelStreakRisk() => _plugin.cancel(2);
}
