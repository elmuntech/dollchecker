import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:dollchecker/features/reminders/domain/reminder_schedule.dart';

/// What the app needs from the platform's notification service, and nothing
/// more. Behind an interface because the real one cannot run in a test — and
/// because the scheduling rules are worth testing without it.
abstract class ReminderScheduler {
  /// Asks for permission if the platform requires it. Returns false when the
  /// user says no, which is a normal answer, not an error.
  Future<bool> ensurePermission();

  /// Replaces any existing reminder with a daily one at [schedule].
  Future<void> scheduleDaily({
    required ReminderSchedule schedule,
    required String title,
    required String body,
  });

  Future<void> cancelAll();
}

/// Used in tests and on any platform where notifications are unavailable.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<bool> ensurePermission() async => false;

  @override
  Future<void> scheduleDaily({
    required ReminderSchedule schedule,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}

/// The real thing: `flutter_local_notifications`, scheduled on the device.
///
/// Local, not push — no FCM/APNs account, no server, and it keeps working
/// offline. The cost is that a reminder lives on one device; that is the right
/// trade for a nudge, and matches where the setting is stored.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _notificationId = 1001;
  static const _channelId = 'daily_missions';

  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested explicitly, when the user turns reminders
          // on — not on first launch, where it would be a prompt with no
          // context.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> ensurePermission() async {
    await _init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
    } catch (e) {
      debugPrint('notification permission failed: $e');
    }
    return false;
  }

  @override
  Future<void> scheduleDaily({
    required ReminderSchedule schedule,
    required String title,
    required String body,
  }) async {
    await _init();
    await cancelAll();
    if (!schedule.enabled) return;

    final next = tz.TZDateTime.from(
      schedule.nextOccurrence(DateTime.now()),
      tz.local,
    );

    await _plugin.zonedSchedule(
      _notificationId,
      title,
      body,
      next,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Daily missions',
          channelDescription: 'A daily nudge about today\'s play missions',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Same wall-clock time every day, which is what a parent means by "18:00"
      // even across a daylight-saving change.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancel(_notificationId);
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return LocalReminderScheduler(FlutterLocalNotificationsPlugin());
});
