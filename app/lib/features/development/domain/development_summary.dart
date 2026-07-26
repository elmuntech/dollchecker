import 'package:dollchecker/core/domain/skills.dart';

/// Aggregated score for one development skill across every scan in scope.
class SkillSummary {
  const SkillSummary({
    required this.skill,
    required this.avgScore,
    required this.maxScore,
    required this.scanCount,
  });

  final String skill;

  /// Mean 0–100 score across the scans that rated this skill.
  final double avgScore;

  /// Best single score seen — the toy that develops this skill most.
  final int maxScore;

  /// How many scans contributed a score for this skill.
  final int scanCount;

  factory SkillSummary.fromRow(Map<String, dynamic> r) => SkillSummary(
        skill: r['skill']?.toString() ?? '',
        avgScore: _toDouble(r['avg_score']),
        maxScore: _toInt(r['max_score']),
        scanCount: _toInt(r['scan_count']),
      );
}

/// Rolled-up score for one of the six developmental domains.
class GroupSummary {
  const GroupSummary({
    required this.group,
    required this.avgScore,
    required this.coveredSkills,
    required this.totalSkills,
  });

  final SkillGroup group;
  final double avgScore;

  /// Skills in this group that at least one scan has rated.
  final int coveredSkills;
  final int totalSkills;

  bool get hasData => coveredSkills > 0;
}

/// Everything the development dashboard renders, derived from the
/// `child_skill_summary` RPC.
class DevelopmentSummary {
  DevelopmentSummary(List<SkillSummary> skills)
      : skills = List.unmodifiable(
          [...skills.where((s) => kSkillKeys.contains(s.skill))]
            ..sort((a, b) => b.avgScore.compareTo(a.avgScore)),
        );

  /// Skills that at least one scan has rated, best first.
  final List<SkillSummary> skills;

  factory DevelopmentSummary.fromRows(List<Map<String, dynamic>> rows) =>
      DevelopmentSummary(rows.map(SkillSummary.fromRow).toList());

  static final empty = DevelopmentSummary(const []);

  bool get isEmpty => skills.isEmpty;

  /// Number of scans behind the summary. Each scan rates many skills, so the
  /// per-skill maximum is the closest honest estimate of the scan count.
  int get scanCount => skills.isEmpty
      ? 0
      : skills.map((s) => s.scanCount).reduce((a, b) => a > b ? a : b);

  /// Single 0–100 headline number: the mean of every rated skill.
  int get overallIndex {
    if (skills.isEmpty) return 0;
    final total = skills.fold<double>(0, (sum, s) => sum + s.avgScore);
    return (total / skills.length).round();
  }

  /// Highest-scoring skills — what the current toy set is good at.
  List<SkillSummary> strengths({int take = 5}) => skills.take(take).toList();

  /// Lowest-scoring rated skills, weakest first — where to shop next.
  List<SkillSummary> gaps({int take = 5}) =>
      skills.reversed.take(take).toList();

  /// Canonical skills no scan has rated yet.
  List<String> get uncoveredSkills {
    final rated = skills.map((s) => s.skill).toSet();
    return kSkillKeys.where((k) => !rated.contains(k)).toList();
  }

  /// The six developmental domains, always in enum order so the radar chart
  /// axes stay stable between rebuilds.
  List<GroupSummary> get groups {
    final bySkill = {for (final s in skills) s.skill: s};
    return SkillGroup.values.map((group) {
      final members = skillsInGroup(group);
      final rated = members
          .map((skill) => bySkill[skill])
          .whereType<SkillSummary>()
          .toList();
      final avg = rated.isEmpty
          ? 0.0
          : rated.fold<double>(0, (sum, s) => sum + s.avgScore) / rated.length;
      return GroupSummary(
        group: group,
        avgScore: avg,
        coveredSkills: rated.length,
        totalSkills: members.length,
      );
    }).toList();
  }
}

double _toDouble(Object? v) =>
    v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

int _toInt(Object? v) =>
    v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? 0));
