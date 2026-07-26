import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/child_profile/presentation/child_form_sheet.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Localized age string for a child ("18 months" / "Age not set").
String childAgeLabel(AppLocalizations l, ChildProfile child) {
  final months = child.ageMonths;
  return months == null ? l.ageUnknown : l.ageInMonths(months);
}

/// App-bar action that shows the active child and opens the switcher.
/// Renders nothing when the user has a single child — there is nothing to pick.
class ChildSwitcherAction extends ConsumerWidget {
  const ChildSwitcherAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider).valueOrNull ?? const [];
    final selected = ref.watch(selectedChildProvider);
    if (children.length < 2 || selected == null) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: () => showChildSwitcher(context, ref),
      icon: const Icon(Icons.expand_more, size: 18),
      label: Text(selected.name, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Bottom sheet listing every child, plus an "add child" entry.
Future<void> showChildSwitcher(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final children = ref.read(childrenProvider).valueOrNull ?? const [];
  final selectedId = ref.read(selectedChildProvider)?.id;

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Text(l.switchChild,
                    style: Theme.of(sheetContext).textTheme.titleMedium),
              ],
            ),
          ),
          for (final child in children)
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  child.name.isEmpty ? '?' : child.name.substring(0, 1),
                ),
              ),
              title: Text(child.name),
              subtitle: Text(childAgeLabel(l, child)),
              trailing: child.id == selectedId
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                ref.read(selectedChildIdProvider.notifier).state = child.id;
                Navigator.of(sheetContext).pop();
              },
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(l.addChild),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final created = await showChildFormSheet(context);
              if (created != null) {
                ref.read(selectedChildIdProvider.notifier).state = created.id;
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
