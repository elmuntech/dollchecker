import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/missions/domain/mission_stats.dart';

void main() {
  final today = DateTime(2026, 7, 26);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  group('empty', () {
    test('no completions means no streak', () {
      final stats = MissionStats.fromCompletedDates(const [], today: today);
      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 0);
      expect(stats.totalCompleted, 0);
      expect(stats.badges, isEmpty);
    });

    test('the shared empty instance matches a computed empty one', () {
      expect(MissionStats.empty.currentStreak, 0);
      expect(MissionStats.empty.totalCompleted, 0);
      expect(MissionStats.empty.recentDays(today), List.filled(7, false));
    });
  });

  group('current streak', () {
    test('counts consecutive days ending today', () {
      final stats = MissionStats.fromCompletedDates(
        [daysAgo(0), daysAgo(1), daysAgo(2)],
        today: today,
      );
      expect(stats.currentStreak, 3);
    });

    test('stays alive when today is not done yet', () {
      // A streak should not die at midnight — only after a full day is missed.
      final stats = MissionStats.fromCompletedDates(
        [daysAgo(1), daysAgo(2)],
        today: today,
      );
      expect(stats.currentStreak, 2);
    });

    test('is zero once a whole day is missed', () {
      final stats = MissionStats.fromCompletedDates(
        [daysAgo(2), daysAgo(3)],
        today: today,
      );
      expect(stats.currentStreak, 0);
      expect(stats.longestStreak, 2);
    });

    test('several completions on one day still count as one day', () {
      final stats = MissionStats.fromCompletedDates(
        [daysAgo(0), daysAgo(0), daysAgo(0)],
        today: today,
      );
      expect(stats.currentStreak, 1);
      expect(stats.totalCompleted, 3);
    });

    test('ignores the time of day', () {
      final stats = MissionStats.fromCompletedDates(
        [DateTime(2026, 7, 26, 23, 59), DateTime(2026, 7, 25, 0, 1)],
        today: DateTime(2026, 7, 26, 8),
      );
      expect(stats.currentStreak, 2);
    });
  });

  group('longest streak', () {
    test('finds the best run, not the current one', () {
      final stats = MissionStats.fromCompletedDates(
        [
          daysAgo(0),
          daysAgo(10), daysAgo(11), daysAgo(12), daysAgo(13),
        ],
        today: today,
      );
      expect(stats.currentStreak, 1);
      expect(stats.longestStreak, 4);
    });

    test('a single day is a streak of one', () {
      final stats =
          MissionStats.fromCompletedDates([daysAgo(5)], today: today);
      expect(stats.longestStreak, 1);
    });

    test('handles a run spanning a month boundary', () {
      final stats = MissionStats.fromCompletedDates(
        [DateTime(2026, 7, 1), DateTime(2026, 6, 30), DateTime(2026, 6, 29)],
        today: DateTime(2026, 7, 1),
      );
      expect(stats.currentStreak, 3);
      expect(stats.longestStreak, 3);
    });

    test('handles a run spanning a leap day', () {
      final stats = MissionStats.fromCompletedDates(
        [DateTime(2028, 3, 1), DateTime(2028, 2, 29), DateTime(2028, 2, 28)],
        today: DateTime(2028, 3, 1),
      );
      expect(stats.currentStreak, 3);
    });
  });

  group('recentDays', () {
    test('returns seven flags, oldest first, ending today', () {
      final stats = MissionStats.fromCompletedDates(
        [daysAgo(0), daysAgo(6)],
        today: today,
      );
      final week = stats.recentDays(today);
      expect(week, hasLength(7));
      expect(week.first, isTrue, reason: 'six days ago');
      expect(week.last, isTrue, reason: 'today');
      expect(week.sublist(1, 6).any((d) => d), isFalse);
    });

    test('excludes days older than the window', () {
      final stats =
          MissionStats.fromCompletedDates([daysAgo(9)], today: today);
      expect(stats.recentDays(today).any((d) => d), isFalse);
      expect(stats.activeDaysIn(today), 0);
    });

    test('activeDaysIn counts distinct days in the window', () {
      final stats = MissionStats.fromCompletedDates(
        [daysAgo(0), daysAgo(0), daysAgo(3)],
        today: today,
      );
      expect(stats.activeDaysIn(today), 2);
    });

    test('honours a custom window length', () {
      final stats =
          MissionStats.fromCompletedDates([daysAgo(20)], today: today);
      expect(stats.recentDays(today, length: 30), hasLength(30));
      expect(stats.activeDaysIn(today, length: 30), 1);
    });
  });

  group('didComplete', () {
    test('answers per calendar day', () {
      final stats =
          MissionStats.fromCompletedDates([daysAgo(2)], today: today);
      expect(stats.didComplete(daysAgo(2)), isTrue);
      expect(stats.didComplete(daysAgo(1)), isFalse);
    });
  });

  group('badges', () {
    test('the first completion unlocks the first badge only', () {
      final stats =
          MissionStats.fromCompletedDates([daysAgo(0)], today: today);
      expect(stats.badges, [MissionBadge.firstMission]);
    });

    test('a three-day streak unlocks the streak badge', () {
      final stats = MissionStats.fromCompletedDates(
        [daysAgo(0), daysAgo(1), daysAgo(2)],
        today: today,
      );
      expect(stats.badges, contains(MissionBadge.threeDayStreak));
      expect(stats.badges, isNot(contains(MissionBadge.weekStreak)));
    });

    test('volume badges track total completions, not days', () {
      final stats = MissionStats.fromCompletedDates(
        List.filled(10, daysAgo(0)),
        today: today,
      );
      expect(stats.badges, contains(MissionBadge.tenMissions));
      expect(stats.badges, isNot(contains(MissionBadge.threeDayStreak)));
    });

    test('a long history unlocks everything', () {
      final stats = MissionStats.fromCompletedDates(
        [for (var i = 0; i < 50; i++) daysAgo(i)],
        today: today,
      );
      expect(stats.badges, hasLength(MissionBadge.values.length));
    });

    test('badges are listed easiest first', () {
      final stats = MissionStats.fromCompletedDates(
        [for (var i = 0; i < 50; i++) daysAgo(i)],
        today: today,
      );
      final order = stats.badges.map(MissionBadge.values.indexOf).toList();
      expect(order, orderedEquals(order.toList()..sort()));
    });
  });
}
