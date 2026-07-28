import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/missions/data/mission_repository.dart';
import 'package:dollchecker/features/missions/domain/day.dart';
import 'package:dollchecker/features/parents/data/parents_repository.dart';
import 'package:dollchecker/features/parents/domain/household_report.dart';
import 'package:dollchecker/features/parents/domain/safety_watch.dart';
import 'package:dollchecker/features/parents/presentation/parents_screen.dart';
import 'package:dollchecker/features/profile/data/profile_repository.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';

import '../../helpers.dart';

final _today = DateTime(2026, 7, 26);

const _alma = ChildProfile(id: 'c1', name: 'Alma');
const _bek = ChildProfile(id: 'c2', name: 'Bek');

ChildWeek week(
  ChildProfile child, {
  int scans = 0,
  int planned = 0,
  int completed = 0,
  Set<int> activeDays = const <int>{},
  int developmentIndex = 0,
}) =>
    ChildWeek(
      child: child,
      scans: scans,
      missionsPlanned: planned,
      missionsCompleted: completed,
      activeDays: activeDays,
      developmentIndex: developmentIndex,
    );

Toy toy(String name, {String safety = 'red'}) => Toy.fromRow({
      'id': 'toy-$name',
      'name': name,
      'owned': true,
      'scan_count': 1,
      'latest_safety': safety,
      'last_scanned_at': '2026-07-25T09:00:00Z',
    });

void main() {
  Future<void> pumpPanel(
    WidgetTester tester, {
    HouseholdReport? report,
    SafetyWatch? watch,
    QuotaStatus quota = const QuotaStatus(tier: 'free', used: 3, resetAt: null),
    List<ChildProfile> children = const [_alma],
    Locale locale = const Locale('en'),
  }) {
    return pumpApp(
      tester,
      const ParentsScreen(),
      locale: locale,
      surfaceSize: const Size(1000, 2400),
      overrides: [
        todayProvider.overrideWithValue(_today),
        childrenProvider.overrideWith((ref) async => children),
        householdReportProvider.overrideWith(
          (ref) async => report ?? HouseholdReport.empty,
        ),
        safetyWatchProvider.overrideWith((ref) async => watch ?? SafetyWatch.empty),
        quotaProvider.overrideWith((ref) async => quota),
        signedImageProvider.overrideWith((ref, arg) async => null),
      ],
    );
  }

  testWidgets('leads with the household week', (tester) async {
    await pumpPanel(
      tester,
      report: HouseholdReport(
        totalScans: 4,
        children: [
          week(
            _alma,
            scans: 4,
            planned: 6,
            completed: 5,
            activeDays: {epochDay(_today)},
          ),
        ],
      ),
    );

    expect(find.text('Parents panel'), findsOneWidget);
    expect(find.text('This week at home'), findsOneWidget);
    expect(find.text('Scans'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Missions'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Active days'), findsOneWidget);
  });

  testWidgets('says so when nothing happened all week', (tester) async {
    await pumpPanel(tester, report: HouseholdReport(children: [week(_alma)], totalScans: 0));
    expect(find.textContaining('No scans and no missions'), findsOneWidget);
  });

  testWidgets('a busy week is not called quiet', (tester) async {
    await pumpPanel(
      tester,
      report: HouseholdReport(totalScans: 1, children: [week(_alma, scans: 1)]),
    );
    expect(find.textContaining('No scans and no missions'), findsNothing);
  });

  group('child cards', () {
    testWidgets('render one per child with their week', (tester) async {
      await pumpPanel(
        tester,
        children: const [_alma, _bek],
        report: HouseholdReport(
          totalScans: 3,
          children: [
            week(_alma, scans: 2, planned: 3, completed: 2, developmentIndex: 71),
            week(_bek, scans: 1),
          ],
        ),
      );

      expect(find.text('Alma'), findsOneWidget);
      expect(find.text('Bek'), findsOneWidget);
      expect(find.text('Scans: 2'), findsOneWidget);
      expect(find.text('2 of 3 done'), findsOneWidget);
      expect(find.textContaining('71'), findsOneWidget);
    });

    testWidgets('a child with no missions this week reads plainly',
        (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.text('No missions this week'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('an unscored child hides the development index', (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.textContaining('Development index'), findsNothing);
    });
  });

  group('safety review', () {
    testWidgets('lists the toys that need another look', (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
        watch: SafetyWatch.from(
            [toy('Magnet set'), toy('Rattle', safety: 'yellow')]),
      );

      expect(find.text('Safety review'), findsOneWidget);
      expect(find.text('2 toys need attention'), findsOneWidget);
      expect(find.text('Magnet set'), findsOneWidget);
      expect(find.text('Rattle'), findsOneWidget);
    });

    testWidgets('an all-green collection says there is nothing to review',
        (tester) async {
      await pumpPanel(
        tester,
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.textContaining('Nothing to review'), findsOneWidget);
      expect(find.textContaining('need attention'), findsNothing);
    });
  });

  group('account', () {
    testWidgets('shows the plan, the quota and the children', (tester) async {
      await pumpPanel(
        tester,
        children: const [_alma, _bek],
        report: HouseholdReport(
          totalScans: 0,
          children: [week(_alma), week(_bek)],
        ),
      );

      expect(find.text('Account'), findsOneWidget);
      expect(find.textContaining('Free'), findsOneWidget);
      expect(find.textContaining('7 free scans left'), findsOneWidget);
      expect(find.text('Alma, Bek'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('a premium plan reads as unlimited', (tester) async {
      await pumpPanel(
        tester,
        quota: const QuotaStatus(tier: 'premium', used: 40, resetAt: null),
        report: HouseholdReport(totalScans: 0, children: [week(_alma)]),
      );
      expect(find.textContaining('Unlimited scans'), findsOneWidget);
    });
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpPanel(
      tester,
      locale: const Locale('ru'),
      report: HouseholdReport(totalScans: 2, children: [week(_alma, scans: 2)]),
      watch: SafetyWatch.from([toy('Magnet set')]),
    );

    expect(find.text('Родительская панель'), findsOneWidget);
    expect(find.text('Эта неделя дома'), findsOneWidget);
    expect(find.text('Проверка безопасности'), findsOneWidget);
    expect(find.text('1 игрушка требует внимания'), findsOneWidget);
  });
}
