import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/core/l10n/locale_controller.dart';
import 'package:dollchecker/core/router/app_router.dart';
import 'package:dollchecker/core/theme/app_theme.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

class DollCheckerApp extends ConsumerWidget {
  const DollCheckerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}
