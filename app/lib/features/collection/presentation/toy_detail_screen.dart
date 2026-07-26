import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dollchecker/features/collection/data/toy_repository.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/collection/presentation/collection_screen.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/safety_badge.dart';

/// One collection entry: its latest verdict plus every scan recorded for it.
class ToyDetailScreen extends ConsumerWidget {
  const ToyDetailScreen({super.key, required this.toyId});
  final String toyId;

  Future<void> _remove(BuildContext context, WidgetRef ref, Toy toy) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.removeToy),
        content: Text(l.removeToyConfirm(toy.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(toyRepositoryProvider).delete(toy.id);
    ref.invalidate(collectionProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.toyRemoved)));
    context.pop();
  }

  Future<void> _toggleOwned(WidgetRef ref, Toy toy) async {
    await ref.read(toyRepositoryProvider).setOwned(toy.id, !toy.owned);
    ref.invalidate(toyProvider(toy.id));
    ref.invalidate(collectionProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final toy = ref.watch(toyProvider(toyId));

    return Scaffold(
      appBar: AppBar(
        title: Text(toy.valueOrNull?.name ?? l.collection),
        actions: [
          if (toy.valueOrNull != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                final loaded = toy.value!;
                if (value == 'owned') _toggleOwned(ref, loaded);
                if (value == 'remove') _remove(context, ref, loaded);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'owned',
                  child: Text(toy.value!.owned
                      ? l.moveToWishlist
                      : l.moveToCollection),
                ),
                PopupMenuItem(value: 'remove', child: Text(l.removeToy)),
              ],
            ),
        ],
      ),
      body: toy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l.analysisFailed)),
        data: (data) => _ToyBody(toy: data),
      ),
    );
  }
}

class _ToyBody extends ConsumerWidget {
  const _ToyBody({required this.toy});
  final Toy toy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scans = ref.watch(toyScansProvider(toy.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 200, child: ToyThumbnail(path: toy.imagePath)),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(toy.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    if (toy.brand != null || toy.category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [toy.brand, toy.category]
                            .whereType<String>()
                            .join(' · '),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SafetyChip(level: toy.safety),
                        if (toy.educationalScore != null)
                          Chip(
                            label: Text(
                                '${l.educationalValue}: ${toy.educationalScore}/100'),
                          ),
                        Chip(label: Text(l.scannedTimes(toy.scanCount))),
                        Chip(
                          label: Text(
                              toy.owned ? l.filterOwned : l.filterWishlist),
                        ),
                      ],
                    ),
                    if (toy.lastScannedAt != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        l.lastScanned(
                            DateFormat.yMMMd().format(toy.lastScannedAt!)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (toy.lastScanId != null) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/scan/${toy.lastScanId}'),
                        icon: const Icon(Icons.description_outlined),
                        label: Text(l.openLatestScan),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(l.toyScans, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        scans.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Text(l.analysisFailed),
          data: (items) => items.isEmpty
              ? Text(l.noScansYet)
              : Column(
                  children: [
                    for (final scan in items)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: SafetyDot(level: scan.safety),
                          title:
                              Text(DateFormat.yMMMd().format(scan.createdAt)),
                          trailing: scan.educationalScore != null
                              ? Text('${scan.educationalScore}/100')
                              : null,
                          onTap: () => context.push('/scan/${scan.scanId}'),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
