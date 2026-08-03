import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/auth/data/auth_repository.dart';
import 'package:dollchecker/features/auth/domain/auth_failure.dart';
import 'package:dollchecker/features/auth/presentation/auth_screen.dart';

import '../../helpers.dart';

/// Records what the screen asked for and replays a prepared outcome.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.signInFailure,
    this.signUpOutcome = SignUpOutcome.signedIn,
  });

  final AuthFailure? signInFailure;
  final SignUpOutcome signUpOutcome;

  String? signedInEmail;
  String? signedUpEmail;
  String? resetEmail;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signedInEmail = email;
    if (signInFailure != null) throw AuthFailureException(signInFailure!);
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    signedUpEmail = email;
    return signUpOutcome;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetEmail = email;
  }

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}
}

void main() {
  Future<FakeAuthRepository> pumpAuth(
    WidgetTester tester, {
    FakeAuthRepository? repository,
    Locale locale = const Locale('en'),
  }) async {
    final repo = repository ?? FakeAuthRepository();
    await pumpApp(
      tester,
      const AuthScreen(),
      locale: locale,
      surfaceSize: const Size(600, 1200),
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    return repo;
  }

  testWidgets('opens on the sign-in form', (tester) async {
    await pumpAuth(tester);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Forgot your password?'), findsOneWidget);
  });

  testWidgets('signs in with what was typed', (tester) async {
    final repo = await pumpAuth(tester);
    await tester.enterText(find.byType(TextField).first, 'parent@example.com');
    await tester.enterText(find.byType(TextField).last, 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(repo.signedInEmail, 'parent@example.com');
  });

  testWidgets('explains a rejected password instead of showing the raw error',
      (tester) async {
    await pumpAuth(
      tester,
      repository:
          FakeAuthRepository(signInFailure: AuthFailure.invalidCredentials),
    );
    await tester.enterText(find.byType(TextField).first, 'parent@example.com');
    await tester.enterText(find.byType(TextField).last, 'wrong-one');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong email or password.'), findsOneWidget);
  });

  testWidgets('catches a malformed address before calling the server',
      (tester) async {
    final repo = await pumpAuth(tester);
    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.enterText(find.byType(TextField).last, 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(repo.signedInEmail, isNull);
  });

  group('sign up', () {
    testWidgets('rejects a short password locally', (tester) async {
      final repo = await pumpAuth(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.enterText(find.byType(TextField).last, 'abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(
        find.text('Use a password of at least 6 characters.'),
        findsOneWidget,
      );
      expect(repo.signedUpEmail, isNull);
    });

    testWidgets('tells the user to open the confirmation email',
        (tester) async {
      await pumpAuth(
        tester,
        repository: FakeAuthRepository(
          signUpOutcome: SignUpOutcome.confirmationRequired,
        ),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.enterText(find.byType(TextField).last, 'secret1');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.textContaining('a@b.com'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('goes straight in when confirmation is off', (tester) async {
      final repo = await pumpAuth(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.enterText(find.byType(TextField).last, 'secret1');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(repo.signedUpEmail, 'a@b.com');
      expect(find.text('Confirm your email'), findsNothing);
    });
  });

  group('password reset', () {
    Future<FakeAuthRepository> openReset(WidgetTester tester) async {
      final repo = await pumpAuth(tester);
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('asks only for an email', (tester) async {
      await openReset(tester);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Send reset link'),
          findsOneWidget);
    });

    testWidgets('sends the link and says what happens next', (tester) async {
      final repo = await openReset(tester);
      await tester.enterText(find.byType(TextField), 'parent@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      expect(repo.resetEmail, 'parent@example.com');
      expect(find.textContaining('reset link is on its way'), findsOneWidget);
    });

    testWidgets('does not send to a malformed address', (tester) async {
      final repo = await openReset(tester);
      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      expect(repo.resetEmail, isNull);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('can go back to sign in', (tester) async {
      await openReset(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Back to sign in'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpAuth(tester, locale: const Locale('ru'));
    expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
    expect(find.text('Забыли пароль?'), findsOneWidget);
  });
}
