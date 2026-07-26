import 'package:dollchecker/features/missions/domain/day.dart';

/// Milestones worth celebrating. Ordered from easiest to hardest so the UI can
/// show them in a sensible progression.
enum MissionBadge {
  firstMission,
  threeDayStreak,
  weekStreak,
  monthStreak,
  tenMissions,
  fiftyMissions,
}

/// Streak and volume figures, derived from the dates of completed missions.
///
/// Nothing is stored: a streak counted from the missions themselves can never
/// drift out of sync with them.
class MissionStats {
  const MissionStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCompleted,
    required this.completedDays,
  });

  /// Consecutive days up to today (or yesterday, if today is still open) on
  /// which at least one mission was completed.
  final int currentStreak;
  final int longestStreak;

  /// Missions completed in total — several on one day all count.
  final int totalCompleted;

  /// Distinct day numbers with at least one completion.
  final Set<int> completedDays;

  static const empty = MissionStats(
    currentStreak: 0,
    longestStreak: 0,
    totalCompleted: 0,
    completedDays: <int>{},
  );

  /// [dates] holds one entry per completed mission, so days may repeat.
  factory MissionStats.fromCompletedDates(
    Iterable<DateTime> dates, {
    required DateTime today,
  }) {
    final total = dates.length;
    final days = dates.map(epochDay).toSet();
    if (days.isEmpty) return empty;

    final sorted = days.toList()..sort();

    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      run = sorted[i] == sorted[i - 1] + 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }

    // Today not being done yet must not break a live streak, so the count may
    // start from yesterday.
    final todayNum = epochDay(today);
    var cursor = days.contains(todayNum)
        ? todayNum
        : (days.contains(todayNum - 1) ? todayNum - 1 : null);
    var current = 0;
    while (cursor != null && days.contains(cursor)) {
      current++;
      cursor = cursor - 1;
    }

    return MissionStats(
      currentStreak: current,
      longestStreak: longest,
      totalCompleted: total,
      completedDays: days,
    );
  }

  /// Whether a mission was completed on [day].
  bool didComplete(DateTime day) => completedDays.contains(epochDay(day));

  /// The last [length] days ending today, oldest first, as completed flags —
  /// the weekly strip on the missions screen.
  List<bool> recentDays(DateTime today, {int length = 7}) {
    final todayNum = epochDay(today);
    return [
      for (var i = length - 1; i >= 0; i--)
        completedDays.contains(todayNum - i),
    ];
  }

  /// Distinct active days within the last [length] days, including today.
  int activeDaysIn(DateTime today, {int length = 7}) =>
      recentDays(today, length: length).where((done) => done).length;

  List<MissionBadge> get badges => [
        if (totalCompleted >= 1) MissionBadge.firstMission,
        if (longestStreak >= 3) MissionBadge.threeDayStreak,
        if (longestStreak >= 7) MissionBadge.weekStreak,
        if (longestStreak >= 30) MissionBadge.monthStreak,
        if (totalCompleted >= 10) MissionBadge.tenMissions,
        if (totalCompleted >= 50) MissionBadge.fiftyMissions,
      ];
}
