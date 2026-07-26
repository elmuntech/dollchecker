import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/missions/domain/mission_selection.dart';

MissionCandidate candidate(
  String id, {
  List<String> skills = const ['fine_motor'],
  String? toyId,
  int? minAgeMonths,
  DateTime? lastPlayed,
  int? duration = 10,
}) =>
    MissionCandidate(
      playIdeaId: id,
      title: 'Idea $id',
      description: 'Do $id.',
      skills: skills,
      toyId: toyId ?? 'toy-$id',
      toyName: 'Toy $id',
      minAgeMonths: minAgeMonths,
      durationMinutes: duration,
      toyLastPlayedAt: lastPlayed,
    );

void main() {
  final day = DateTime(2026, 7, 26);

  group('edge cases', () {
    test('no candidates yields no missions', () {
      expect(
        selectDailyMissions(
            candidates: const [], skillAverages: const {}, day: day),
        isEmpty,
      );
    });

    test('asking for zero missions yields none', () {
      expect(
        selectDailyMissions(
          candidates: [candidate('a')],
          skillAverages: const {},
          day: day,
          count: 0,
        ),
        isEmpty,
      );
    });

    test('never returns more than asked for', () {
      final picked = selectDailyMissions(
        candidates: [for (var i = 0; i < 20; i++) candidate('$i')],
        skillAverages: const {},
        day: day,
        count: 3,
      );
      expect(picked, hasLength(3));
    });

    test('returns what it has when candidates are scarce', () {
      final picked = selectDailyMissions(
        candidates: [candidate('a')],
        skillAverages: const {},
        day: day,
        count: 3,
      );
      expect(picked, hasLength(1));
    });
  });

  group('stability', () {
    test('the same day yields the same missions', () {
      final candidates = [for (var i = 0; i < 12; i++) candidate('$i')];
      final first = selectDailyMissions(
          candidates: candidates, skillAverages: const {}, day: day);
      final second = selectDailyMissions(
          candidates: candidates, skillAverages: const {}, day: day);
      expect(first.map((c) => c.playIdeaId).toList(),
          second.map((c) => c.playIdeaId).toList());
    });

    test('the time of day does not change the selection', () {
      final candidates = [for (var i = 0; i < 12; i++) candidate('$i')];
      final morning = selectDailyMissions(
        candidates: candidates,
        skillAverages: const {},
        day: DateTime(2026, 7, 26, 7),
      );
      final evening = selectDailyMissions(
        candidates: candidates,
        skillAverages: const {},
        day: DateTime(2026, 7, 26, 21),
      );
      expect(morning.map((c) => c.playIdeaId), evening.map((c) => c.playIdeaId));
    });

    test('different days produce different sets', () {
      final candidates = [for (var i = 0; i < 30; i++) candidate('$i')];
      final sets = [
        for (var i = 0; i < 5; i++)
          selectDailyMissions(
            candidates: candidates,
            skillAverages: const {},
            day: DateTime(2026, 7, 26 + i),
          ).map((c) => c.playIdeaId).join(',')
      ];
      expect(sets.toSet().length, greaterThan(1),
          reason: 'missions must not be identical every morning');
    });
  });

  group('skill gaps', () {
    test('a weak skill outranks a strong one', () {
      final picked = selectDailyMissions(
        candidates: [
          candidate('strong', skills: ['creativity']),
          candidate('weak', skills: ['logic']),
        ],
        skillAverages: const {'creativity': 95, 'logic': 5},
        day: day,
        count: 1,
      );
      expect(picked.single.playIdeaId, 'weak');
    });

    test('an idea is judged by its weakest targeted skill', () {
      final picked = selectDailyMissions(
        candidates: [
          candidate('mixed', skills: ['creativity', 'logic']),
          candidate('solid', skills: ['creativity']),
        ],
        skillAverages: const {'creativity': 95, 'logic': 5},
        day: day,
        count: 1,
      );
      expect(picked.single.playIdeaId, 'mixed');
    });

    test('an unrated skill is worth a nudge but loses to a measured gap', () {
      final scored = scoreCandidates(
        candidates: [
          candidate('unrated', skills: ['memory']),
          candidate('measured', skills: ['logic']),
        ],
        skillAverages: const {'logic': 5},
        day: day,
      );
      final unrated =
          scored.firstWhere((s) => s.candidate.playIdeaId == 'unrated');
      final measured =
          scored.firstWhere((s) => s.candidate.playIdeaId == 'measured');
      expect(unrated.gap, greaterThan(0));
      expect(measured.gap, greaterThan(unrated.gap));
    });

    test('an idea with no skills gets a neutral gap', () {
      final scored = scoreCandidates(
        candidates: [candidate('none', skills: const [])],
        skillAverages: const {},
        day: day,
      );
      expect(scored.single.gap, 0.5);
    });
  });

  group('toy rotation', () {
    test('a long-unplayed toy outranks one played today', () {
      final picked = selectDailyMissions(
        candidates: [
          candidate('fresh', lastPlayed: day),
          candidate('stale', lastPlayed: day.subtract(const Duration(days: 40))),
        ],
        skillAverages: const {'fine_motor': 50},
        day: day,
        count: 1,
      );
      expect(picked.single.playIdeaId, 'stale');
    });

    test('a never-played toy scores full rotation', () {
      final scored = scoreCandidates(
        candidates: [candidate('never', lastPlayed: null)],
        skillAverages: const {},
        day: day,
      );
      expect(scored.single.rotation, 1);
    });

    test('a toy played today scores no rotation', () {
      final scored = scoreCandidates(
        candidates: [candidate('today', lastPlayed: day)],
        skillAverages: const {},
        day: day,
      );
      expect(scored.single.rotation, 0);
    });

    test('rotation saturates rather than growing forever', () {
      final scored = scoreCandidates(
        candidates: [
          candidate('a', lastPlayed: day.subtract(const Duration(days: 30))),
          candidate('b', lastPlayed: day.subtract(const Duration(days: 300))),
        ],
        skillAverages: const {},
        day: day,
      );
      expect(scored.every((s) => s.rotation <= 1), isTrue);
      expect(scored.map((s) => s.rotation).toSet(), {1.0});
    });
  });

  group('toy diversity', () {
    test('one toy cannot fill the whole day', () {
      final picked = selectDailyMissions(
        candidates: [
          candidate('a1', toyId: 'shared'),
          candidate('a2', toyId: 'shared'),
          candidate('a3', toyId: 'shared'),
          candidate('b', toyId: 'other-b'),
          candidate('c', toyId: 'other-c'),
        ],
        skillAverages: const {},
        day: day,
        count: 3,
      );
      expect(picked.map((c) => c.toyId).toSet(), hasLength(3));
    });

    test('repeats a toy rather than returning a short day', () {
      final picked = selectDailyMissions(
        candidates: [
          candidate('a1', toyId: 'only'),
          candidate('a2', toyId: 'only'),
          candidate('a3', toyId: 'only'),
        ],
        skillAverages: const {},
        day: day,
        count: 3,
      );
      expect(picked, hasLength(3));
      expect(picked.map((c) => c.playIdeaId).toSet(), hasLength(3),
          reason: 'the same idea must not appear twice in one day');
    });

    test('never repeats the same play idea', () {
      final picked = selectDailyMissions(
        candidates: [for (var i = 0; i < 10; i++) candidate('$i', toyId: 'one')],
        skillAverages: const {},
        day: day,
        count: 3,
      );
      expect(picked.map((c) => c.playIdeaId).toSet(), hasLength(picked.length));
    });
  });

  group('age fit', () {
    test('an idea above the child\'s age loses to an age-appropriate one', () {
      final picked = selectDailyMissions(
        candidates: [
          // Strong on every other signal, but aimed at a much older child.
          candidate('tooOld',
              minAgeMonths: 60, lastPlayed: null, skills: ['logic']),
          candidate('fits',
              minAgeMonths: 6,
              lastPlayed: day.subtract(const Duration(days: 1))),
        ],
        skillAverages: const {'logic': 0, 'fine_motor': 90},
        day: day,
        childAgeMonths: 18,
        count: 1,
      );
      expect(picked.single.playIdeaId, 'fits');
    });

    test('a too-old idea is still used when nothing else exists', () {
      final picked = selectDailyMissions(
        candidates: [candidate('tooOld', minAgeMonths: 60)],
        skillAverages: const {},
        day: day,
        childAgeMonths: 18,
        count: 3,
      );
      expect(picked, hasLength(1));
    });

    test('an unknown child age never flags a mismatch', () {
      final scored = scoreCandidates(
        candidates: [candidate('a', minAgeMonths: 200)],
        skillAverages: const {},
        day: day,
      );
      expect(scored.single.ageMismatch, isFalse);
    });

    test('an idea with no minimum age never flags a mismatch', () {
      final scored = scoreCandidates(
        candidates: [candidate('a', minAgeMonths: null)],
        skillAverages: const {},
        day: day,
        childAgeMonths: 3,
      );
      expect(scored.single.ageMismatch, isFalse);
    });
  });

  group('scoreCandidates', () {
    test('returns every candidate, best first', () {
      final scored = scoreCandidates(
        candidates: [for (var i = 0; i < 6; i++) candidate('$i')],
        skillAverages: const {},
        day: day,
      );
      expect(scored, hasLength(6));
      for (var i = 1; i < scored.length; i++) {
        expect(scored[i - 1].score, greaterThanOrEqualTo(scored[i].score));
      }
    });

    test('keeps every component inside 0–1', () {
      final scored = scoreCandidates(
        candidates: [
          candidate('a', lastPlayed: day.subtract(const Duration(days: 900))),
          candidate('b', lastPlayed: day.add(const Duration(days: 5))),
        ],
        skillAverages: const {'fine_motor': 120},
        day: day,
      );
      for (final s in scored) {
        expect(s.gap, inInclusiveRange(0, 1));
        expect(s.rotation, inInclusiveRange(0, 1));
        expect(s.jitter, inInclusiveRange(0, 1));
      }
    });

    test('a mismatched age drives the score below any clean candidate', () {
      final scored = scoreCandidates(
        candidates: [
          candidate('old', minAgeMonths: 200),
          candidate('ok', minAgeMonths: 1),
        ],
        skillAverages: const {},
        day: day,
        childAgeMonths: 24,
      );
      expect(scored.last.candidate.playIdeaId, 'old');
      expect(scored.last.score, lessThan(0));
    });
  });
}
