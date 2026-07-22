import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialized global Supabase client. `Supabase.initialize` is called in
/// `main()` before `runApp`.
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Emits the current auth state; drives router redirects.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseProvider);
  return client.auth.onAuthStateChange;
});

/// Convenience: the current session (null when signed out).
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider); // re-evaluate on auth changes
  return ref.watch(supabaseProvider).auth.currentSession;
});
