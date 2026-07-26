import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/child_profile/presentation/child_form_sheet.dart';
import 'package:dollchecker/features/child_profile/presentation/child_switcher.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Manage every child profile: add, edit, delete, and pick the active one.
class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ChildProfile child,
    int total,
  ) async {
    final l = AppLocalizations.of(context);
    // The app's redirect guard requires at least one child, so the last one
    // cannot be removed.
    if (total <= 1) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.cannotDeleteLastChild)));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.deleteChild),
        content: Text(l.deleteChildConfirm(child.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(childRepositoryProvider).delete(child.id);
    if (ref.read(selectedChildIdProvider) == child.id) {
      ref.read(selectedChildIdProvider.notifier).state = null;
    }
    ref.invalidate(childrenProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final children = ref.watch(childrenProvider);
    final selectedId = ref.watch(selectedChildProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: Text(l.children)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showChildFormSheet(context),
        icon: const Icon(Icons.add),
        label: Text(l.addChild),
      ),
      body: children.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l.analysisFailed)),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            for (final child in items)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      child.name.isEmpty ? '?' : child.name.substring(0, 1),
                    ),
                  ),
                  title: Text(child.name),
                  subtitle: Text(childAgeLabel(l, child)),
                  onTap: () =>
                      ref.read(selectedChildIdProvider.notifier).state =
                          child.id,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (child.id == selectedId)
                        const Icon(Icons.check, color: Colors.green),
                      IconButton(
                        tooltip: l.editChild,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            showChildFormSheet(context, existing: child),
                      ),
                      IconButton(
                        tooltip: l.deleteChild,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _delete(context, ref, child, items.length),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
