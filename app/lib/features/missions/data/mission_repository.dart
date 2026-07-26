import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/development/data/development_repository.dart';
import 'package:dollchecker/features/missions/domain/day.dart';
import 'package:dollchecker/features/missions/domain/mission.dart';
import 'package:dollchecker/features/missions/domain/mission_selection.dart';
import 'package:dollchecker/features/missions/domain/mission_stats.dart';

/// How many missions make up a day.
const kMissionsPerDay = 3;

/// How far back the streak query reads. Long enough for any streak worth
/// displaying, short enough to stay one cheap request.
const _streakWindowDays = 400;

final missionRepositoryProvider = Provider<MissionRepository>((ref) {
  return MissionRepository(ref.watch(supabaseProvider), ref);
});

class MissionRepository {
  MissionRepository(this._client, this._ref);
  final SupabaseClient _client;
  final Ref _ref;

  /// Today's missions for [child], generating them on first open of the day.
  Future<List<Mission>> missionsForDay(
    ChildProfile child, {
    required DateTime day,
  }) async {
    final existing = await _fetchDay(child.id, day);
    if (existing.isNotEmpty) return existing;

    // Read back rather than returning what we inserted: a concurrent device may
    // have won the upsert, and its rows are the ones that count.
    final generated = await _generate(child, day);
    return generated ? _fetchDay(child.id, day) : const [];
  }

  Future<List<Mission>> _fetchDay(String childId, DateTime day) async {
    final rows = await _client
        .from('daily_missions')
        .select(Mission.columns)
        .eq('child_profile_id', childId)
        .eq('mission_date', isoDate(day))
        .order('slot');
    return (rows as List)
        .map((r) => Mission.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Builds the day's missions from the family's stored play ideas.
  ///
  /// Candidates are drawn from every scan the user owns rather than only this
  /// child's, so a newly added child still gets missions from the toys already
  /// in the house. Age-appropriateness is handled by the selection scoring.
  /// Returns whether any missions were written for the day.
  Future<bool> _generate(ChildProfile child, DateTime day) async {
    final candidates = await _candidates();
    if (candidates.isEmpty) return false;

    final summary =
        await _ref.read(developmentRepositoryProvider).summary(childId: child.id);
    final skillAverages = {
      for (final skill in summary.skills) skill.skill: skill.avgScore,
    };

    final picked = selectDailyMissions(
      candidates: candidates,
      skillAverages: skillAverages,
      day: day,
      childAgeMonths: child.ageMonths,
      count: kMissionsPerDay,
    );
    if (picked.isEmpty) return false;

    final userId = _client.auth.currentUser!.id;
    final rows = [
      for (var slot = 0; slot < picked.length; slot++)
        {
          'user_id': userId,
          'child_profile_id': child.id,
          'mission_date': isoDate(day),
          'slot': slot,
          'play_idea_id': picked[slot].playIdeaId,
          'toy_id': picked[slot].toyId,
          'title': picked[slot].title,
          'description': picked[slot].description,
          'skill': picked[slot].primarySkill,
          'duration_minutes': picked[slot].durationMinutes,
        },
    ];

    // Two devices opening the app on the same morning would otherwise race;
    // the unique (child, date, slot) index makes the loser a no-op.
    await _client.from('daily_missions').upsert(
          rows,
          onConflict: 'child_profile_id,mission_date,slot',
          ignoreDuplicates: true,
        );
    return true;
  }

  Future<List<MissionCandidate>> _candidates({int limit = 300}) async {
    final ideaRows = await _client
        .from('play_ideas')
        .select('id, title, description, skills_targeted, min_age_months, '
            'duration_minutes, scans!inner(toy_id, identification)')
        .order('created_at', ascending: false)
        .limit(limit);

    final toyRows =
        await _client.from('toys').select('id, name, last_played_at');
    final toys = {
      for (final row in (toyRows as List))
        row['id'].toString(): Map<String, dynamic>.from(row as Map),
    };

    return (ideaRows as List).map((raw) {
      final r = Map<String, dynamic>.from(raw as Map);
      final scan = r['scans'];
      final toyId = scan is Map ? scan['toy_id']?.toString() : null;
      final toy = toyId == null ? null : toys[toyId];
      final ident = scan is Map ? scan['identification'] : null;

      return MissionCandidate(
        playIdeaId: r['id'].toString(),
        title: r['title']?.toString() ?? '',
        description: r['description']?.toString() ?? '',
        skills: r['skills_targeted'] is List
            ? (r['skills_targeted'] as List).map((e) => '$e').toList()
            : const [],
        toyId: toyId,
        toyName: toy?['name']?.toString() ??
            (ident is Map ? (ident['name']?.toString() ?? '') : ''),
        minAgeMonths: r['min_age_months'] as int?,
        durationMinutes: r['duration_minutes'] as int?,
        toyLastPlayedAt: toy?['last_played_at'] == null
            ? null
            : DateTime.tryParse('${toy!['last_played_at']}')?.toLocal(),
      );
    }).toList();
  }

  /// Marks a mission done or skipped. Completing one also stamps the toy's
  /// `last_played_at` (via a trigger), which feeds tomorrow's rotation.
  Future<void> setStatus(String missionId, MissionStatus status) async {
    await _client.from('daily_missions').update({
      'status': missionStatusKey(status),
      'completed_at': status == MissionStatus.completed
          ? DateTime.now().toUtc().toIso8601String()
          : null,
    }).eq('id', missionId);
  }

  Future<MissionStats> stats(String childId, {required DateTime today}) async {
    final since = today.subtract(const Duration(days: _streakWindowDays));
    final rows = await _client
        .from('daily_missions')
        .select('mission_date')
        .eq('child_profile_id', childId)
        .eq('status', 'completed')
        .gte('mission_date', isoDate(since));

    final dates = (rows as List)
        .map((r) => DateTime.tryParse('${(r as Map)['mission_date']}'))
        .whereType<DateTime>();
    return MissionStats.fromCompletedDates(dates, today: today);
  }

  /// Owned toys that have gone longest without being played — the rotation
  /// nudge. Never-played toys come first.
  Future<List<Toy>> rotationSuggestions({int limit = 3}) async {
    final rows = await _client
        .from('toys')
        .select(Toy.columns)
        .eq('owned', true)
        .order('last_played_at', ascending: true, nullsFirst: true)
        .limit(limit);
    return (rows as List)
        .map((r) => Toy.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}

/// Today, as a date-only value. Overridden in tests that need a fixed day.
final todayProvider = Provider<DateTime>((ref) => dateOnly(DateTime.now()));

final todaysMissionsProvider =
    FutureProvider.autoDispose<List<Mission>>((ref) async {
  final child = ref.watch(selectedChildProvider);
  if (child == null) return const [];
  return ref.watch(missionRepositoryProvider).missionsForDay(
        child,
        day: ref.watch(todayProvider),
      );
});

final missionStatsProvider =
    FutureProvider.autoDispose<MissionStats>((ref) async {
  final child = ref.watch(selectedChildProvider);
  if (child == null) return MissionStats.empty;
  return ref
      .watch(missionRepositoryProvider)
      .stats(child.id, today: ref.watch(todayProvider));
});

final rotationSuggestionsProvider =
    FutureProvider.autoDispose<List<Toy>>((ref) async {
  return ref.watch(missionRepositoryProvider).rotationSuggestions();
});
