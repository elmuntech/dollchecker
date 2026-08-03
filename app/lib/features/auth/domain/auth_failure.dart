import 'package:supabase_flutter/supabase_flutter.dart';

/// Why an auth attempt did not succeed, in terms the UI can explain.
///
/// Supabase reports failures as free-text messages, which are useless to show
/// verbatim: a user who mistyped a password should not read "Invalid login
/// credentials" in English inside a Russian app. Everything is mapped to one of
/// these cases and localized at the edge.
enum AuthFailure {
  invalidCredentials,
  emailNotConfirmed,
  emailTaken,
  weakPassword,
  invalidEmail,
  rateLimited,
  network,
  unknown,
}

/// Shortest password Supabase accepts by default. Checked client-side too, so a
/// too-short password costs no round trip.
const kMinPasswordLength = 6;

/// Classifies an auth error message. Pure, so every branch is testable without
/// a server.
AuthFailure authFailureFromMessage(String message, {String? statusCode}) {
  final m = message.toLowerCase();

  // Rate limiting comes first: its message often also mentions "email", which
  // would otherwise match a less specific rule below.
  if (statusCode == '429' ||
      m.contains('rate limit') ||
      m.contains('too many') ||
      m.contains('security purposes')) {
    return AuthFailure.rateLimited;
  }
  if (m.contains('failed host lookup') ||
      m.contains('socketexception') ||
      m.contains('clientexception') ||
      m.contains('connection refused') ||
      m.contains('connection closed') ||
      m.contains('network is unreachable') ||
      m.contains('timed out')) {
    return AuthFailure.network;
  }
  if (m.contains('email not confirmed') || m.contains('not confirmed')) {
    return AuthFailure.emailNotConfirmed;
  }
  if (m.contains('already registered') ||
      m.contains('already been registered') ||
      m.contains('user already exists')) {
    return AuthFailure.emailTaken;
  }
  if (m.contains('password should be') ||
      m.contains('password is too') ||
      m.contains('weak password')) {
    return AuthFailure.weakPassword;
  }
  if (m.contains('invalid email') ||
      m.contains('unable to validate email') ||
      m.contains('email address is invalid')) {
    return AuthFailure.invalidEmail;
  }
  if (m.contains('invalid login') ||
      m.contains('invalid credentials') ||
      m.contains('invalid grant')) {
    return AuthFailure.invalidCredentials;
  }
  return AuthFailure.unknown;
}

/// Classifies whatever the Supabase SDK threw.
AuthFailure authFailureFrom(Object error) {
  if (error is AuthException) {
    return authFailureFromMessage(error.message, statusCode: error.statusCode);
  }
  return authFailureFromMessage(error.toString());
}

/// Rejects input the server would only reject after a round trip. Returns null
/// when the credentials are worth sending.
AuthFailure? validateCredentials({
  required String email,
  required String password,
  required bool isSignUp,
}) {
  if (!isValidEmail(email)) return AuthFailure.invalidEmail;
  if (password.isEmpty) {
    return isSignUp ? AuthFailure.weakPassword : AuthFailure.invalidCredentials;
  }
  // Only sign-up is checked for length: an existing account may predate the
  // current rule, and telling that user their password is too short is a lie.
  if (isSignUp && password.length < kMinPasswordLength) {
    return AuthFailure.weakPassword;
  }
  return null;
}

/// Deliberately permissive — the server is the real authority. This only
/// catches obvious typos ("no @", trailing space, missing domain).
bool isValidEmail(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty || trimmed.contains(' ')) return false;
  final at = trimmed.indexOf('@');
  if (at <= 0 || at != trimmed.lastIndexOf('@')) return false;
  final domain = trimmed.substring(at + 1);
  return domain.contains('.') &&
      !domain.startsWith('.') &&
      !domain.endsWith('.');
}
