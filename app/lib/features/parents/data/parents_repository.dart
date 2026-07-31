import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/development/data/development_repository.dart';
import 'package:dollchecker/features/missions/data/mission_repository.dart';
import 'package:dollchecker/features/missions/domain/day.dart';
import 'package:dollchecker/features/parents/domain/household_report.dart';
import 'package:dollchecker/features/parents/domain/safety_watch.dart';

final parentsRepositoryProvider = Provider<ParentsRepository>((ref) {
  return ParentsRepository(ref.watch(supabaseProvider), ref);
});

/// Household-wide reads for the parents panel. Everything else in the app looks
/// at one child at a time; this is the only surface that spans them.
class ParentsRepository {
  ParentsRepository(this._client, this._ref);
  final SupabaseClient _client;
  final Ref _ref;

  /// The last [windowDays] days for every child, plus the household totals.
  Future<HouseholdReport> report({
    required List<ChildProfile> children,
    required DateTime today,
    int windowDays = kParentsWindowDays,
  }) async {
    if (children.isEmpty) return HouseholdReport.empty;

    final since = dateOnly(today).subtract(Duration(days: windowDays - 1));

    // Two household-wide queries rather than two per child. Both bounds are
    // deliberately loose — `HouseholdReport.build` trims to local calendar days.
    final scanRows = await _client
        .from('scans')
        .select('child_profile_id, created_at')
        .gte('created_at', since.toUtc().toIso8601String());

    final missionRows = await _client
        .from('daily_missions')
        .select('child_profile_id, mission_date, status')
        .gte('mission_date', isoDate(since));

    // The development index is a lifetime aggregate, so it comes from the same
    // RPC the dashboard uses — one per child, run together.
    final development = _ref.read(developmentRepositoryProvider);
    final summaries = await Future.wait(
      children.map((c) => development.summary(childId: c.id)),
    );

    return HouseholdReport.build(
      children: children,
      scanRows: _rows(scanRows),
      missionRows: _rows(missionRows),
      developmentIndexes: {
        for (var i = 0; i < children.length; i++)
          children[i].id: summaries[i].overallIndex,
      },
      today: today,
      windowDays: windowDays,
    );
  }

  /// Owned toys whose latest analysis was not green — the panel's safety review.
  ///
  /// Wishlist entries are left out: a toy that is not in the house cannot hurt
  /// anyone, and flagging it would only bury the ones that can.
  Future<SafetyWatch> safetyWatchlist({int limit = 12}) async {
    final rows = await _client
        .from('toys')
        .select(Toy.columns)
        .eq('owned', true)
        .inFilter('latest_safety', ['red', 'yellow'])
        // `safety_level` is declared green → yellow → red, so descending puts
        // the worst first and the limit keeps the ones that matter most.
        .order('latest_safety', ascending: false)
        .order('last_scanned_at', ascending: false)
        .limit(limit);

    return SafetyWatch.from(_rows(rows).map(Toy.fromRow));
  }

  static List<Map<String, dynamic>> _rows(Object? result) =>
      result is List
          ? result
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList()
          : const [];
}

/// The household's week. Rebuilt when the child list or the day changes.
final householdReportProvider =
    FutureProvider.autoDispose<HouseholdReport>((ref) async {
  final children = ref.watch(childrenProvider).valueOrNull ?? const [];
  return ref.watch(parentsRepositoryProvider).report(
        children: children,
        today: ref.watch(todayProvider),
      );
});

final safetyWatchProvider =
    FutureProvider.autoDispose<SafetyWatch>((ref) async {
  return ref.watch(parentsRepositoryProvider).safetyWatchlist();
});
