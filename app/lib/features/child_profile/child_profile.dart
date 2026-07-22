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

  int? get ageMonths {
    if (birthDate == null) return null;
    final now = DateTime.now();
    return (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
  }
}

final childRepositoryProvider = Provider<ChildRepository>((ref) {
  return ChildRepository(ref.watch(supabaseProvider));
});

class ChildRepository {
  ChildRepository(this._client);
  final SupabaseClient _client;

  Future<List<ChildProfile>> list() async {
    final rows = await _client
        .from('child_profiles')
        .select('id, name, birth_date')
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
          'birth_date': birthDate?.toIso8601String().split('T').first,
        })
        .select('id, name, birth_date')
        .single();
    return ChildProfile.fromRow(Map<String, dynamic>.from(row));
  }
}

/// Loads the current user's children.
final childrenProvider = FutureProvider<List<ChildProfile>>((ref) async {
  // Re-fetch when auth changes.
  ref.watch(sessionProvider);
  return ref.watch(childRepositoryProvider).list();
});

/// Currently selected child (defaults to the first one).
final selectedChildProvider = StateProvider<ChildProfile?>((ref) {
  final children = ref.watch(childrenProvider).valueOrNull;
  return children != null && children.isNotEmpty ? children.first : null;
});
