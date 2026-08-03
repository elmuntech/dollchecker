import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/reminders/domain/reminder_schedule.dart';

const _six = ReminderSchedule(enabled: true, hour: 18, minute: 0);

void main() {
  group('nextOccurrence', () {
    test('is today when the time is still ahead', () {
      expect(
        _six.nextOccurrence(DateTime(2026, 8, 3, 9, 30)),
        DateTime(2026, 8, 3, 18, 0),
      );
    });

    test('is tomorrow once the time has passed', () {
      expect(
        _six.nextOccurrence(DateTime(2026, 8, 3, 18, 30)),
        DateTime(2026, 8, 4, 18, 0),
      );
    });

    test('is tomorrow at the exact minute, not a second ago', () {
      // Scheduling "now" would fire immediately and then never again today.
      expect(
        _six.nextOccurrence(DateTime(2026, 8, 3, 18, 0)),
        DateTime(2026, 8, 4, 18, 0),
      );
    });

    test('rolls over a month boundary', () {
      expect(
        _six.nextOccurrence(DateTime(2026, 8, 31, 20, 0)),
        DateTime(2026, 9, 1, 18, 0),
      );
    });

    test('rolls over a year boundary', () {
      expect(
        _six.nextOccurrence(DateTime(2026, 12, 31, 23, 59)),
        DateTime(2027, 1, 1, 18, 0),
      );
    });
  });

  group('label', () {
    test('is zero-padded', () {
      expect(const ReminderSchedule(enabled: true, hour: 9, minute: 5).label,
          '09:05');
      expect(_six.label, '18:00');
    });
  });

  group('encode / decode', () {
    test('round-trips', () {
      const schedule = ReminderSchedule(enabled: true, hour: 7, minute: 45);
      expect(ReminderSchedule.decode(schedule.encode()), schedule);
    });

    test('round-trips a disabled reminder', () {
      const schedule = ReminderSchedule(enabled: false, hour: 21, minute: 30);
      expect(ReminderSchedule.decode(schedule.encode()), schedule);
    });

    test('an absent value is the default', () {
      expect(ReminderSchedule.decode(null), ReminderSchedule.defaultSchedule);
    });

    test('the default is off — nobody opted in yet', () {
      expect(ReminderSchedule.defaultSchedule.enabled, isFalse);
    });

    test('junk falls back to the default rather than throwing', () {
      // A corrupted preference must not stop the app from starting.
      for (final raw in ['', 'x', '1|', '1|25|0', '1|18|60', '1|a|b', '1|-1|0']) {
        expect(
          ReminderSchedule.decode(raw),
          ReminderSchedule.defaultSchedule,
          reason: raw,
        );
      }
    });
  });

  test('copyWith changes one field at a time', () {
    expect(_six.copyWith(enabled: false).hour, 18);
    expect(_six.copyWith(hour: 7).enabled, isTrue);
    expect(_six.copyWith(minute: 15).label, '18:15');
  });
}
