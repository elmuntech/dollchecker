import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

const _fullAnalysis = '''
{
  "identification": {
    "name": "Wooden Stacking Rings",
    "brand": "Melissa & Doug",
    "category": "stacking toy",
    "confidence": 0.82,
    "detected_language": "en"
  },
  "age_recommendation": { "min_months": 12, "max_months": 36, "label": "1–3 years" },
  "materials": ["wood", "non-toxic paint"],
  "safety": {
    "overall": "yellow",
    "score": 74,
    "hazards": [
      {
        "type": "small_parts",
        "severity": "medium",
        "description": "The smallest ring may fit a choke tube.",
        "recommendation": "Supervise children under 3."
      }
    ],
    "summary": "Generally sound, watch the smallest ring.",
    "supervision_level": "constant",
    "cleaning": "Wipe with a damp cloth.",
    "storage": "Keep dry.",
    "disclaimer": "AI guidance only."
  },
  "development": {
    "educational_score": 81,
    "educational_summary": "Strong for early motor and spatial work.",
    "skills": [
      { "skill": "fine_motor", "score": 88, "reason": "Grasping", "how_to_maximize": "Name the colors." },
      { "skill": "spatial_reasoning", "score": 74, "reason": "Ordering", "how_to_maximize": "Ask which is bigger." }
    ]
  },
  "play_coach": {
    "ideas": [
      {
        "title": "Rainbow tower",
        "description": "Stack from largest to smallest.",
        "skills_targeted": ["fine_motor", "spatial_reasoning"],
        "min_age_months": 12,
        "duration_minutes": 10,
        "difficulty": "easy"
      }
    ]
  }
}
''';

void main() {
  group('ToyAnalysis.fromJsonString', () {
    final analysis = ToyAnalysis.fromJsonString(_fullAnalysis);

    test('parses identification', () {
      expect(analysis.identification.name, 'Wooden Stacking Rings');
      expect(analysis.identification.brand, 'Melissa & Doug');
      expect(analysis.identification.confidence, closeTo(0.82, 1e-9));
      expect(analysis.identification.detectedLanguage, 'en');
    });

    test('parses the age recommendation', () {
      expect(analysis.age.minMonths, 12);
      expect(analysis.age.maxMonths, 36);
      expect(analysis.age.label, '1–3 years');
    });

    test('parses safety, including hazards', () {
      expect(analysis.safety.overall, SafetyLevel.yellow);
      expect(analysis.safety.score, 74);
      expect(analysis.safety.hazards, hasLength(1));
      expect(analysis.safety.hazards.single.type, 'small_parts');
      expect(analysis.safety.supervisionLevel, 'constant');
    });

    test('parses development skills', () {
      expect(analysis.development.educationalScore, 81);
      expect(analysis.development.skills, hasLength(2));
      expect(analysis.development.skills.first.skill, 'fine_motor');
      expect(analysis.development.skills.first.score, 88);
    });

    test('lifts play ideas out of play_coach', () {
      expect(analysis.playIdeas, hasLength(1));
      expect(analysis.playIdeas.single.title, 'Rainbow tower');
      expect(analysis.playIdeas.single.skillsTargeted,
          ['fine_motor', 'spatial_reasoning']);
      expect(analysis.playIdeas.single.difficulty, 'easy');
    });

    test('parses materials', () {
      expect(analysis.materials, ['wood', 'non-toxic paint']);
    });
  });

  group('defensive parsing', () {
    test('an empty object yields safe defaults rather than throwing', () {
      final analysis = ToyAnalysis.fromJson(const {});
      expect(analysis.identification.name, '');
      expect(analysis.safety.overall, SafetyLevel.unknown);
      expect(analysis.safety.hazards, isEmpty);
      expect(analysis.development.educationalScore, 0);
      expect(analysis.playIdeas, isEmpty);
      expect(analysis.materials, isEmpty);
    });

    test('an unknown safety value maps to unknown, not a crash', () {
      final analysis = ToyAnalysis.fromJson(const {
        'safety': {'overall': 'chartreuse', 'score': 10},
      });
      expect(analysis.safety.overall, SafetyLevel.unknown);
    });

    test('numeric strings are coerced', () {
      final analysis = ToyAnalysis.fromJson(const {
        'safety': {'overall': 'green', 'score': '55'},
        'age_recommendation': {'min_months': '6', 'max_months': '24'},
      });
      expect(analysis.safety.score, 55);
      expect(analysis.age.minMonths, 6);
      expect(analysis.age.maxMonths, 24);
    });
  });

  group('safetyLevelFromKey', () {
    test('maps every machine value', () {
      expect(safetyLevelFromKey('green'), SafetyLevel.green);
      expect(safetyLevelFromKey('yellow'), SafetyLevel.yellow);
      expect(safetyLevelFromKey('red'), SafetyLevel.red);
    });

    test('maps null and junk to unknown', () {
      expect(safetyLevelFromKey(null), SafetyLevel.unknown);
      expect(safetyLevelFromKey('GREEN'), SafetyLevel.unknown);
    });
  });

  group('ScanSummary.fromRow', () {
    test('reads the history row shape', () {
      final summary = ScanSummary.fromRow({
        'id': 'scan-1',
        'identification': {'name': 'Rattle'},
        'safety_overall': 'green',
        'educational_score': 60,
        'created_at': '2026-07-20T10:00:00Z',
      });
      expect(summary.scanId, 'scan-1');
      expect(summary.toyName, 'Rattle');
      expect(summary.safety, SafetyLevel.green);
      expect(summary.educationalScore, 60);
      expect(summary.createdAt.toUtc().year, 2026);
    });

    test('survives a null identification', () {
      final summary = ScanSummary.fromRow({
        'id': 'scan-2',
        'identification': null,
        'safety_overall': null,
        'educational_score': null,
        'created_at': 'not-a-date',
      });
      expect(summary.toyName, '');
      expect(summary.safety, SafetyLevel.unknown);
      expect(summary.educationalScore, isNull);
    });
  });
}
