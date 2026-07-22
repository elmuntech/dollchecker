import 'dart:convert';

/// Immutable models mirroring the Edge Function's JSON schema. Hand-written
/// (no codegen) so they compile without build_runner.

enum SafetyLevel { green, yellow, red, unknown }

SafetyLevel _safetyFrom(String? s) {
  switch (s) {
    case 'green':
      return SafetyLevel.green;
    case 'yellow':
      return SafetyLevel.yellow;
    case 'red':
      return SafetyLevel.red;
    default:
      return SafetyLevel.unknown;
  }
}

T? _as<T>(Object? v) => v is T ? v : null;

int _int(Object? v, [int fallback = 0]) =>
    v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? fallback));

double _double(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : (double.tryParse('$v') ?? fallback);

List<String> _strList(Object? v) =>
    v is List ? v.map((e) => '$e').toList() : const [];

class Identification {
  final String name;
  final String brand;
  final String category;
  final double confidence;
  final String detectedLanguage;

  const Identification({
    required this.name,
    required this.brand,
    required this.category,
    required this.confidence,
    required this.detectedLanguage,
  });

  factory Identification.fromJson(Map<String, dynamic> j) => Identification(
        name: _as<String>(j['name']) ?? '',
        brand: _as<String>(j['brand']) ?? '',
        category: _as<String>(j['category']) ?? '',
        confidence: _double(j['confidence']),
        detectedLanguage: _as<String>(j['detected_language']) ?? 'en',
      );
}

class AgeRecommendation {
  final int minMonths;
  final int maxMonths;
  final String label;

  const AgeRecommendation({
    required this.minMonths,
    required this.maxMonths,
    required this.label,
  });

  factory AgeRecommendation.fromJson(Map<String, dynamic> j) =>
      AgeRecommendation(
        minMonths: _int(j['min_months']),
        maxMonths: _int(j['max_months']),
        label: _as<String>(j['label']) ?? '',
      );
}

class Hazard {
  final String type;
  final String severity;
  final String description;
  final String recommendation;

  const Hazard({
    required this.type,
    required this.severity,
    required this.description,
    required this.recommendation,
  });

  factory Hazard.fromJson(Map<String, dynamic> j) => Hazard(
        type: _as<String>(j['type']) ?? 'other',
        severity: _as<String>(j['severity']) ?? 'low',
        description: _as<String>(j['description']) ?? '',
        recommendation: _as<String>(j['recommendation']) ?? '',
      );
}

class SafetyReport {
  final SafetyLevel overall;
  final int score;
  final List<Hazard> hazards;
  final String summary;
  final String supervisionLevel;
  final String cleaning;
  final String storage;
  final String disclaimer;

  const SafetyReport({
    required this.overall,
    required this.score,
    required this.hazards,
    required this.summary,
    required this.supervisionLevel,
    required this.cleaning,
    required this.storage,
    required this.disclaimer,
  });

  factory SafetyReport.fromJson(Map<String, dynamic> j) => SafetyReport(
        overall: _safetyFrom(_as<String>(j['overall'])),
        score: _int(j['score']),
        hazards: (j['hazards'] as List? ?? [])
            .map((e) => Hazard.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        summary: _as<String>(j['summary']) ?? '',
        supervisionLevel: _as<String>(j['supervision_level']) ?? 'occasional',
        cleaning: _as<String>(j['cleaning']) ?? '',
        storage: _as<String>(j['storage']) ?? '',
        disclaimer: _as<String>(j['disclaimer']) ?? '',
      );
}

class SkillScore {
  final String skill; // machine key
  final int score;
  final String reason;
  final String howToMaximize;

  const SkillScore({
    required this.skill,
    required this.score,
    required this.reason,
    required this.howToMaximize,
  });

  factory SkillScore.fromJson(Map<String, dynamic> j) => SkillScore(
        skill: _as<String>(j['skill']) ?? '',
        score: _int(j['score']),
        reason: _as<String>(j['reason']) ?? '',
        howToMaximize: _as<String>(j['how_to_maximize']) ?? '',
      );
}

class Development {
  final int educationalScore;
  final String educationalSummary;
  final List<SkillScore> skills;

  const Development({
    required this.educationalScore,
    required this.educationalSummary,
    required this.skills,
  });

  factory Development.fromJson(Map<String, dynamic> j) => Development(
        educationalScore: _int(j['educational_score']),
        educationalSummary: _as<String>(j['educational_summary']) ?? '',
        skills: (j['skills'] as List? ?? [])
            .map((e) =>
                SkillScore.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class PlayIdea {
  final String title;
  final String description;
  final List<String> skillsTargeted;
  final int minAgeMonths;
  final int durationMinutes;
  final String difficulty;

  const PlayIdea({
    required this.title,
    required this.description,
    required this.skillsTargeted,
    required this.minAgeMonths,
    required this.durationMinutes,
    required this.difficulty,
  });

  factory PlayIdea.fromJson(Map<String, dynamic> j) => PlayIdea(
        title: _as<String>(j['title']) ?? '',
        description: _as<String>(j['description']) ?? '',
        skillsTargeted: _strList(j['skills_targeted']),
        minAgeMonths: _int(j['min_age_months']),
        durationMinutes: _int(j['duration_minutes']),
        difficulty: _as<String>(j['difficulty']) ?? 'medium',
      );
}

class ToyAnalysis {
  final Identification identification;
  final AgeRecommendation age;
  final List<String> materials;
  final SafetyReport safety;
  final Development development;
  final List<PlayIdea> playIdeas;

  const ToyAnalysis({
    required this.identification,
    required this.age,
    required this.materials,
    required this.safety,
    required this.development,
    required this.playIdeas,
  });

  factory ToyAnalysis.fromJson(Map<String, dynamic> j) => ToyAnalysis(
        identification: Identification.fromJson(
            Map<String, dynamic>.from(j['identification'] as Map? ?? {})),
        age: AgeRecommendation.fromJson(
            Map<String, dynamic>.from(j['age_recommendation'] as Map? ?? {})),
        materials: _strList(j['materials']),
        safety: SafetyReport.fromJson(
            Map<String, dynamic>.from(j['safety'] as Map? ?? {})),
        development: Development.fromJson(
            Map<String, dynamic>.from(j['development'] as Map? ?? {})),
        playIdeas: ((j['play_coach'] as Map?)?['ideas'] as List? ?? [])
            .map((e) => PlayIdea.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static ToyAnalysis fromJsonString(String s) =>
      ToyAnalysis.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// Result of a scan: the persisted id + storage path + parsed analysis.
class ScanResult {
  final String scanId;
  final String? imagePath;
  final ToyAnalysis analysis;

  const ScanResult({
    required this.scanId,
    required this.imagePath,
    required this.analysis,
  });
}

/// Lightweight row for the history list.
class ScanSummary {
  final String scanId;
  final String toyName;
  final SafetyLevel safety;
  final int? educationalScore;
  final DateTime createdAt;

  const ScanSummary({
    required this.scanId,
    required this.toyName,
    required this.safety,
    required this.educationalScore,
    required this.createdAt,
  });

  factory ScanSummary.fromRow(Map<String, dynamic> r) {
    final ident = r['identification'];
    final name = ident is Map ? (ident['name']?.toString() ?? '') : '';
    return ScanSummary(
      scanId: r['id'].toString(),
      toyName: name,
      safety: _safetyFrom(r['safety_overall'] as String?),
      educationalScore: r['educational_score'] as int?,
      createdAt:
          DateTime.tryParse('${r['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }
}
