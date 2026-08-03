import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/paging/paged_list.dart';
import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

/// How many toys one page of the collection grid holds.
const kCollectionPageSize = 30;

final toyRepositoryProvider = Provider<ToyRepository>((ref) {
  return ToyRepository(ref.watch(supabaseProvider));
});

class ToyRepository {
  ToyRepository(this._client);
  final SupabaseClient _client;

  /// One page of the collection for the active filter and search term.
  ///
  /// Paged rather than capped at 200: a family past that simply stopped
  /// seeing the rest of their toy box, and the grid gave no hint that it had
  /// stopped early.
  Future<List<Toy>> list({
    CollectionFilter filter = CollectionFilter.all,
    String search = '',
    int limit = kCollectionPageSize,
    int offset = 0,
  }) async {
    var query = _client.from('toys').select(Toy.columns);
    switch (filter) {
      case CollectionFilter.owned:
        query = query.eq('owned', true);
      case CollectionFilter.wishlist:
        query = query.eq('owned', false);
      case CollectionFilter.all:
        break;
    }
    final term = search.trim();
    if (term.isNotEmpty) {
      final escaped = term.replaceAll('%', r'\%').replaceAll('_', r'\_');
      query = query.or('name.ilike.%$escaped%,brand.ilike.%$escaped%');
    }
    // `id` makes the sort total. `last_scanned_at` is null for a wishlist toy
    // that has never been scanned, so ties are the common case here, not the
    // rare one — without a tiebreaker the page boundary would move between
    // requests and rows would be shown twice or skipped entirely.
    final rows = await query
        .order('last_scanned_at', ascending: false, nullsFirst: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map((r) => Toy.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<Toy> get(String id) async {
    final row =
        await _client.from('toys').select(Toy.columns).eq('id', id).single();
    return Toy.fromRow(Map<String, dynamic>.from(row));
  }

  /// Moves a toy between the toy box (`owned`) and the wishlist.
  Future<void> setOwned(String id, bool owned) async {
    await _client
        .from('toys')
        .update({'owned': owned, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  /// Removes the collection entry. Scans are kept — `scans.toy_id` is
  /// `on delete set null` — so History and the dashboard are unaffected.
  Future<void> delete(String id) async {
    await _client.from('toys').delete().eq('id', id);
  }

  /// Every scan recorded for one toy, newest first.
  Future<List<ScanSummary>> scans(String toyId) async {
    final rows = await _client
        .from('scans')
        .select(
            'id, identification, safety_overall, educational_score, created_at')
        .eq('toy_id', toyId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => ScanSummary.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}

final collectionFilterProvider =
    StateProvider<CollectionFilter>((ref) => CollectionFilter.all);

final collectionSearchProvider = StateProvider<String>((ref) => '');

/// The collection grid contents for the active filter and search term, one
/// page at a time.
///
/// Rebuilt from scratch whenever the filter or the search term changes: a
/// half-scrolled page of the previous query is not a prefix of the new one.
class CollectionPageController
    extends AutoDisposeAsyncNotifier<PagedList<Toy>> {
  CollectionFilter _filter = CollectionFilter.all;
  String _search = '';

  @override
  Future<PagedList<Toy>> build() async {
    _filter = ref.watch(collectionFilterProvider);
    _search = ref.watch(collectionSearchProvider);
    final page = await ref.watch(toyRepositoryProvider).list(
          filter: _filter,
          search: _search,
        );
    return PagedList.first(page, pageSize: kCollectionPageSize);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.loading());
    try {
      final page = await ref.read(toyRepositoryProvider).list(
            filter: _filter,
            search: _search,
            offset: current.length,
          );
      // De-duplicated by id: a scan finishing between two pages moves a toy to
      // the top of the ordering, and offset paging would otherwise repeat it.
      state = AsyncData(
        current.appendUnique(
          page,
          pageSize: kCollectionPageSize,
          key: (toy) => toy.id,
        ),
      );
    } catch (_) {
      // Keep what is already on screen; the footer offers another try.
      state = AsyncData(current.settled());
    }
  }
}

final collectionProvider =
    AsyncNotifierProvider.autoDispose<CollectionPageController, PagedList<Toy>>(
  CollectionPageController.new,
);

final toyProvider =
    FutureProvider.autoDispose.family<Toy, String>((ref, id) async {
  return ref.watch(toyRepositoryProvider).get(id);
});

final toyScansProvider = FutureProvider.autoDispose
    .family<List<ScanSummary>, String>((ref, toyId) async {
  return ref.watch(toyRepositoryProvider).scans(toyId);
});
