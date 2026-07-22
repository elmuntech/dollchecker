import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/core/l10n/locale_controller.dart';
import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l.language,
                style: Theme.of(context).textTheme.titleSmall),
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: locale.languageCode,
            title: Text(l.english),
            onChanged: (v) =>
                ref.read(localeProvider.notifier).state = const Locale('en'),
          ),
          RadioListTile<String>(
            value: 'ru',
            groupValue: locale.languageCode,
            title: Text(l.russian),
            onChanged: (v) =>
                ref.read(localeProvider.notifier).state = const Locale('ru'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l.signOut),
            onTap: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ],
      ),
    );
  }
}
