import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/core/config/env.dart';
import 'package:dollchecker/core/config/store_billing.dart';
import 'package:dollchecker/core/errors/rate_limited.dart';
import 'package:dollchecker/core/utils/external_link.dart';
import 'package:dollchecker/features/billing/data/billing_repository.dart';
import 'package:dollchecker/features/profile/data/profile_repository.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// The price line, when one has been configured. Left absent by default: the
/// checkout page is the authority on price, and a stale hard-coded number in
/// the app is worse than none.
final priceLabelProvider =
    Provider<String?>((ref) => Env.optional('PREMIUM_PRICE_LABEL'));

/// Where the paywall is in its one long step: the purchase happens in a
/// browser, so the app can only wait for the upgrade to land.
enum _Stage {
  idle,
  opening,
  waiting,
  unavailable,
  rateLimited,
  failed,
  timedOut,
}

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Stage _stage = _Stage.idle;

  Future<void> _startCheckout() async {
    setState(() => _stage = _Stage.opening);
    final billing = ref.read(billingRepositoryProvider);

    final String url;
    try {
      url = await billing.checkoutUrl();
    } on BillingUnavailableException {
      if (mounted) setState(() => _stage = _Stage.unavailable);
      return;
    } on RateLimitedException {
      // The purchase did not fail — it was asked for too fast. Saying
      // "checkout failed" would send the user straight back into the limit.
      if (mounted) setState(() => _stage = _Stage.rateLimited);
      return;
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.failed);
      return;
    }

    final opened = await ref.read(externalLauncherProvider)(Uri.parse(url));
    if (!opened) {
      if (mounted) setState(() => _stage = _Stage.failed);
      return;
    }

    if (mounted) setState(() => _stage = _Stage.waiting);
    final upgraded = await billing.waitForPremium();
    if (!mounted) return;
    // Settle the stage either way. Popping is best-effort — the paywall may be
    // the only route on the stack — and a spinner left running after the answer
    // arrived would say the app is still working when it is not.
    setState(() => _stage = upgraded ? _Stage.idle : _Stage.timedOut);
    if (upgraded) Navigator.of(context).maybePop();
  }

  Future<void> _recheck() async {
    setState(() => _stage = _Stage.waiting);
    final upgraded = await ref
        .read(billingRepositoryProvider)
        .waitForPremium(timeout: const Duration(seconds: 6));
    if (!mounted) return;
    setState(() => _stage = upgraded ? _Stage.idle : _Stage.timedOut);
    if (upgraded) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final price = ref.watch(priceLabelProvider);
    final canBuy = ref.watch(billingAllowedProvider);
    final busy = _stage == _Stage.opening || _stage == _Stage.waiting;

    return Scaffold(
      appBar: AppBar(title: Text(l.premiumTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Center(child: Text('✨', style: TextStyle(fontSize: 56))),
            const SizedBox(height: 12),
            Text(
              l.premiumHeadline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l.premiumSubtitle(kFreeMonthlyScans),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _Benefit(icon: Icons.all_inclusive, text: l.benefitUnlimitedScans),
            _Benefit(icon: Icons.insights, text: l.benefitFullHistory),
            _Benefit(icon: Icons.local_fire_department, text: l.benefitMissions),
            _Benefit(icon: Icons.family_restroom, text: l.benefitEveryChild),
            const SizedBox(height: 24),
            // The benefits are shown on every platform — they are what the
            // account already has or could have. Only the ways to buy are
            // platform-dependent.
            if (!canBuy)
              Text(
                l.premiumElsewhere,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              if (price != null) ...[
                Text(
                  price,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: busy ? null : _startCheckout,
                child: busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.premiumCta),
              ),
              const SizedBox(height: 12),
              _StageMessage(stage: _stage, onRecheck: _recheck),
              const SizedBox(height: 16),
              Text(
                l.premiumFinePrint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Says what is happening now, and — when the wait ran out — what to do about
/// it. A checkout that completed while the app was closed lands here too.
class _StageMessage extends StatelessWidget {
  const _StageMessage({required this.stage, required this.onRecheck});

  final _Stage stage;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (text, isError) = switch (stage) {
      _Stage.idle => (null, false),
      _Stage.opening => (null, false),
      _Stage.waiting => (l.premiumWaiting, false),
      _Stage.unavailable => (l.premiumUnavailable, false),
      _Stage.rateLimited => (l.rateLimited, false),
      _Stage.failed => (l.premiumFailed, true),
      _Stage.timedOut => (l.premiumPending, false),
    };
    if (text == null) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: isError ? scheme.error : null),
        ),
        if (stage == _Stage.timedOut)
          TextButton(onPressed: onRecheck, child: Text(l.premiumRecheck)),
      ],
    );
  }
}
