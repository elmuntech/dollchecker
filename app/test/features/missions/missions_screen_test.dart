import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/missions/data/mission_repository.dart';
import 'package:dollchecker/features/missions/domain/mission.dart';
import 'package:dollchecker/features/missions/domain/mission_stats.dart';
import 'package:dollchecker/features/missions/presentation/missions_screen.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';

import '../../helpers.dart';

final _today = DateTime(2026, 7, 26);

Mission mission(
  String id, {
  int slot = 0,
  String status = 'pending',
  String title = 'Rainbow tower',
}) =>
    Mission.fromRow({
      'id': id,
      'child_profile_id': 'c1',
      'mission_date': '2026-07-26',
      'slot': slot,
      'title': title,
      'description': 'Stack the rings.',
      'skill': 'fine_motor',
      'duration_minutes': 10,
      'status': status,
      'toy_id': 'toy-1',
    });

Toy toy(String name, {String? lastPlayed}) => Toy.fromRow({
      'id': 'toy-$name',
      'name': name,
      'owned': true,
      'scan_count': 1,
      'last_played_at': lastPlayed,
    });

void main() {
  Future<void> pumpMissions(
    WidgetTester tester, {
    List<Mission> missions = const [],
    MissionStats? stats,
    List<Toy> rotation = const [],
    Locale locale = const Locale('en'),
  }) {
    return pumpApp(
      tester,
      const MissionsScreen(),
      locale: locale,
      surfaceSize: const Size(1000, 2400),
      overrides: [
        todayProvider.overrideWithValue(_today),
        childrenProvider.overrideWith(
            (ref) async => [const ChildProfile(id: 'c1', name: 'Alma')]),
        todaysMissionsProvider.overrideWith((ref) async => missions),
        missionStatsProvider
            .overrideWith((ref) async => stats ?? MissionStats.empty),
        rotationSuggestionsProvider.overrideWith((ref) async => rotation),
        signedImageProvider.overrideWith((ref, arg) async => null),
      ],
    );
  }

  testWidgets('with no play ideas it explains what to do first',
      (tester) async {
    await pumpMissions(tester);
    expect(find.textContaining('Scan a toy first'), findsOneWidget);
  });

  testWidgets('renders a card per mission with its metadata', (tester) async {
    await pumpMissions(tester, missions: [
      mission('m1', slot: 0, title: 'Rainbow tower'),
      mission('m2', slot: 1, title: 'Sort by color'),
    ]);
    expect(find.text('Rainbow tower'), findsOneWidget);
    expect(find.text('Sort by color'), findsOneWidget);
    expect(find.text('10 min'), findsNWidgets(2));
    expect(find.text('Fine motor'), findsNWidgets(2));
  });

  testWidgets('an open mission offers Done and Skip', (tester) async {
    await pumpMissions(tester, missions: [mission('m1')]);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('a settled mission offers Undo instead', (tester) async {
    await pumpMissions(
      tester,
      missions: [mission('m1', status: 'completed')],
    );
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('a skipped mission is marked as such', (tester) async {
    await pumpMissions(tester, missions: [mission('m1', status: 'skipped')]);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('shows progress across the day', (tester) async {
    await pumpMissions(tester, missions: [
      mission('m1', slot: 0, status: 'completed'),
      mission('m2', slot: 1),
      mission('m3', slot: 2),
    ]);
    expect(find.text('1 of 3 done'), findsOneWidget);
  });

  testWidgets('congratulates a fully completed day', (tester) async {
    await pumpMissions(tester, missions: [
      mission('m1', slot: 0, status: 'completed'),
      mission('m2', slot: 1, status: 'completed'),
    ]);
    expect(find.textContaining('All done for today'), findsOneWidget);
  });

  group('streak card', () {
    testWidgets('shows a live streak with best and total', (tester) async {
      final stats = MissionStats.fromCompletedDates(
        [_today, _today.subtract(const Duration(days: 1))],
        today: _today,
      );
      await pumpMissions(tester, stats: stats, missions: [mission('m1')]);
      expect(find.text('2 days in a row'), findsOneWidget);
      expect(find.textContaining('Best: 2'), findsOneWidget);
      expect(find.textContaining('2 missions completed'), findsOneWidget);
    });

    testWidgets('shows the seven-day strip', (tester) async {
      await pumpMissions(tester, missions: [mission('m1')]);
      expect(find.text('Last 7 days'), findsOneWidget);
    });

    testWidgets('reads sensibly with no streak yet', (tester) async {
      await pumpMissions(tester, missions: [mission('m1')]);
      expect(find.text('No streak yet'), findsOneWidget);
    });
  });

  group('badges', () {
    testWidgets('are hidden until the first completion', (tester) async {
      await pumpMissions(tester, missions: [mission('m1')]);
      expect(find.text('Milestones'), findsNothing);
    });

    testWidgets('appear once earned', (tester) async {
      final stats = MissionStats.fromCompletedDates(
        [_today, _today.subtract(const Duration(days: 1)),
         _today.subtract(const Duration(days: 2))],
        today: _today,
      );
      await pumpMissions(tester, stats: stats, missions: [mission('m1')]);
      expect(find.text('Milestones'), findsOneWidget);
      expect(find.text('First mission'), findsOneWidget);
      expect(find.text('3-day streak'), findsOneWidget);
    });
  });

  group('toy rotation', () {
    testWidgets('is hidden when there is nothing to rotate', (tester) async {
      await pumpMissions(tester, missions: [mission('m1')]);
      expect(find.textContaining('bring these back'), findsNothing);
    });

    testWidgets('lists neglected toys, flagging never-played ones',
        (tester) async {
      await pumpMissions(
        tester,
        missions: [mission('m1')],
        rotation: [toy('Blocks'), toy('Rattle', lastPlayed: '2026-06-01')],
      );
      expect(find.textContaining('bring these back'), findsOneWidget);
      expect(find.text('Blocks'), findsOneWidget);
      expect(find.text('Not played yet'), findsOneWidget);
      expect(find.textContaining('Last played'), findsOneWidget);
    });
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpMissions(
      tester,
      missions: [mission('m1')],
      locale: const Locale('ru'),
    );
    expect(find.text('Ежедневные миссии'), findsOneWidget);
    expect(find.text('Миссии на сегодня'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
  });
}
