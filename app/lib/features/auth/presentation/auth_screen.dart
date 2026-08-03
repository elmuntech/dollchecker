import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/core/l10n/labels.dart';
import 'package:dollchecker/features/auth/data/auth_repository.dart';
import 'package:dollchecker/features/auth/domain/auth_failure.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// What the single form is currently for.
enum AuthMode { signIn, signUp, resetRequest }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _loading = false;
  AuthFailure? _failure;

  /// Set once an email has gone out, so the form is replaced by an explanation
  /// of what to do next instead of appearing to have done nothing.
  String? _confirmationSentTo;
  String? _resetSentTo;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchTo(AuthMode mode) {
    setState(() {
      _mode = mode;
      _failure = null;
      _resetSentTo = null;
      _confirmationSentTo = null;
    });
  }

  Future<void> _submit() async {
    final email = _email.text;
    final password = _password.text;

    if (_mode == AuthMode.resetRequest) {
      if (!isValidEmail(email)) {
        setState(() => _failure = AuthFailure.invalidEmail);
        return;
      }
    } else {
      final invalid = validateCredentials(
        email: email,
        password: password,
        isSignUp: _mode == AuthMode.signUp,
      );
      if (invalid != null) {
        setState(() => _failure = invalid);
        return;
      }
    }

    setState(() {
      _loading = true;
      _failure = null;
    });

    final auth = ref.read(authRepositoryProvider);
    try {
      switch (_mode) {
        case AuthMode.signIn:
          await auth.signIn(email: email, password: password);
        case AuthMode.signUp:
          final outcome = await auth.signUp(email: email, password: password);
          if (outcome == SignUpOutcome.confirmationRequired && mounted) {
            setState(() => _confirmationSentTo = email.trim());
          }
        case AuthMode.resetRequest:
          await auth.sendPasswordReset(email);
          if (mounted) setState(() => _resetSentTo = email.trim());
      }
    } on AuthFailureException catch (e) {
      if (mounted) setState(() => _failure = e.failure);
    } catch (_) {
      if (mounted) setState(() => _failure = AuthFailure.unknown);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🧸', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 8),
                  Text(l.appTitle,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 32),
                  if (_confirmationSentTo != null)
                    _MailSent(
                      title: l.checkInbox,
                      body: l.checkInboxHint(_confirmationSentTo!),
                      onBack: () => _switchTo(AuthMode.signIn),
                    )
                  else if (_resetSentTo != null)
                    _MailSent(
                      title: l.resetPassword,
                      body: l.resetEmailSent(_resetSentTo!),
                      onBack: () => _switchTo(AuthMode.signIn),
                    )
                  else
                    ..._form(l),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _form(AppLocalizations l) {
    final isReset = _mode == AuthMode.resetRequest;

    return [
      if (isReset) ...[
        Text(l.resetPasswordHint, textAlign: TextAlign.center),
        const SizedBox(height: 16),
      ],
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: isReset ? TextInputAction.done : TextInputAction.next,
        decoration: InputDecoration(labelText: l.email),
      ),
      if (!isReset) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_loading) _submit();
          },
          decoration: InputDecoration(
            labelText: l.password,
            helperText: _mode == AuthMode.signUp ? l.passwordRule : null,
          ),
        ),
      ],
      if (_failure != null) ...[
        const SizedBox(height: 12),
        Text(
          authFailureLabel(l, _failure!),
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(switch (_mode) {
                  AuthMode.signIn => l.signIn,
                  AuthMode.signUp => l.signUp,
                  AuthMode.resetRequest => l.sendResetLink,
                }),
        ),
      ),
      const SizedBox(height: 8),
      if (isReset)
        TextButton(
          onPressed: () => _switchTo(AuthMode.signIn),
          child: Text(l.backToSignIn),
        )
      else ...[
        TextButton(
          onPressed: () => _switchTo(
            _mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn,
          ),
          child: Text(_mode == AuthMode.signIn ? l.signUp : l.signIn),
        ),
        if (_mode == AuthMode.signIn)
          TextButton(
            onPressed: () => _switchTo(AuthMode.resetRequest),
            child: Text(l.forgotPassword),
          ),
      ],
    ];
  }
}

/// Shown after a confirmation or recovery email has been sent. There is nothing
/// to do in the app until the user opens the link, so the form gets out of the
/// way.
class _MailSent extends StatelessWidget {
  const _MailSent({
    required this.title,
    required this.body,
    required this.onBack,
  });

  final String title;
  final String body;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Icon(Icons.mark_email_read_outlined,
            size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        TextButton(onPressed: onBack, child: Text(l.backToSignIn)),
      ],
    );
  }
}
