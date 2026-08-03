import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this build may sell and manage the subscription inside the app.
///
/// Payments go through Polar, a merchant of record, via a hosted checkout in
/// the browser. That is fine on Android and on the web. On iOS it is not:
/// App Store guideline 3.1.1 requires In-App Purchase for digital content
/// unlocked inside the app, and 3.1.3 forbids steering the user to an outside
/// purchase — so both the checkout button and the "manage subscription" link
/// are review risks on iOS, not just the first one.
///
/// The conservative configuration is therefore to ship iOS with **no purchase
/// path at all**. Premium bought on Android or the web still works: the tier
/// comes from the server, and every paid feature reads it the same way on
/// every platform. Nothing is hidden except the ways to buy and to cancel.
///
/// This is a judgement about review risk, not legal advice, and it is not
/// permanent. Two ways out, in increasing order of effort:
///
///  1. Set [kAllowIosCheckout] to true and submit with the web checkout,
///     arguing the case. Some reviewers accept it; many do not.
///  2. Add StoreKit (directly or via RevenueCat) for iOS and gate on the
///     platform here instead of hiding the button.
///
/// Either way this file is the only place that decides.
const bool kAllowIosCheckout = false;

/// True when the running platform may show a purchase or manage-subscription
/// path.
bool get storeBillingAllowed {
  if (kIsWeb) return true;
  return Platform.isIOS ? kAllowIosCheckout : true;
}

/// Overridden in tests, which must be able to render both configurations
/// without pretending to be a different operating system.
final billingAllowedProvider = Provider<bool>((ref) => storeBillingAllowed);
