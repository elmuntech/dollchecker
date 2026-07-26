import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/l10n/locale_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Wraps [child] in the providers, localizations and Material scaffolding that
/// every screen in the app assumes.
Widget wrapApp(
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
}

/// Pumps [child] and settles the localization delegates.
///
/// Pass [surfaceSize] for screens whose content is taller than the default
/// 800px test window — a lazy [ListView] never builds its off-screen children,
/// so sections below the fold would otherwise be unfindable.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    wrapApp(child, overrides: overrides, locale: locale),
  );
  await tester.pumpAndSettle();
}
