import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/errors/rate_limited.dart';

void main() {
  group('rateLimitedFrom', () {
    test('reads the wait out of a decoded body', () {
      expect(
        rateLimitedFrom({'error': 'rate_limited', 'retry_after': 30})
            .retryAfterSeconds,
        30,
      );
    });

    test('accepts a numeric string, which is how some transports arrive', () {
      expect(rateLimitedFrom({'retry_after': '45'}).retryAfterSeconds, 45);
    });

    test('still reports the limit when no wait was stated', () {
      // A limit with no Retry-After is still a limit; the message just cannot
      // say how long.
      expect(rateLimitedFrom({'error': 'rate_limited'}).retryAfterSeconds,
          isNull);
      expect(rateLimitedFrom(null).retryAfterSeconds, isNull);
      expect(rateLimitedFrom('nonsense').retryAfterSeconds, isNull);
      expect(rateLimitedFrom({'retry_after': 'soon'}).retryAfterSeconds,
          isNull);
    });
  });
}
