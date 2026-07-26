import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/play/domain/play_idea_entry.dart';

PlayIdeaEntry idea(String id) => PlayIdeaEntry(
      id: id,
      scanId: 'scan-1',
      toyName: 'Blocks',
      title: 'Idea $id',
      description: '',
      skillsTargeted: const [],
      minAgeMonths: null,
      durationMinutes: null,
      difficulty: 'easy',
      isFavorited: false,
    );

void main() {
  group('PlayIdeaEntry.fromRow', () {
    test('reads the joined row shape', () {
      final entry = PlayIdeaEntry.fromRow({
        'id': 'idea-1',
        'scan_id': 'scan-7',
        'title': 'Rainbow tower',
        'description': 'Stack the rings.',
        'skills_targeted': ['fine_motor', 'spatial_reasoning'],
        'min_age_months': 12,
        'duration_minutes': 10,
        'difficulty': 'easy',
        'is_favorited': true,
        'scans': {'identification': {'name': 'Stacking Rings'}},
      });
      expect(entry.id, 'idea-1');
      expect(entry.scanId, 'scan-7');
      expect(entry.toyName, 'Stacking Rings');
      expect(entry.skillsTargeted, ['fine_motor', 'spatial_reasoning']);
      expect(entry.durationMinutes, 10);
      expect(entry.isFavorited, isTrue);
    });

    test('defaults difficulty and favorite state', () {
      final entry = PlayIdeaEntry.fromRow({
        'id': 'idea-2',
        'scan_id': 'scan-7',
        'title': 'Sort by color',
      });
      expect(entry.difficulty, 'medium');
      expect(entry.isFavorited, isFalse);
      expect(entry.skillsTargeted, isEmpty);
      expect(entry.toyName, '');
      expect(entry.minAgeMonths, isNull);
    });
  });

  group('copyWith', () {
    test('flips the favorite flag only', () {
      final original = idea('1');
      final favorited = original.copyWith(isFavorited: true);
      expect(favorited.isFavorited, isTrue);
      expect(favorited.id, original.id);
      expect(favorited.title, original.title);
    });
  });

  group('ideaOfTheDay', () {
    final ideas = [idea('a'), idea('b'), idea('c')];

    test('returns null for an empty list', () {
      expect(ideaOfTheDay(const [], DateTime(2026, 7, 26)), isNull);
    });

    test('is stable within a calendar day', () {
      final morning = ideaOfTheDay(ideas, DateTime(2026, 7, 26, 8));
      final evening = ideaOfTheDay(ideas, DateTime(2026, 7, 26, 22));
      expect(morning!.id, evening!.id);
    });

    test('moves on as the days pass', () {
      final picks = List.generate(
        3,
        (i) => ideaOfTheDay(ideas, DateTime(2026, 7, 26 + i))!.id,
      );
      expect(picks.toSet(), hasLength(3));
    });

    test('always returns a member of the list', () {
      for (var day = 1; day <= 31; day++) {
        final pick = ideaOfTheDay(ideas, DateTime(2026, 1, day));
        expect(ideas.map((i) => i.id), contains(pick!.id));
      }
    });

    test('handles a single idea', () {
      final one = [idea('only')];
      expect(ideaOfTheDay(one, DateTime(2026, 7, 26))!.id, 'only');
    });
  });
}
