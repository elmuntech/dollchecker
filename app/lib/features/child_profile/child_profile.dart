import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/supabase/supabase.dart';

class ChildProfile {
  final String id;
  final String name;
  final DateTime? birthDate;

  const ChildProfile({required this.id, required this.name, this.birthDate});

  factory ChildProfile.fromRow(Map<String, dynamic> r) => ChildProfile(
        id: r['id'].toString(),
        name: r['name']?.toString() ?? '',
        birthDate: r['birth_date'] == null
            ? null
            : DateTime.tryParse('${r['birth_date']}'),
      );

  /// Whole months since birth — the unit the analyzer reasons about.
  int? get ageMonths {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var months =
        (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
    if (now.day < birthDate!.day) months -= 1;
    return months < 0 ? 0 : months;
  }
}

final childRepositoryProvider = Provider<ChildRepository>((ref) {
  return ChildRepository(ref.watch(supabaseProvider));
});

class ChildRepository {
  ChildRepository(this._client);
  final SupabaseClient _client;

  static const _columns = 'id, name, birth_date';

  Future<List<ChildProfile>> list() async {
    final rows = await _client
        .from('child_profiles')
        .select(_columns)
        .order('created_at');
    return (rows as List)
        .map((r) => ChildProfile.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<ChildProfile> create({
    required String name,
    DateTime? birthDate,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('child_profiles')
        .insert({
          'user_id': userId,
          'name': name,
          'birth_date': _dateOnly(birthDate),
        })
        .select(_columns)
        .single();
    return ChildProfile.fromRow(Map<String, dynamic>.from(row));
  }

  Future<ChildProfile> update({
    required String id,
    required String name,
    DateTime? birthDate,
  }) async {
    final row = await _client
        .from('child_profiles')
        .update({'name': name, 'birth_date': _dateOnly(birthDate)})
        .eq('id', id)
        .select(_columns)
        .single();
    return ChildProfile.fromRow(Map<String, dynamic>.from(row));
  }

  /// Deleting a child keeps their scans: `scans.child_profile_id` is
  /// `on delete set null`, so history and the collection survive.
  Future<void> delete(String id) async {
    await _client.from('child_profiles').delete().eq('id', id);
  }

  static String? _dateOnly(DateTime? d) =>
      d?.toIso8601String().split('T').first;
}

/// Loads the current user's children.
final childrenProvider = FutureProvider<List<ChildProfile>>((ref) async {
  // Re-fetch when auth changes.
  ref.watch(sessionProvider);
  return ref.watch(childRepositoryProvider).list();
});

/// Id of the child the user is currently looking at. Held separately from the
/// resolved profile so the choice survives a refetch of [childrenProvider].
final selectedChildIdProvider = StateProvider<String?>((ref) => null);

/// The selected child, falling back to the first one when nothing is chosen —
/// or when the chosen child has been deleted.
final selectedChildProvider = Provider<ChildProfile?>((ref) {
  final children = ref.watch(childrenProvider).valueOrNull ?? const [];
  if (children.isEmpty) return null;
  final id = ref.watch(selectedChildIdProvider);
  return children.firstWhere((c) => c.id == id, orElse: () => children.first);
});
