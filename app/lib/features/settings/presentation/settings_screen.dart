import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/core/l10n/locale_controller.dart';
import 'package:dollchecker/core/supabase/supabase.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/profile/data/profile_repository.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    final children = ref.watch(childrenProvider).valueOrNull ?? const [];
    final quota = ref.watch(quotaProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.child_care_outlined),
            title: Text(l.children),
            subtitle: Text(children.map((c) => c.name).join(', ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/children'),
          ),
          if (quota != null)
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(l.plan),
              subtitle: Text(
                quota.isPremium
                    ? '${l.planPremium} · ${l.unlimitedScans}'
                    : '${l.planFree} · ${l.scansLeft(quota.remaining ?? 0)}',
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child:
                Text(l.language, style: Theme.of(context).textTheme.titleSmall),
          ),
          RadioGroup<String>(
            groupValue: locale.languageCode,
            onChanged: (value) {
              if (value != null) {
                ref.read(localeProvider.notifier).state = Locale(value);
              }
            },
            child: Column(
              children: [
                RadioListTile<String>(value: 'en', title: Text(l.english)),
                RadioListTile<String>(value: 'ru', title: Text(l.russian)),
              ],
            ),
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
