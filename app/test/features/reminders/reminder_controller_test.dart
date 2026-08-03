import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/reminders/data/reminder_repository.dart';
import 'package:dollchecker/features/reminders/data/reminder_scheduler.dart';
import 'package:dollchecker/features/reminders/domain/reminder_schedule.dart';

const _copy = ReminderCopy(title: 'Time to play', body: 'Missions waiting.');

/// Records what the platform was asked to do.
class RecordingScheduler implements ReminderScheduler {
  RecordingScheduler({this.granted = true});

  final bool granted;
  int permissionAsks = 0;
  int cancels = 0;
  final List<({ReminderSchedule schedule, String title})> scheduled = [];

  @override
  Future<bool> ensurePermission() async {
    permissionAsks++;
    return granted;
  }

  @override
  Future<void> scheduleDaily({
    required ReminderSchedule schedule,
    required String title,
    required String body,
  }) async {
    scheduled.add((schedule: schedule, title: title));
  }

  @override
  Future<void> cancelAll() async => cancels++;
}

void main() {
  late RecordingScheduler scheduler;
  late InMemoryReminderStore store;

  ProviderContainer containerWith({
    bool granted = true,
    ReminderSchedule stored = ReminderSchedule.defaultSchedule,
  }) {
    scheduler = RecordingScheduler(granted: granted);
    store = InMemoryReminderStore(stored);
    final container = ProviderContainer(overrides: [
      reminderSchedulerProvider.overrideWithValue(scheduler),
      reminderStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('starts from what was stored', () async {
    const stored = ReminderSchedule(enabled: true, hour: 7, minute: 30);
    final container = containerWith(stored: stored);
    expect(await container.read(reminderControllerProvider.future), stored);
  });

  test('enabling asks permission, then schedules with the given copy',
      () async {
    final container = containerWith();
    await container.read(reminderControllerProvider.future);
    await container
        .read(reminderControllerProvider.notifier)
        .setEnabled(true, _copy);

    expect(scheduler.permissionAsks, 1);
    expect(scheduler.scheduled.single.schedule.enabled, isTrue);
    expect(scheduler.scheduled.single.title, 'Time to play');
    expect(container.read(reminderControllerProvider).value?.enabled, isTrue);
    expect((await store.read()).enabled, isTrue);
  });

  test('a refused permission leaves the switch off and schedules nothing',
      () async {
    // A switch that reads "on" while the system will never deliver is a lie.
    final container = containerWith(granted: false);
    await container.read(reminderControllerProvider.future);
    await container
        .read(reminderControllerProvider.notifier)
        .setEnabled(true, _copy);

    expect(scheduler.permissionAsks, 1);
    expect(scheduler.scheduled, isEmpty);
    expect(container.read(reminderControllerProvider).value?.enabled, isFalse);
  });

  test('disabling does not ask for permission again', () async {
    final container = containerWith(
      stored: const ReminderSchedule(enabled: true, hour: 18, minute: 0),
    );
    await container.read(reminderControllerProvider.future);
    await container
        .read(reminderControllerProvider.notifier)
        .setEnabled(false, _copy);

    expect(scheduler.permissionAsks, 0);
    // A disabled schedule is still handed down: cancelling is the scheduler's
    // job, and it needs to know the reminder is off.
    expect(scheduler.scheduled.single.schedule.enabled, isFalse);
    expect((await store.read()).enabled, isFalse);
  });

  test('changing the time re-schedules and persists it', () async {
    final container = containerWith(
      stored: const ReminderSchedule(enabled: true, hour: 18, minute: 0),
    );
    await container.read(reminderControllerProvider.future);
    await container
        .read(reminderControllerProvider.notifier)
        .setTime(hour: 7, minute: 15, copy: _copy);

    expect(scheduler.scheduled.single.schedule.label, '07:15');
    expect((await store.read()).label, '07:15');
    expect(container.read(reminderControllerProvider).value?.hour, 7);
  });

  test('rescheduling re-arms an enabled reminder with fresh copy', () async {
    final container = containerWith(
      stored: const ReminderSchedule(enabled: true, hour: 18, minute: 0),
    );
    await container.read(reminderControllerProvider.future);
    await container.read(reminderControllerProvider.notifier).reschedule(
          const ReminderCopy(title: 'Пора играть', body: 'Миссии ждут.'),
        );

    expect(scheduler.scheduled.single.title, 'Пора играть');
  });

  test('rescheduling a disabled reminder does nothing', () async {
    final container = containerWith();
    await container.read(reminderControllerProvider.future);
    await container.read(reminderControllerProvider.notifier).reschedule(_copy);

    expect(scheduler.scheduled, isEmpty);
  });
}
