import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/domain/skills.dart';

void main() {
  group('skill keys', () {
    test('are unique', () {
      expect(kSkillKeys.toSet().length, kSkillKeys.length);
    });

    test('match the twenty canonical keys in the DB enum', () {
      expect(kSkillKeys.length, 20);
    });
  });

  group('skill groups', () {
    test('partition every canonical skill exactly once', () {
      final grouped = <String>[];
      for (final group in SkillGroup.values) {
        grouped.addAll(skillsInGroup(group));
      }
      expect(grouped.length, kSkillKeys.length,
          reason: 'a skill is in two groups, or in none');
      expect(grouped.toSet(), kSkillKeys.toSet());
    });

    test('contain no unknown skills', () {
      for (final group in SkillGroup.values) {
        for (final skill in skillsInGroup(group)) {
          expect(kSkillKeys, contains(skill));
        }
      }
    });

    test('groupOfSkill agrees with skillsInGroup', () {
      for (final group in SkillGroup.values) {
        for (final skill in skillsInGroup(group)) {
          expect(groupOfSkill(skill), group);
        }
      }
    });

    test('groupOfSkill returns null for an unknown key', () {
      expect(groupOfSkill('telekinesis'), isNull);
    });

    test('every group has at least one skill', () {
      for (final group in SkillGroup.values) {
        expect(skillsInGroup(group), isNotEmpty);
      }
    });
  });
}
