import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dollchecker/core/errors/rate_limited.dart';
import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/profile/data/profile_repository.dart';

/// Billing exists in the code but not yet in the world: the Polar account or
/// its keys are not set up. The paywall says so instead of failing.
class BillingUnavailableException implements Exception {}

/// The provider was reachable but would not produce a link.
class BillingFailedException implements Exception {}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(ref.watch(supabaseProvider), ref);
});

class BillingRepository {
  BillingRepository(this._client, this._ref);
  final SupabaseClient _client;
  final Ref _ref;

  /// A hosted checkout page for the premium plan.
  Future<String> checkoutUrl() => _url(const {'action': 'checkout'});

  /// The provider's customer portal, where a subscription is changed or
  /// cancelled. Cancelling has to be possible without emailing support.
  Future<String> portalUrl() => _url(const {'action': 'portal'});

  Future<String> _url(Map<String, dynamic> body) async {
    final dynamic payload;
    try {
      final res = await _client.functions.invoke('polar-billing', body: body);
      if (res.status == 503) throw BillingUnavailableException();
      // Not a failed purchase. Saying "checkout failed" would send the user
      // straight back to the button, into the same limit.
      if (res.status == 429) throw rateLimitedFrom(res.data);
      if (res.status != 200 || res.data == null) {
        throw BillingFailedException();
      }
      payload = res.data;
    } on FunctionException catch (e) {
      // Newer supabase_flutter throws instead of returning a non-2xx status.
      if (e.status == 503) throw BillingUnavailableException();
      if (e.status == 429) throw rateLimitedFrom(e.details);
      throw BillingFailedException();
    }

    final url = (payload as Map)['url']?.toString();
    // Only ever hand an https link to the browser: opening whatever came back
    // is how an open redirect starts.
    if (url == null || !url.startsWith('https://')) {
      throw BillingFailedException();
    }
    return url;
  }

  /// Waits for the tier to turn premium after a checkout.
  ///
  /// Paying happens outside the app and the tier is granted by a webhook, so
  /// there is nothing to await directly — the account is simply re-read until
  /// the upgrade lands. Returning false is not an error: the webhook may still
  /// be in flight, and the screen says as much.
  Future<bool> waitForPremium({
    Duration timeout = const Duration(seconds: 45),
    Duration interval = const Duration(seconds: 3),
  }) async {
    final profiles = _ref.read(profileRepositoryProvider);
    final deadline = DateTime.now().add(timeout);
    while (true) {
      try {
        final quota = await profiles.quota();
        if (quota.isPremium) {
          // Everything that reads the tier is now stale.
          _ref.invalidate(quotaProvider);
          return true;
        }
      } catch (_) {
        // A failed poll is not a failed purchase; keep trying until the
        // deadline.
      }
      if (!DateTime.now().add(interval).isBefore(deadline)) return false;
      await Future<void>.delayed(interval);
    }
  }
}
