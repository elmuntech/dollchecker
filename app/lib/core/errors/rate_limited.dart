/// The server refused because too many requests arrived too quickly.
///
/// One type for the whole app rather than one per feature. A rate limit means
/// the same thing wherever it comes from — wait, then try again — and a screen
/// that cannot tell it apart from a real failure tells the user their action
/// broke when it merely came too soon.
class RateLimitedException implements Exception {
  const RateLimitedException([this.retryAfterSeconds]);

  /// How long the server asked us to wait, when it said. Null is common: a
  /// limit with no stated wait is still a limit.
  final int? retryAfterSeconds;
}

/// Reads `retry_after` out of whatever shape the error arrived in.
///
/// The body is a decoded map on one path and an opaque `details` object on the
/// other, and either may be missing the field entirely — so the exception is
/// thrown regardless of whether a wait could be read.
RateLimitedException rateLimitedFrom(Object? payload) {
  if (payload is Map) {
    final seconds = payload['retry_after'];
    if (seconds is int) return RateLimitedException(seconds);
    if (seconds is String) return RateLimitedException(int.tryParse(seconds));
  }
  return const RateLimitedException();
}
