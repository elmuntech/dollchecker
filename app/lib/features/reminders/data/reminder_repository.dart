import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dollchecker/features/reminders/data/reminder_scheduler.dart';
import 'package:dollchecker/features/reminders/domain/reminder_schedule.dart';

/// What the notification says. Passed in from the UI rather than built here, so
/// it is in the language the user reads the app in — and so switching language
/// can re-arm tomorrow's reminder in the new one.
class ReminderCopy {
  const ReminderCopy({required this.title, required this.body});
  final String title;
  final String body;
}

/// Where the reminder setting is kept. Device-local, like the reminder itself.
abstract class ReminderStore {
  Future<ReminderSchedule> read();
  Future<void> write(ReminderSchedule schedule);
}

class PreferencesReminderStore implements ReminderStore {
  const PreferencesReminderStore();

  static const _key = 'reminder_schedule';

  @override
  Future<ReminderSchedule> read() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSchedule.decode(prefs.getString(_key));
  }

  @override
  Future<void> write(ReminderSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, schedule.encode());
  }
}

/// Kept in memory only — used in tests, where there is no platform.
class InMemoryReminderStore implements ReminderStore {
  InMemoryReminderStore([this._schedule = ReminderSchedule.defaultSchedule]);
  ReminderSchedule _schedule;

  @override
  Future<ReminderSchedule> read() async => _schedule;

  @override
  Future<void> write(ReminderSchedule schedule) async => _schedule = schedule;
}

final reminderStoreProvider =
    Provider<ReminderStore>((ref) => const PreferencesReminderStore());

/// The reminder setting, and the only place that keeps the stored value and the
/// scheduled notification in step.
class ReminderController extends AsyncNotifier<ReminderSchedule> {
  @override
  Future<ReminderSchedule> build() => ref.read(reminderStoreProvider).read();

  /// Turning the reminder on asks the platform first. A switch that reads "on"
  /// while the system will never deliver anything promises something it cannot
  /// keep, so a refusal leaves it off.
  Future<void> setEnabled(bool enabled, ReminderCopy copy) async {
    final current = state.valueOrNull ?? ReminderSchedule.defaultSchedule;
    if (enabled) {
      final granted =
          await ref.read(reminderSchedulerProvider).ensurePermission();
      if (!granted) {
        state = AsyncData(current.copyWith(enabled: false));
        return;
      }
    }
    await _apply(current.copyWith(enabled: enabled), copy);
  }

  Future<void> setTime({
    required int hour,
    required int minute,
    required ReminderCopy copy,
  }) async {
    final current = state.valueOrNull ?? ReminderSchedule.defaultSchedule;
    await _apply(current.copyWith(hour: hour, minute: minute), copy);
  }

  /// Re-arms an enabled reminder with fresh copy — after a language change,
  /// so tomorrow's notification is not still in yesterday's language.
  Future<void> reschedule(ReminderCopy copy) async {
    final current = state.valueOrNull;
    if (current == null || !current.enabled) return;
    await _apply(current, copy);
  }

  Future<void> _apply(ReminderSchedule schedule, ReminderCopy copy) async {
    await ref.read(reminderStoreProvider).write(schedule);
    await ref.read(reminderSchedulerProvider).scheduleDaily(
          schedule: schedule,
          title: copy.title,
          body: copy.body,
        );
    state = AsyncData(schedule);
  }
}

final reminderControllerProvider =
    AsyncNotifierProvider<ReminderController, ReminderSchedule>(
  ReminderController.new,
);
