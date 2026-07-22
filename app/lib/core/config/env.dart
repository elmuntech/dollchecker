import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Public client configuration loaded from the bundled `.env` asset.
/// Both values are safe to ship; RLS protects data and the Anthropic key
/// lives only in the Edge Function.
class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR-PROJECT');
}
