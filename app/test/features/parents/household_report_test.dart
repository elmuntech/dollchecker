import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/missions/domain/day.dart';
import 'package:dollchecker/features/parents/domain/household_report.dart';

final _today = DateTime(2026, 7, 26);

const _alma = ChildProfile(id: 'c1', name: 'Alma');
const _bek = ChildProfile(id: 'c2', name: 'Bek');

Map<String, dynamic> scan(String? childId, DateTime at) => {
      'child_profile_id': childId,
      'created_at': at.toUtc().toIso8601String(),
    };

Map<String, dynamic> mission(
  String childId,
  DateTime date, {
  String status = 'pending',
}) =>
    {
      'child_profile_id': childId,
      'mission_date': isoDate(date),
      'status': status,
    };

HouseholdReport build({
  List<ChildProfile> children = const [_alma],
  List<Map<String, dynamic>> scans = const [],
  List<Map<String, dynamic>> missions = const [],
  Map<String, int> development = const {},
}) =>
    HouseholdReport.build(
      children: children,
      scanRows: scans,
      missionRows: missions,
      developmentIndexes: development,
      today: _today,
    );

void main() {
  group('window', () {
    test('keeps today and the six days before it', () {
      final report = build(scans: [
        scan('c1', _today),
        scan('c1', _today.subtract(const Duration(days: 6))),
      ]);
      expect(report.totalScans, 2);
      expect(report.children.single.scans, 2);
    });

    test('drops anything older than the window', () {
      final report = build(scans: [
        scan('c1', _today.subtract(const Duration(days: 7))),
        scan('c1', _today.subtract(const Duration(days: 40))),
      ]);
      expect(report.totalScans, 0);
      expect(report.children.single.scans, 0);
    });

    test('honours a custom window length', () {
      final report = HouseholdReport.build(
        children: const [_alma],
        scanRows: [scan('c1', _today.subtract(const Duration(days: 20)))],
        missionRows: const [],
        developmentIndexes: const {},
        today: _today,
        windowDays: 30,
      );
      expect(report.totalScans, 1);
      expect(report.windowDays, 30);
    });
  });

  group('per child', () {
    test('splits scans and missions by child', () {
      final report = build(
        children: const [_alma, _bek],
        scans: [scan('c1', _today), scan('c2', _today), scan('c2', _today)],
        missions: [
          mission('c1', _today, status: 'completed'),
          mission('c1', _today),
          mission('c2', _today, status: 'skipped'),
        ],
      );

      final alma = report.children.first;
      final bek = report.children.last;
      expect(alma.scans, 1);
      expect(alma.missionsPlanned, 2);
      expect(alma.missionsCompleted, 1);
      expect(alma.completionRate, 0.5);
      expect(bek.scans, 2);
      expect(bek.missionsPlanned, 1);
      expect(bek.missionsCompleted, 0);
      expect(bek.completionRate, 0);
    });

    test('keeps the child order it was given, including untouched children',
        () {
      final report = build(children: const [_alma, _bek]);
      expect(report.children.map((c) => c.child.id), ['c1', 'c2']);
      expect(report.children.every((c) => c.isQuiet), isTrue);
    });

    test('a scan not linked to a child counts for the household only', () {
      final report = build(scans: [scan(null, _today)]);
      expect(report.totalScans, 1);
      expect(report.children.single.scans, 0);
    });

    test('carries the development index through', () {
      final report = build(development: const {'c1': 72});
      expect(report.children.single.developmentIndex, 72);
    });

    test('a child with no scores reads as zero, not null', () {
      expect(build().children.single.developmentIndex, 0);
    });
  });

  group('active days', () {
    test('counts distinct days with a completion', () {
      final report = build(missions: [
        mission('c1', _today, status: 'completed'),
        mission('c1', _today, status: 'completed'),
        mission('c1', _today.subtract(const Duration(days: 2)),
            status: 'completed'),
      ]);
      expect(report.children.single.activeDayCount, 2);
      expect(report.activeDays, 2);
    });

    test('pending and skipped missions never make a day active', () {
      final report = build(missions: [
        mission('c1', _today),
        mission('c1', _today, status: 'skipped'),
      ]);
      expect(report.children.single.activeDayCount, 0);
      expect(report.children.single.isQuiet, isTrue);
    });

    test('two children playing on the same day is one household day', () {
      final report = build(
        children: const [_alma, _bek],
        missions: [
          mission('c1', _today, status: 'completed'),
          mission('c2', _today, status: 'completed'),
        ],
      );
      expect(report.activeDays, 1);
      expect(report.missionsCompleted, 2);
    });

    test('the day strip flags the days that were active, oldest first', () {
      final report = build(missions: [
        mission('c1', _today, status: 'completed'),
        mission('c1', _today.subtract(const Duration(days: 6)),
            status: 'completed'),
      ]);
      expect(
        report.children.single.dayStrip(_today),
        [true, false, false, false, false, false, true],
      );
    });
  });

  group('household totals', () {
    test('sum the children', () {
      final report = build(
        children: const [_alma, _bek],
        scans: [scan('c1', _today), scan('c2', _today)],
        missions: [
          mission('c1', _today, status: 'completed'),
          mission('c2', _today),
        ],
      );
      expect(report.totalScans, 2);
      expect(report.missionsPlanned, 2);
      expect(report.missionsCompleted, 1);
      expect(report.isQuiet, isFalse);
    });

    test('a week with nothing in it is quiet', () {
      expect(build().isQuiet, isTrue);
      expect(HouseholdReport.empty.isQuiet, isTrue);
      expect(HouseholdReport.empty.children, isEmpty);
    });

    test('scanning without playing is not a quiet week', () {
      expect(build(scans: [scan('c1', _today)]).isQuiet, isFalse);
    });
  });

  group('malformed rows', () {
    test('are skipped rather than crashing the panel', () {
      final report = build(
        scans: [
          {'child_profile_id': 'c1', 'created_at': 'not-a-date'},
          scan('c1', _today),
        ],
        missions: [
          {'child_profile_id': 'c1', 'mission_date': null, 'status': 'completed'},
          {'child_profile_id': null, 'mission_date': isoDate(_today)},
          mission('c1', _today, status: 'completed'),
        ],
      );
      expect(report.totalScans, 1);
      expect(report.missionsPlanned, 1);
      expect(report.missionsCompleted, 1);
    });
  });
}
