import 'package:dollchecker/features/missions/domain/day.dart';

/// A play idea considered for today's missions, joined to the toy it came from.
class MissionCandidate {
  const MissionCandidate({
    required this.playIdeaId,
    required this.title,
    required this.description,
    required this.skills,
    required this.toyId,
    required this.toyName,
    required this.minAgeMonths,
    required this.durationMinutes,
    required this.toyLastPlayedAt,
  });

  final String playIdeaId;
  final String title;
  final String description;
  final List<String> skills;
  final String? toyId;
  final String toyName;
  final int? minAgeMonths;
  final int? durationMinutes;

  /// When the toy behind this idea was last used in a completed mission.
  /// Null means never — the strongest rotation signal there is.
  final DateTime? toyLastPlayedAt;

  /// The skill a mission built from this idea is filed under.
  String? get primarySkill => skills.isEmpty ? null : skills.first;
}

/// How a candidate scored, exposed so the reasoning stays inspectable (and
/// testable) rather than hidden inside the sort.
class ScoredCandidate {
  const ScoredCandidate({
    required this.candidate,
    required this.gap,
    required this.rotation,
    required this.jitter,
    required this.ageMismatch,
  });

  final MissionCandidate candidate;

  /// 0–1: how much the child's weakest skills stand to gain.
  final double gap;

  /// 0–1: how long the toy has sat unused.
  final double rotation;

  /// 0–1: stable per-day noise so the same toys do not surface every morning.
  final double jitter;

  /// True when the idea's minimum age is above the child's age.
  final bool ageMismatch;

  static const _gapWeight = 0.45;
  static const _rotationWeight = 0.35;
  static const _jitterWeight = 0.20;

  double get score {
    final base =
        _gapWeight * gap + _rotationWeight * rotation + _jitterWeight * jitter;
    // Too-old ideas are pushed below everything age-appropriate, but stay
    // eligible so a sparse collection can still fill the day.
    return ageMismatch ? base - 1 : base;
  }
}

/// A toy played this long ago counts as fully rotated out; beyond it, waiting
/// longer adds nothing.
const _rotationHorizonDays = 30;

/// Skills nothing has rated yet are worth a nudge — but less than a skill we
/// have measured and know is weak.
const _unratedSkillGap = 0.6;

/// Ranks [candidates] for [day] without picking, so callers (and tests) can see
/// why an idea won.
List<ScoredCandidate> scoreCandidates({
  required List<MissionCandidate> candidates,
  required Map<String, double> skillAverages,
  required DateTime day,
  int? childAgeMonths,
}) {
  final dayKey = epochDay(day);
  return candidates.map((c) {
    return ScoredCandidate(
      candidate: c,
      gap: _gapFor(c.skills, skillAverages),
      rotation: _rotationFor(c.toyLastPlayedAt, day),
      jitter: _jitter('${c.playIdeaId}#$dayKey'),
      ageMismatch: childAgeMonths != null &&
          c.minAgeMonths != null &&
          c.minAgeMonths! > childAgeMonths,
    );
  }).toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      // Ties break on id so the order is total and reproducible.
      return byScore != 0
          ? byScore
          : a.candidate.playIdeaId.compareTo(b.candidate.playIdeaId);
    });
}

/// Picks the day's missions: highest-scoring ideas, preferring a different toy
/// for each so a single toy cannot fill the whole day.
///
/// The result is stable for a given [day] — regenerating produces the same set
/// — and shifts as days pass, as toys are played, and as the child's skill gaps
/// change.
List<MissionCandidate> selectDailyMissions({
  required List<MissionCandidate> candidates,
  required Map<String, double> skillAverages,
  required DateTime day,
  int? childAgeMonths,
  int count = 3,
}) {
  if (count <= 0 || candidates.isEmpty) return const [];

  final ranked = scoreCandidates(
    candidates: candidates,
    skillAverages: skillAverages,
    day: day,
    childAgeMonths: childAgeMonths,
  );

  final picked = <MissionCandidate>[];
  final usedToys = <String>{};
  final usedIdeas = <String>{};

  // First pass: one mission per toy.
  for (final scored in ranked) {
    if (picked.length >= count) break;
    final toyId = scored.candidate.toyId;
    if (toyId != null && !usedToys.add(toyId)) continue;
    usedIdeas.add(scored.candidate.playIdeaId);
    picked.add(scored.candidate);
  }

  // Second pass: a small collection may not have `count` distinct toys, so
  // allow repeats rather than handing back a short day.
  for (final scored in ranked) {
    if (picked.length >= count) break;
    if (usedIdeas.contains(scored.candidate.playIdeaId)) continue;
    usedIdeas.add(scored.candidate.playIdeaId);
    picked.add(scored.candidate);
  }

  return picked;
}

/// 0–1 gap for the skills an idea targets — driven by the weakest one, since
/// that is the skill the mission is really there to shore up.
double _gapFor(List<String> skills, Map<String, double> skillAverages) {
  if (skills.isEmpty) return 0.5;
  var best = 0.0;
  for (final skill in skills) {
    final avg = skillAverages[skill];
    final gap =
        avg == null ? _unratedSkillGap : (100 - avg.clamp(0, 100)) / 100;
    if (gap > best) best = gap;
  }
  return best;
}

double _rotationFor(DateTime? lastPlayed, DateTime day) {
  if (lastPlayed == null) return 1;
  final days = epochDay(day) - epochDay(lastPlayed);
  if (days <= 0) return 0;
  return (days / _rotationHorizonDays).clamp(0.0, 1.0);
}

/// Deterministic 0–1 noise from a string (FNV-1a). Not random — the same input
/// always gives the same value, which is what keeps a day's missions stable.
double _jitter(String seed) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < seed.length; i++) {
    hash ^= seed.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash / 0xFFFFFFFF;
}
