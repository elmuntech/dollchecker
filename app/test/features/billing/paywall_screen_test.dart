import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/errors/rate_limited.dart';
import 'package:dollchecker/core/utils/external_link.dart';
import 'package:dollchecker/features/billing/data/billing_repository.dart';
import 'package:dollchecker/features/billing/presentation/paywall_screen.dart';

import '../../helpers.dart';

/// Replays a prepared checkout outcome without a server.
class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({
    this.url = 'https://polar.sh/checkout/x',
    this.unavailable = false,
    this.rateLimited = false,
    this.fails = false,
    this.upgraded = true,
  });

  final String url;
  final bool unavailable;
  final bool rateLimited;
  final bool fails;
  final bool upgraded;

  int checkoutCalls = 0;
  int waitCalls = 0;

  @override
  Future<String> checkoutUrl() async {
    checkoutCalls++;
    if (unavailable) throw BillingUnavailableException();
    if (rateLimited) throw const RateLimitedException(30);
    if (fails) throw BillingFailedException();
    return url;
  }

  @override
  Future<String> portalUrl() async {
    if (unavailable) throw BillingUnavailableException();
    return url;
  }

  @override
  Future<bool> waitForPremium({Duration? timeout, Duration? interval}) async {
    waitCalls++;
    return upgraded;
  }
}

void main() {
  late List<Uri> opened;

  setUp(() => opened = []);

  Future<void> pumpPaywall(
    WidgetTester tester, {
    FakeBillingRepository? billing,
    bool launcherSucceeds = true,
    String? price,
    Locale locale = const Locale('en'),
  }) {
    return pumpApp(
      tester,
      const PaywallScreen(),
      locale: locale,
      surfaceSize: const Size(700, 1400),
      overrides: [
        billingRepositoryProvider
            .overrideWithValue(billing ?? FakeBillingRepository()),
        priceLabelProvider.overrideWithValue(price),
        externalLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return launcherSucceeds;
        }),
      ],
    );
  }

  testWidgets('sells the plan before asking for anything', (tester) async {
    await pumpPaywall(tester);
    expect(find.text('DollChecker Premium'), findsOneWidget);
    expect(find.text('Unlimited toy analyses'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue to checkout'),
        findsOneWidget);
  });

  testWidgets('shows a price only when one is configured', (tester) async {
    await pumpPaywall(tester);
    expect(find.text(r'$4.99 / month'), findsNothing);

    await pumpPaywall(tester, price: r'$4.99 / month');
    expect(find.text(r'$4.99 / month'), findsOneWidget);
  });

  testWidgets('opens the checkout page and waits for the webhook',
      (tester) async {
    final billing = FakeBillingRepository();
    await pumpPaywall(tester, billing: billing);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue to checkout'));
    await tester.pumpAndSettle();

    expect(billing.checkoutCalls, 1);
    expect(opened.single.toString(), 'https://polar.sh/checkout/x');
    expect(billing.waitCalls, 1);
  });

  testWidgets('says premium is not open yet rather than failing',
      (tester) async {
    await pumpPaywall(
      tester,
      billing: FakeBillingRepository(unavailable: true),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continue to checkout'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not open yet'), findsOneWidget);
    expect(opened, isEmpty);
  });

  testWidgets('reports a checkout that could not be created', (tester) async {
    await pumpPaywall(tester, billing: FakeBillingRepository(fails: true));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue to checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open checkout. Please try again.'),
        findsOneWidget);
  });

  testWidgets('reports a browser that would not open', (tester) async {
    await pumpPaywall(tester, launcherSucceeds: false);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue to checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open checkout. Please try again.'),
        findsOneWidget);
  });

  testWidgets('offers another look when the payment has not landed yet',
      (tester) async {
    // Paying happens outside the app and the tier arrives by webhook, so "not
    // yet" is a normal outcome, not an error.
    final billing = FakeBillingRepository(upgraded: false);
    await pumpPaywall(tester, billing: billing);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue to checkout'));
    await tester.pumpAndSettle();

    expect(find.textContaining('has not arrived yet'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Check again'));
    await tester.pumpAndSettle();
    expect(billing.waitCalls, 2);
  });

  testWidgets('asking too fast says to wait, not that the purchase failed',
      (tester) async {
    // The worst thing to say wrongly on a paywall is "that did not work" —
    // the user tries again immediately and hits the same limit.
    await pumpPaywall(
      tester,
      billing: FakeBillingRepository(rateLimited: true),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continue to checkout'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wait a moment'), findsOneWidget);
    expect(find.text('Could not open checkout. Please try again.'),
        findsNothing);
    expect(opened, isEmpty);
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpPaywall(tester, locale: const Locale('ru'));
    expect(find.text('Сканируйте без ограничений'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Перейти к оплате'),
        findsOneWidget);
  });
}
