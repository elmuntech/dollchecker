import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/config/env.dart';
import 'package:dollchecker/core/errors/rate_limited.dart';
import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/auth/domain/auth_failure.dart';

/// Raised by [AuthRepository] instead of the SDK's free-text errors.
class AuthFailureException implements Exception {
  const AuthFailureException(this.failure);
  final AuthFailure failure;
}

/// Result of a sign-up. Whether a session comes back depends on a project
/// setting the app does not control, so both outcomes are first-class.
enum SignUpOutcome {
  /// Signed in immediately — email confirmation is off.
  signedIn,

  /// A confirmation email was sent; the account is not usable until it is
  /// opened.
  confirmationRequired,
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseProvider));
});

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Future<void> signIn({required String email, required String password}) {
    return _guard(() async {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    });
  }

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: Env.authRedirectUrl,
      );
      return res.session == null
          ? SignUpOutcome.confirmationRequired
          : SignUpOutcome.signedIn;
    });
  }

  /// Emails a recovery link. Deliberately reports success even for an address
  /// with no account — telling a stranger which emails are registered is an
  /// account-enumeration leak, and Supabase behaves the same way.
  Future<void> sendPasswordReset(String email) {
    return _guard(() async {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: Env.authRedirectUrl,
      );
    });
  }

  /// Sets a new password for the session opened by a recovery link.
  Future<void> updatePassword(String password) {
    return _guard(() async {
      await _auth.updateUser(UserAttributes(password: password));
    });
  }

  Future<void> signOut() => _auth.signOut();

  /// Permanently deletes the account, then signs out locally.
  ///
  /// The heavy lifting is the `delete-account` Edge Function: a client can
  /// never delete an `auth.users` row itself, and the user's stored images have
  /// to go with it.
  Future<void> deleteAccount() async {
    try {
      final res = await _client.functions.invoke(
        'delete-account',
        body: const {'confirm': true},
      );
      if (res.status == 429) throw rateLimitedFrom(res.data);
      if (res.status != 200) throw _deleteFailure(res.status);
    } on FunctionException catch (e) {
      // Newer supabase_flutter throws instead of returning a non-2xx status.
      if (e.status == 429) throw rateLimitedFrom(e.details);
      throw _deleteFailure(e.status);
    }
    // The user row is gone; the local session is now a token for nothing.
    await _auth.signOut();
  }

  AuthFailureException _deleteFailure(int status) => AuthFailureException(
        status == 401 ? AuthFailure.invalidCredentials : AuthFailure.unknown,
      );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailureException {
      rethrow;
    } catch (e) {
      throw AuthFailureException(authFailureFrom(e));
    }
  }
}

/// True while the app is handling a password-recovery deep link — the router
/// then holds the user on the "set a new password" screen.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);
