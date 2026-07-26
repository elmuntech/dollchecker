import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/domain/skills.dart';
import 'package:dollchecker/features/development/domain/development_summary.dart';

Map<String, dynamic> row(String skill, num avg, int max, int scans) => {
      'skill': skill,
      'avg_score': avg,
      'max_score': max,
      'scan_count': scans,
    };

void main() {
  group('SkillSummary.fromRow', () {
    test('reads the RPC shape', () {
      final s = SkillSummary.fromRow(row('fine_motor', 72.5, 90, 4));
      expect(s.skill, 'fine_motor');
      expect(s.avgScore, 72.5);
      expect(s.maxScore, 90);
      expect(s.scanCount, 4);
    });

    test('tolerates numerics arriving as strings', () {
      // PostgREST serializes `numeric` as a JSON string.
      final s = SkillSummary.fromRow({
        'skill': 'logic',
        'avg_score': '61.5',
        'max_score': '80',
        'scan_count': '3',
      });
      expect(s.avgScore, 61.5);
      expect(s.maxScore, 80);
      expect(s.scanCount, 3);
    });

    test('falls back to zero on missing fields', () {
      final s = SkillSummary.fromRow({'skill': 'memory'});
      expect(s.avgScore, 0);
      expect(s.maxScore, 0);
      expect(s.scanCount, 0);
    });
  });

  group('DevelopmentSummary', () {
    test('is empty with no rows', () {
      final summary = DevelopmentSummary.fromRows(const []);
      expect(summary.isEmpty, isTrue);
      expect(summary.overallIndex, 0);
      expect(summary.scanCount, 0);
      expect(summary.strengths(), isEmpty);
      expect(summary.gaps(), isEmpty);
      expect(summary.uncoveredSkills.length, kSkillKeys.length);
    });

    test('sorts skills best-first', () {
      final summary = DevelopmentSummary.fromRows([
        row('logic', 40, 40, 1),
        row('creativity', 90, 95, 2),
        row('memory', 65, 70, 1),
      ]);
      expect(summary.skills.map((s) => s.skill).toList(),
          ['creativity', 'memory', 'logic']);
    });

    test('overallIndex averages the rated skills', () {
      final summary = DevelopmentSummary.fromRows([
        row('logic', 40, 40, 1),
        row('creativity', 90, 95, 1),
      ]);
      expect(summary.overallIndex, 65);
    });

    test('scanCount is the largest per-skill scan count', () {
      final summary = DevelopmentSummary.fromRows([
        row('logic', 40, 40, 2),
        row('creativity', 90, 95, 7),
      ]);
      expect(summary.scanCount, 7);
    });

    test('strengths and gaps come from opposite ends', () {
      final summary = DevelopmentSummary.fromRows([
        row('logic', 10, 10, 1),
        row('creativity', 90, 90, 1),
        row('memory', 50, 50, 1),
      ]);
      expect(summary.strengths(take: 1).single.skill, 'creativity');
      expect(summary.gaps(take: 1).single.skill, 'logic');
      expect(summary.gaps(take: 2).map((s) => s.skill).toList(),
          ['logic', 'memory']);
    });

    test('take larger than the list does not overflow', () {
      final summary = DevelopmentSummary.fromRows([row('logic', 10, 10, 1)]);
      expect(summary.strengths(take: 5).length, 1);
      expect(summary.gaps(take: 5).length, 1);
    });

    test('uncoveredSkills lists exactly the unrated canonical skills', () {
      final summary = DevelopmentSummary.fromRows([
        row('logic', 10, 10, 1),
        row('creativity', 90, 90, 1),
      ]);
      expect(summary.uncoveredSkills, isNot(contains('logic')));
      expect(summary.uncoveredSkills, isNot(contains('creativity')));
      expect(summary.uncoveredSkills.length, kSkillKeys.length - 2);
    });

    test('drops skills the app does not know about', () {
      // The backend could gain a key before the app ships support for it.
      final summary = DevelopmentSummary.fromRows([
        row('logic', 10, 10, 1),
        row('telekinesis', 99, 99, 1),
      ]);
      expect(summary.skills.map((s) => s.skill), ['logic']);
      expect(summary.overallIndex, 10);
    });

    test('groups always cover all six domains in enum order', () {
      final summary = DevelopmentSummary.fromRows([row('logic', 80, 80, 1)]);
      expect(summary.groups.map((g) => g.group).toList(), SkillGroup.values);
    });

    test('a group averages only its rated members', () {
      // 'cognitive' holds five skills; rate two of them.
      final summary = DevelopmentSummary.fromRows([
        row('logic', 80, 80, 1),
        row('memory', 40, 40, 1),
      ]);
      final cognitive = summary.groups
          .firstWhere((g) => g.group == SkillGroup.cognitive);
      expect(cognitive.avgScore, 60);
      expect(cognitive.coveredSkills, 2);
      expect(cognitive.totalSkills, skillsInGroup(SkillGroup.cognitive).length);
      expect(cognitive.hasData, isTrue);
    });

    test('an unrated group scores zero and reports no data', () {
      final summary = DevelopmentSummary.fromRows([row('logic', 80, 80, 1)]);
      final motor =
          summary.groups.firstWhere((g) => g.group == SkillGroup.motor);
      expect(motor.avgScore, 0);
      expect(motor.coveredSkills, 0);
      expect(motor.hasData, isFalse);
    });
  });
}
