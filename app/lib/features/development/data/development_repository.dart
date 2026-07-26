import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/development/domain/development_summary.dart';

/// One toy that scored highly on a given skill, with the coaching tip the
/// analysis produced for it.
class SkillHighlight {
  const SkillHighlight({
    required this.scanId,
    required this.toyName,
    required this.score,
    required this.howToMaximize,
  });

  final String scanId;
  final String toyName;
  final int score;
  final String howToMaximize;

  factory SkillHighlight.fromRow(Map<String, dynamic> r) {
    final scan = r['scans'];
    final ident = scan is Map ? scan['identification'] : null;
    return SkillHighlight(
      scanId: scan is Map ? scan['id'].toString() : '',
      toyName: ident is Map ? (ident['name']?.toString() ?? '') : '',
      score: r['score'] is int ? r['score'] as int : 0,
      howToMaximize: r['how_to_maximize']?.toString() ?? '',
    );
  }
}

final developmentRepositoryProvider = Provider<DevelopmentRepository>((ref) {
  return DevelopmentRepository(ref.watch(supabaseProvider));
});

class DevelopmentRepository {
  DevelopmentRepository(this._client);
  final SupabaseClient _client;

  /// Aggregated per-skill scores. [childId] null aggregates every scan.
  Future<DevelopmentSummary> summary({String? childId}) async {
    final rows = await _client.rpc(
      'child_skill_summary',
      params: {'p_child_id': childId},
    );
    if (rows is! List) return DevelopmentSummary.empty;
    return DevelopmentSummary.fromRows(
      rows.map((r) => Map<String, dynamic>.from(r as Map)).toList(),
    );
  }

  /// The toys that develop [skill] best, strongest first.
  Future<List<SkillHighlight>> highlights(
    String skill, {
    String? childId,
    int limit = 3,
  }) async {
    var query = _client
        .from('development_scores')
        .select('score, how_to_maximize, scans!inner(id, identification, child_profile_id)')
        .eq('skill', skill);
    if (childId != null) {
      query = query.eq('scans.child_profile_id', childId);
    }
    final rows = await query.order('score', ascending: false).limit(limit);
    return (rows as List)
        .map((r) => SkillHighlight.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}

/// Dashboard data for the currently selected child.
final developmentSummaryProvider =
    FutureProvider.autoDispose<DevelopmentSummary>((ref) async {
  final child = ref.watch(selectedChildProvider);
  return ref.watch(developmentRepositoryProvider).summary(childId: child?.id);
});

/// Best toys for one skill, for the skill detail sheet.
final skillHighlightsProvider = FutureProvider.autoDispose
    .family<List<SkillHighlight>, String>((ref, skill) async {
  final child = ref.watch(selectedChildProvider);
  return ref
      .watch(developmentRepositoryProvider)
      .highlights(skill, childId: child?.id);
});
