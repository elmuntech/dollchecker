import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/supabase/supabase.dart';

/// Free-tier monthly scan allowance. Must match `FREE_MONTHLY_SCANS` in
/// `supabase/functions/analyze-toy/utils.ts` — the Edge Function is the one
/// that actually enforces it; this copy only drives the UI.
const kFreeMonthlyScans = 10;

/// The caller's subscription tier and remaining scan allowance.
class QuotaStatus {
  const QuotaStatus({
    required this.tier,
    required this.used,
    required this.resetAt,
  });

  final String tier;
  final int used;
  final DateTime? resetAt;

  static const unknown = QuotaStatus(tier: 'free', used: 0, resetAt: null);

  bool get isPremium => tier != 'free';

  /// Usage after applying a monthly rollover that the server has not yet
  /// written back (it only does so on the next scan).
  int get effectiveUsed {
    final reset = resetAt;
    if (reset != null && !DateTime.now().toUtc().isBefore(reset.toUtc())) {
      return 0;
    }
    return used < 0 ? 0 : used;
  }

  /// Null for premium accounts, which are unlimited.
  int? get remaining =>
      isPremium ? null : (kFreeMonthlyScans - effectiveUsed).clamp(0, kFreeMonthlyScans);

  bool get isExhausted => remaining == 0;

  factory QuotaStatus.fromRow(Map<String, dynamic> r) => QuotaStatus(
        tier: r['tier']?.toString() ?? 'free',
        used: r['scan_quota_used'] is int ? r['scan_quota_used'] as int : 0,
        resetAt: r['quota_reset_at'] == null
            ? null
            : DateTime.tryParse('${r['quota_reset_at']}'),
      );
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseProvider));
});

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;

  Future<QuotaStatus> quota() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return QuotaStatus.unknown;
    final row = await _client
        .from('profiles')
        .select('tier, scan_quota_used, quota_reset_at')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return QuotaStatus.unknown;
    return QuotaStatus.fromRow(Map<String, dynamic>.from(row));
  }
}

final quotaProvider = FutureProvider<QuotaStatus>((ref) async {
  ref.watch(sessionProvider);
  return ref.watch(profileRepositoryProvider).quota();
});
