import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/core/l10n/labels.dart';
import 'package:dollchecker/features/auth/data/auth_repository.dart';
import 'package:dollchecker/features/auth/domain/auth_failure.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Where a recovery link lands. Supabase has already opened a session by the
/// time this screen builds — the only thing left is choosing a new password,
/// and the router keeps the user here until they do.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  AuthFailure? _failure;
  bool _mismatch = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.length < kMinPasswordLength) {
      setState(() {
        _failure = AuthFailure.weakPassword;
        _mismatch = false;
      });
      return;
    }
    if (password != _confirm.text) {
      setState(() {
        _failure = null;
        _mismatch = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _failure = null;
      _mismatch = false;
    });

    try {
      await ref.read(authRepositoryProvider).updatePassword(password);
      // Leaving recovery mode releases the router; the user lands in the app
      // already signed in with the new password.
      ref.read(passwordRecoveryProvider.notifier).state = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).passwordUpdated)),
        );
      }
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _failure = e.failure);
    } catch (_) {
      if (mounted) setState(() => _failure = AuthFailure.unknown);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    ref.read(passwordRecoveryProvider.notifier).state = false;
    // The recovery session only exists to change the password, so abandoning
    // the flow signs out rather than dropping the user into the app.
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.resetPassword)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.newPasswordHint, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l.newPassword,
                      helperText: l.passwordRule,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    onSubmitted: (_) {
                      if (!_loading) _save();
                    },
                    decoration: InputDecoration(labelText: l.confirmPassword),
                  ),
                  if (_mismatch || _failure != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _mismatch
                          ? l.passwordsDoNotMatch
                          : authFailureLabel(l, _failure!),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l.savePassword),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _cancel,
                    child: Text(l.cancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
