import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/missions/domain/day.dart';

/// How many days the parents panel looks back. One week is short enough that a
/// quiet stretch is visible immediately, long enough to survive a busy weekday.
const kParentsWindowDays = 7;

/// One child's activity over the reporting window, as the parents panel tells
/// it: what was scanned for them, what they were asked to play, and what they
/// actually did.
class ChildWeek {
  ChildWeek({
    required this.child,
    required this.scans,
    required this.missionsPlanned,
    required this.missionsCompleted,
    required Set<int> activeDays,
    required this.developmentIndex,
  }) : activeDays = Set.unmodifiable(activeDays);

  final ChildProfile child;

  /// Scans linked to this child inside the window.
  final int scans;

  /// Missions the app generated for this child inside the window.
  final int missionsPlanned;
  final int missionsCompleted;

  /// Day numbers ([epochDay]) on which at least one mission was completed.
  final Set<int> activeDays;

  /// The child's development index (0–100), or 0 when nothing has been scanned
  /// for them yet. Not windowed — it is a lifetime aggregate.
  final int developmentIndex;

  int get activeDayCount => activeDays.length;

  /// Share of the window's missions that were completed, 0–1. A window with no
  /// missions reads as empty rather than complete.
  double get completionRate =>
      missionsPlanned == 0 ? 0 : missionsCompleted / missionsPlanned;

  /// Nothing was scanned and nothing was played — the week a parent most needs
  /// to see.
  bool get isQuiet => scans == 0 && missionsCompleted == 0;

  /// The last [length] days ending on [today], oldest first, as active flags.
  List<bool> dayStrip(DateTime today, {int length = kParentsWindowDays}) {
    final todayNum = epochDay(today);
    return [
      for (var i = length - 1; i >= 0; i--) activeDays.contains(todayNum - i),
    ];
  }
}

/// The whole household's week: one [ChildWeek] per child plus the totals the
/// panel leads with.
class HouseholdReport {
  HouseholdReport({
    required List<ChildWeek> children,
    required this.totalScans,
    this.windowDays = kParentsWindowDays,
  }) : children = List.unmodifiable(children);

  final List<ChildWeek> children;

  /// Every scan in the window, including scans that were never linked to a
  /// child — so the household total can exceed the sum of the per-child counts.
  final int totalScans;

  final int windowDays;

  static final empty = HouseholdReport(children: const [], totalScans: 0);

  int get missionsPlanned =>
      children.fold(0, (sum, c) => sum + c.missionsPlanned);

  int get missionsCompleted =>
      children.fold(0, (sum, c) => sum + c.missionsCompleted);

  /// Days on which *any* child completed a mission. Two children playing on the
  /// same day is one active day for the household.
  int get activeDays =>
      children.expand((c) => c.activeDays).toSet().length;

  /// Nothing at all happened in the window.
  bool get isQuiet => totalScans == 0 && missionsCompleted == 0;

  /// Builds the report from the rows the repository fetched.
  ///
  /// The queries over-fetch by a few hours (a date bound in UTC cannot express
  /// a local calendar day), so the window is applied here, on local calendar
  /// days, rather than trusted from the database.
  factory HouseholdReport.build({
    required List<ChildProfile> children,
    required List<Map<String, dynamic>> scanRows,
    required List<Map<String, dynamic>> missionRows,
    required Map<String, int> developmentIndexes,
    required DateTime today,
    int windowDays = kParentsWindowDays,
  }) {
    final lastDay = epochDay(today);
    final firstDay = lastDay - (windowDays - 1);
    bool inWindow(int day) => day >= firstDay && day <= lastDay;

    var totalScans = 0;
    final scansByChild = <String, int>{};
    for (final row in scanRows) {
      final at = DateTime.tryParse('${row['created_at']}')?.toLocal();
      if (at == null || !inWindow(epochDay(at))) continue;
      totalScans++;
      final childId = row['child_profile_id']?.toString();
      if (childId != null) {
        scansByChild.update(childId, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    final planned = <String, int>{};
    final completed = <String, int>{};
    final active = <String, Set<int>>{};
    for (final row in missionRows) {
      final childId = row['child_profile_id']?.toString();
      if (childId == null) continue;
      final date = DateTime.tryParse('${row['mission_date']}');
      if (date == null) continue;
      final day = epochDay(date);
      if (!inWindow(day)) continue;

      planned.update(childId, (n) => n + 1, ifAbsent: () => 1);
      if (row['status'] == 'completed') {
        completed.update(childId, (n) => n + 1, ifAbsent: () => 1);
        active.putIfAbsent(childId, () => <int>{}).add(day);
      }
    }

    return HouseholdReport(
      windowDays: windowDays,
      totalScans: totalScans,
      children: [
        for (final child in children)
          ChildWeek(
            child: child,
            scans: scansByChild[child.id] ?? 0,
            missionsPlanned: planned[child.id] ?? 0,
            missionsCompleted: completed[child.id] ?? 0,
            activeDays: active[child.id] ?? const <int>{},
            developmentIndex: developmentIndexes[child.id] ?? 0,
          ),
      ],
    );
  }
}
