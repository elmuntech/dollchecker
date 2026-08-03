import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/core/config/env.dart';

/// The published legal and support destinations. Both stores refuse an app
/// without a privacy policy, but the app has to build and run long before those
/// URLs exist — so each one is optional and the UI simply omits what is absent.
class LegalLinks {
  const LegalLinks({this.privacyUrl, this.termsUrl, this.supportEmail});

  final String? privacyUrl;
  final String? termsUrl;
  final String? supportEmail;

  static const none = LegalLinks();

  bool get isEmpty =>
      privacyUrl == null && termsUrl == null && supportEmail == null;

  bool get isNotEmpty => !isEmpty;

  /// `mailto:` target for the support row, with a subject that tells support
  /// which app the message came from.
  Uri? get supportUri {
    final email = supportEmail;
    if (email == null) return null;
    return Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: const {'subject': 'DollChecker'},
    );
  }
}

/// Reads the links from the bundled `.env`. Overridden in tests.
final legalLinksProvider = Provider<LegalLinks>((ref) {
  return LegalLinks(
    privacyUrl: Env.privacyUrl,
    termsUrl: Env.termsUrl,
    supportEmail: Env.supportEmail,
  );
});
