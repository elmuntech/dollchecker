import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// How the app leaves for the browser or the mail client. Indirected through a
/// provider so a test can watch where a screen tried to send the user without
/// a platform underneath it.
typedef ExternalLauncher = Future<bool> Function(Uri uri);

final externalLauncherProvider =
    Provider<ExternalLauncher>((ref) => openExternalUri);

/// Opens [uri] outside the app — the browser for a policy page, the mail client
/// for support. Returns false when the platform has nothing that can handle it,
/// so the caller can say so instead of appearing to do nothing.
///
/// Android 11+ needs a matching `<queries>` entry in the manifest or this
/// always returns false; see `docs/INTEGRATIONS.md`.
Future<bool> openExternalUri(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme.isEmpty) return false;
  return openExternalUri(uri);
}
