import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

final toyRepositoryProvider = Provider<ToyRepository>((ref) {
  return ToyRepository(ref.watch(supabaseProvider));
});

class ToyRepository {
  ToyRepository(this._client);
  final SupabaseClient _client;

  Future<List<Toy>> list({
    CollectionFilter filter = CollectionFilter.all,
    String search = '',
    int limit = 200,
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
    final rows = await query
        .order('last_scanned_at', ascending: false, nullsFirst: false)
        .limit(limit);
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

/// The collection grid contents for the active filter and search term.
final collectionProvider = FutureProvider.autoDispose<List<Toy>>((ref) async {
  final filter = ref.watch(collectionFilterProvider);
  final search = ref.watch(collectionSearchProvider);
  return ref.watch(toyRepositoryProvider).list(filter: filter, search: search);
});

final toyProvider =
    FutureProvider.autoDispose.family<Toy, String>((ref, id) async {
  return ref.watch(toyRepositoryProvider).get(id);
});

final toyScansProvider = FutureProvider.autoDispose
    .family<List<ScanSummary>, String>((ref, toyId) async {
  return ref.watch(toyRepositoryProvider).scans(toyId);
});
