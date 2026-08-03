import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/features/auth/domain/auth_failure.dart';

void main() {
  group('authFailureFromMessage', () {
    test('recognizes wrong credentials', () {
      expect(
        authFailureFromMessage('Invalid login credentials'),
        AuthFailure.invalidCredentials,
      );
    });

    test('recognizes an unconfirmed email', () {
      expect(
        authFailureFromMessage('Email not confirmed'),
        AuthFailure.emailNotConfirmed,
      );
    });

    test('recognizes an address that already has an account', () {
      expect(
        authFailureFromMessage('User already registered'),
        AuthFailure.emailTaken,
      );
    });

    test('recognizes a rejected password', () {
      expect(
        authFailureFromMessage('Password should be at least 6 characters'),
        AuthFailure.weakPassword,
      );
    });

    test('recognizes a malformed address', () {
      expect(
        authFailureFromMessage('Unable to validate email address'),
        AuthFailure.invalidEmail,
      );
    });

    test('treats a 429 as rate limiting whatever the wording', () {
      expect(
        authFailureFromMessage('anything', statusCode: '429'),
        AuthFailure.rateLimited,
      );
    });

    test('recognizes the resend cooldown, which also mentions email', () {
      // Would otherwise fall through to a less specific email rule.
      expect(
        authFailureFromMessage(
          'For security purposes, you can only request this after 51 seconds',
        ),
        AuthFailure.rateLimited,
      );
    });

    test('recognizes a dead connection', () {
      expect(
        authFailureFromMessage(
          'SocketException: Failed host lookup: "example.supabase.co"',
        ),
        AuthFailure.network,
      );
    });

    test('falls back to unknown rather than guessing', () {
      expect(authFailureFromMessage('teapot'), AuthFailure.unknown);
    });
  });

  group('authFailureFrom', () {
    test('reads an AuthException', () {
      expect(
        authFailureFrom(const AuthException('Invalid login credentials')),
        AuthFailure.invalidCredentials,
      );
    });

    test('reads an AuthException status code', () {
      expect(
        authFailureFrom(const AuthException('nope', statusCode: '429')),
        AuthFailure.rateLimited,
      );
    });

    test('falls back to the string form of anything else', () {
      expect(
        authFailureFrom(Exception('Failed host lookup: nowhere')),
        AuthFailure.network,
      );
    });
  });

  group('isValidEmail', () {
    test('accepts an ordinary address', () {
      expect(isValidEmail('parent@example.com'), isTrue);
    });

    test('tolerates surrounding whitespace', () {
      expect(isValidEmail('  parent@example.com '), isTrue);
    });

    test('rejects the obvious typos', () {
      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('parent'), isFalse);
      expect(isValidEmail('@example.com'), isFalse);
      expect(isValidEmail('parent@example'), isFalse);
      expect(isValidEmail('parent@@example.com'), isFalse);
      expect(isValidEmail('parent @example.com'), isFalse);
      expect(isValidEmail('parent@.com'), isFalse);
      expect(isValidEmail('parent@example.'), isFalse);
    });
  });

  group('validateCredentials', () {
    test('passes a usable sign-up', () {
      expect(
        validateCredentials(
          email: 'a@b.com',
          password: 'secret1',
          isSignUp: true,
        ),
        isNull,
      );
    });

    test('rejects a short password on sign-up', () {
      expect(
        validateCredentials(email: 'a@b.com', password: 'abc', isSignUp: true),
        AuthFailure.weakPassword,
      );
    });

    test('does not judge the length of an existing password on sign-in', () {
      // An older account may legitimately have a shorter password; telling that
      // user it is "too short" would send them to reset it for nothing.
      expect(
        validateCredentials(email: 'a@b.com', password: 'abc', isSignUp: false),
        isNull,
      );
    });

    test('rejects an empty password differently per mode', () {
      expect(
        validateCredentials(email: 'a@b.com', password: '', isSignUp: true),
        AuthFailure.weakPassword,
      );
      expect(
        validateCredentials(email: 'a@b.com', password: '', isSignUp: false),
        AuthFailure.invalidCredentials,
      );
    });

    test('rejects a malformed address before any round trip', () {
      expect(
        validateCredentials(email: 'nope', password: 'secret1', isSignUp: true),
        AuthFailure.invalidEmail,
      );
    });
  });
}
