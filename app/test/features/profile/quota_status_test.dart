import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/profile/data/profile_repository.dart';

void main() {
  final future = DateTime.now().toUtc().add(const Duration(days: 5));
  final past = DateTime.now().toUtc().subtract(const Duration(days: 5));

  group('QuotaStatus', () {
    test('counts remaining free scans inside the window', () {
      final quota = QuotaStatus(tier: 'free', used: 3, resetAt: future);
      expect(quota.remaining, kFreeMonthlyScans - 3);
      expect(quota.isExhausted, isFalse);
      expect(quota.isPremium, isFalse);
    });

    test('is exhausted at the limit', () {
      final quota =
          QuotaStatus(tier: 'free', used: kFreeMonthlyScans, resetAt: future);
      expect(quota.remaining, 0);
      expect(quota.isExhausted, isTrue);
    });

    test('never reports negative remaining when usage overshoots', () {
      final quota = QuotaStatus(
          tier: 'free', used: kFreeMonthlyScans + 5, resetAt: future);
      expect(quota.remaining, 0);
    });

    test('treats an elapsed window as a fresh month', () {
      // The server only writes the rollover on the next scan, so the UI has to
      // apply it itself.
      final quota = QuotaStatus(tier: 'free', used: 99, resetAt: past);
      expect(quota.effectiveUsed, 0);
      expect(quota.remaining, kFreeMonthlyScans);
      expect(quota.isExhausted, isFalse);
    });

    test('premium is unlimited', () {
      final quota = QuotaStatus(tier: 'premium', used: 500, resetAt: future);
      expect(quota.isPremium, isTrue);
      expect(quota.remaining, isNull);
      expect(quota.isExhausted, isFalse);
    });

    test('a missing reset date leaves usage as stored', () {
      const quota = QuotaStatus(tier: 'free', used: 4, resetAt: null);
      expect(quota.effectiveUsed, 4);
      expect(quota.remaining, kFreeMonthlyScans - 4);
    });

    test('the unknown fallback is a full free allowance', () {
      expect(QuotaStatus.unknown.remaining, kFreeMonthlyScans);
      expect(QuotaStatus.unknown.isPremium, isFalse);
    });
  });

  group('QuotaStatus.fromRow', () {
    test('reads the profiles row', () {
      final quota = QuotaStatus.fromRow({
        'tier': 'premium',
        'scan_quota_used': 7,
        'quota_reset_at': '2026-08-01T00:00:00Z',
      });
      expect(quota.tier, 'premium');
      expect(quota.used, 7);
      expect(quota.resetAt, isNotNull);
    });

    test('defaults a sparse row to a free account', () {
      final quota = QuotaStatus.fromRow(const {});
      expect(quota.tier, 'free');
      expect(quota.used, 0);
      expect(quota.resetAt, isNull);
    });
  });
}
