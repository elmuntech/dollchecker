import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/paging/paged_list.dart';
import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/play/domain/play_idea_entry.dart';

/// How many ideas one page of the Play Coach feed holds.
const kPlayPageSize = 30;

final playRepositoryProvider = Provider<PlayRepository>((ref) {
  return PlayRepository(ref.watch(supabaseProvider));
});

class PlayRepository {
  PlayRepository(this._client);
  final SupabaseClient _client;

  /// One page of the idea feed, newest first.
  ///
  /// Paged rather than capped at 200: every scan writes several ideas, so an
  /// active family reaches that in a few months and the feed would then stop
  /// without saying it had.
  Future<List<PlayIdeaEntry>> list({
    String? childId,
    bool favoritesOnly = false,
    String? skill,
    int limit = kPlayPageSize,
    int offset = 0,
  }) async {
    var query = _client.from('play_ideas').select(PlayIdeaEntry.columns);
    if (favoritesOnly) query = query.eq('is_favorited', true);
    if (skill != null) query = query.contains('skills_targeted', [skill]);
    if (childId != null) query = query.eq('scans.child_profile_id', childId);

    // One scan writes several ideas in a single insert, so they share a
    // `created_at` to the microsecond. `id` is what keeps the sort total and
    // the page boundary in one place between requests.
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
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

/// The Play Coach feed, one page at a time.
///
/// Rebuilt from scratch when the child, the favorites toggle or the skill
/// filter changes — a half-scrolled page of the old query says nothing about
/// the new one.
class PlayPageController
    extends AutoDisposeAsyncNotifier<PagedList<PlayIdeaEntry>> {
  String? _childId;
  bool _favoritesOnly = false;
  String? _skill;

  @override
  Future<PagedList<PlayIdeaEntry>> build() async {
    _childId = ref.watch(selectedChildProvider)?.id;
    _favoritesOnly = ref.watch(playFavoritesOnlyProvider);
    _skill = ref.watch(playSkillFilterProvider);
    final page = await ref.watch(playRepositoryProvider).list(
          childId: _childId,
          favoritesOnly: _favoritesOnly,
          skill: _skill,
        );
    return PagedList.first(page, pageSize: kPlayPageSize);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.loading());
    try {
      final page = await ref.read(playRepositoryProvider).list(
            childId: _childId,
            favoritesOnly: _favoritesOnly,
            skill: _skill,
            offset: current.length,
          );
      // De-duplicated by id: a scan finishing between two pages inserts ideas
      // at the top, and offset paging would otherwise repeat a row.
      state = AsyncData(
        current.appendUnique(
          page,
          pageSize: kPlayPageSize,
          key: (idea) => idea.id,
        ),
      );
    } catch (_) {
      // Keep what is already on screen; the footer offers another try.
      state = AsyncData(current.settled());
    }
  }

  /// Flips one idea's favorite flag in place.
  ///
  /// Refetching instead would throw away every page after the first, which is
  /// a long scroll back for what is a one-field change.
  Future<void> toggleFavorite(PlayIdeaEntry idea) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final wanted = !idea.isFavorited;
    await ref.read(playRepositoryProvider).setFavorite(idea.id, wanted);

    // "Favorites only" is a filter, so unfavoriting there removes the row
    // rather than restyling it.
    final items = _favoritesOnly && !wanted
        ? current.items.where((i) => i.id != idea.id).toList()
        : [
            for (final i in current.items)
              i.id == idea.id ? i.copyWith(isFavorited: wanted) : i,
          ];
    state = AsyncData(
      PagedList(items: items, hasMore: current.hasMore),
    );
  }
}

final playIdeasProvider = AsyncNotifierProvider.autoDispose<PlayPageController,
    PagedList<PlayIdeaEntry>>(PlayPageController.new);
