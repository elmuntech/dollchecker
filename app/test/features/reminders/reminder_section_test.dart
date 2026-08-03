import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/reminders/data/reminder_repository.dart';
import 'package:dollchecker/features/reminders/data/reminder_scheduler.dart';
import 'package:dollchecker/features/reminders/domain/reminder_schedule.dart';
import 'package:dollchecker/features/settings/presentation/settings_screen.dart';

import '../../helpers.dart';

class RecordingScheduler implements ReminderScheduler {
  RecordingScheduler({this.granted = true});

  final bool granted;
  final List<ReminderSchedule> scheduled = [];

  @override
  Future<bool> ensurePermission() async => granted;

  @override
  Future<void> scheduleDaily({
    required ReminderSchedule schedule,
    required String title,
    required String body,
  }) async {
    scheduled.add(schedule);
  }

  @override
  Future<void> cancelAll() async {}
}

void main() {
  Future<RecordingScheduler> pumpSection(
    WidgetTester tester, {
    ReminderSchedule stored = ReminderSchedule.defaultSchedule,
    bool granted = true,
    Locale locale = const Locale('en'),
  }) async {
    final scheduler = RecordingScheduler(granted: granted);
    await pumpApp(
      tester,
      const Scaffold(body: ReminderSection()),
      locale: locale,
      overrides: [
        reminderSchedulerProvider.overrideWithValue(scheduler),
        reminderStoreProvider.overrideWithValue(InMemoryReminderStore(stored)),
      ],
    );
    return scheduler;
  }

  testWidgets('offers one switch and one time', (tester) async {
    await pumpSection(tester);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
  });

  testWidgets('starts off, showing the stored state', (tester) async {
    await pumpSection(tester);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
  });

  testWidgets('turning it on schedules the reminder', (tester) async {
    final scheduler = await pumpSection(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(scheduler.scheduled.single.enabled, isTrue);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
  });

  testWidgets('a refused permission leaves the switch off', (tester) async {
    final scheduler = await pumpSection(tester, granted: false);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(scheduler.scheduled, isEmpty);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
  });

  testWidgets('the time is only editable once reminders are on',
      (tester) async {
    await pumpSection(tester);
    final timeRow = find.widgetWithText(ListTile, 'Reminder time');
    expect(tester.widget<ListTile>(timeRow).enabled, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(timeRow).enabled, isTrue);
  });

  testWidgets('shows the stored time', (tester) async {
    await pumpSection(
      tester,
      stored: const ReminderSchedule(enabled: true, hour: 7, minute: 5),
    );
    expect(find.text('07:05'), findsOneWidget);
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpSection(tester, locale: const Locale('ru'));
    expect(find.text('Ежедневное напоминание'), findsOneWidget);
    expect(find.text('Время напоминания'), findsOneWidget);
  });
}
