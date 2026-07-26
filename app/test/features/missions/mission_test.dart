import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/missions/domain/day.dart';
import 'package:dollchecker/features/missions/domain/mission.dart';

void main() {
  group('Mission.fromRow', () {
    test('reads a full row', () {
      final mission = Mission.fromRow({
        'id': 'm-1',
        'child_profile_id': 'c-1',
        'mission_date': '2026-07-26',
        'slot': 1,
        'play_idea_id': 'idea-3',
        'toy_id': 'toy-9',
        'title': 'Rainbow tower',
        'description': 'Stack the rings.',
        'skill': 'fine_motor',
        'duration_minutes': 10,
        'status': 'completed',
        'completed_at': '2026-07-26T18:00:00Z',
      });
      expect(mission.id, 'm-1');
      expect(mission.slot, 1);
      expect(mission.skill, 'fine_motor');
      expect(mission.status, MissionStatus.completed);
      expect(mission.isDone, isTrue);
      expect(mission.isOpen, isFalse);
      expect(mission.completedAt, isNotNull);
      expect(isSameDay(mission.date, DateTime(2026, 7, 26)), isTrue);
    });

    test('defaults a sparse row to a pending mission', () {
      final mission = Mission.fromRow({
        'id': 'm-2',
        'mission_date': '2026-07-26',
        'title': 'Sort by color',
      });
      expect(mission.status, MissionStatus.pending);
      expect(mission.isOpen, isTrue);
      expect(mission.slot, 0);
      expect(mission.playIdeaId, isNull);
      expect(mission.toyId, isNull);
      expect(mission.completedAt, isNull);
    });

    test('a deleted idea or toy leaves the mission intact', () {
      // Both FKs are `on delete set null`, so the text has to stand alone.
      final mission = Mission.fromRow({
        'id': 'm-3',
        'mission_date': '2026-07-26',
        'title': 'Build a tunnel',
        'description': 'Use the blocks.',
        'play_idea_id': null,
        'toy_id': null,
      });
      expect(mission.title, 'Build a tunnel');
      expect(mission.description, 'Use the blocks.');
    });
  });

  group('status keys', () {
    test('round-trip through the database values', () {
      for (final status in MissionStatus.values) {
        expect(missionStatusFromKey(missionStatusKey(status)), status);
      }
    });

    test('an unknown key reads as pending', () {
      expect(missionStatusFromKey('exploded'), MissionStatus.pending);
      expect(missionStatusFromKey(null), MissionStatus.pending);
    });
  });

  group('copyWith', () {
    test('changes only the status', () {
      final mission = Mission.fromRow({
        'id': 'm-1',
        'mission_date': '2026-07-26',
        'title': 'Rainbow tower',
        'toy_id': 'toy-9',
      });
      final done = mission.copyWith(status: MissionStatus.completed);
      expect(done.status, MissionStatus.completed);
      expect(done.id, mission.id);
      expect(done.title, mission.title);
      expect(done.toyId, mission.toyId);
    });
  });

  group('day helpers', () {
    test('isoDate zero-pads for Postgres', () {
      expect(isoDate(DateTime(2026, 7, 6)), '2026-07-06');
      expect(isoDate(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('epochDay counts calendar days, not elapsed hours', () {
      final a = DateTime(2026, 7, 26, 23, 59);
      final b = DateTime(2026, 7, 27, 0, 1);
      expect(epochDay(b) - epochDay(a), 1);
    });

    test('dateOnly strips the time', () {
      final d = dateOnly(DateTime(2026, 7, 26, 15, 30));
      expect(d, DateTime(2026, 7, 26));
    });

    test('isSameDay ignores the clock', () {
      expect(
        isSameDay(DateTime(2026, 7, 26, 1), DateTime(2026, 7, 26, 23)),
        isTrue,
      );
      expect(
        isSameDay(DateTime(2026, 7, 26), DateTime(2026, 7, 27)),
        isFalse,
      );
    });
  });
}
