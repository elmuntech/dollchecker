import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Public client configuration loaded from the bundled `.env` asset.
/// Every value here is safe to ship; RLS protects data and the Anthropic key
/// lives only in the Edge Function.
class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Where Supabase sends the user back after a confirmation or recovery
  /// email. Must also be listed under Auth → URL configuration → Redirect URLs,
  /// and registered as a deep link in the Android manifest / iOS Info.plist.
  /// Null falls back to the project's Site URL.
  static String? get authRedirectUrl => optional('AUTH_REDIRECT_URL');

  /// Legal and support links. The stores require the first two before
  /// submission; the UI hides whichever is missing rather than showing a row
  /// that leads nowhere.
  static String? get privacyUrl => optional('PRIVACY_URL');
  static String? get termsUrl => optional('TERMS_URL');
  static String? get supportEmail => optional('SUPPORT_EMAIL');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR-PROJECT');

  /// Treats a blank or still-placeholder entry as absent, so a half-filled
  /// `.env` never surfaces a "YOUR-…" string in the UI.
  static String? optional(String key) {
    final raw = dotenv.env[key]?.trim() ?? '';
    if (raw.isEmpty || raw.contains('YOUR-')) return null;
    return raw;
  }
}
