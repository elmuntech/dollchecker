import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/play/domain/play_idea_entry.dart';

final playRepositoryProvider = Provider<PlayRepository>((ref) {
  return PlayRepository(ref.watch(supabaseProvider));
});

class PlayRepository {
  PlayRepository(this._client);
  final SupabaseClient _client;

  Future<List<PlayIdeaEntry>> list({
    String? childId,
    bool favoritesOnly = false,
    String? skill,
    int limit = 200,
  }) async {
    var query = _client.from('play_ideas').select(PlayIdeaEntry.columns);
    if (favoritesOnly) query = query.eq('is_favorited', true);
    if (skill != null) query = query.contains('skills_targeted', [skill]);
    if (childId != null) query = query.eq('scans.child_profile_id', childId);

    final rows =
        await query.order('created_at', ascending: false).limit(limit);
    return (rows as List)
        .map((r) => PlayIdeaEntry.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> setFavorite(String id, bool favorited) async {
    await _client
        .from('play_ideas')
        .update({'is_favorited': favorited}).eq('id', id);
  }
}

/// Show only favorited ideas.
final playFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

/// Optional skill filter (a canonical skill key), null for "any skill".
final playSkillFilterProvider = StateProvider<String?>((ref) => null);

final playIdeasProvider =
    FutureProvider.autoDispose<List<PlayIdeaEntry>>((ref) async {
  final child = ref.watch(selectedChildProvider);
  return ref.watch(playRepositoryProvider).list(
        childId: child?.id,
        favoritesOnly: ref.watch(playFavoritesOnlyProvider),
        skill: ref.watch(playSkillFilterProvider),
      );
});
