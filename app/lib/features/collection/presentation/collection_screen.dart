import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/features/collection/data/toy_repository.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/error_retry.dart';
import 'package:dollchecker/shared/widgets/load_more_footer.dart';
import 'package:dollchecker/shared/widgets/safety_badge.dart';

/// Every toy the user has scanned, deduplicated into one entry per toy.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late final EndOfListLoader _loader;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(collectionSearchProvider);
    _loader = EndOfListLoader(
      _scroll,
      () => ref.read(collectionProvider.notifier).loadMore(),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final toys = ref.watch(collectionProvider);
    final filter = ref.watch(collectionFilterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.collection)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (v) =>
                  ref.read(collectionSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: l.searchToys,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          ref.read(collectionSearchProvider.notifier).state = '';
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                for (final entry in <(CollectionFilter, String)>[
                  (CollectionFilter.all, l.filterAll),
                  (CollectionFilter.owned, l.filterOwned),
                  (CollectionFilter.wishlist, l.filterWishlist),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: filter == entry.$1,
                      onSelected: (_) => ref
                          .read(collectionFilterProvider.notifier)
                          .state = entry.$1,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(collectionProvider),
              child: toys.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
              ErrorRetry(onRetry: () => ref.invalidate(collectionProvider)),
                data: (page) {
                  if (page.isEmpty) {
                    final noFilters = filter == CollectionFilter.all &&
                        ref.read(collectionSearchProvider).trim().isEmpty;
                    return _CenteredMessage(
                      text:
                          noFilters ? l.collectionEmpty : l.collectionNoMatches,
                    );
                  }
                  // A grid cannot hold a full-width footer, so the footer is a
                  // sliver of its own below the grid rather than a final tile.
                  return CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        sliver: SliverGrid.builder(
                          gridDelegate: _gridDelegate,
                          itemCount: page.length,
                          itemBuilder: (context, i) =>
                              _ToyCard(toy: page.items[i]),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: page.hasMore
                            ? LoadMoreFooter(
                                loading: page.isLoadingMore,
                                onLoadMore: () => ref
                                    .read(collectionProvider.notifier)
                                    .loadMore(),
                              )
                            : const SizedBox(height: 24),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two columns on phones, more on tablets, with cards tall enough for the
/// image plus two lines of text.
const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 0.72,
);

class _ToyCard extends ConsumerWidget {
  const _ToyCard({required this.toy});
  final Toy toy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/toy/${toy.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ToyThumbnail(path: toy.imagePath)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    toy.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    toy.brand ?? (toy.category ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SafetyDot(level: toy.safety),
                      const SizedBox(width: 8),
                      if (toy.educationalScore != null)
                        Text('${toy.educationalScore}/100',
                            style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      if (!toy.owned)
                        Tooltip(
                          message: l.filterWishlist,
                          child: const Icon(Icons.favorite_border, size: 16),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toy images live in a private bucket, so they load through a signed URL.
class ToyThumbnail extends ConsumerWidget {
  const ToyThumbnail({super.key, required this.path});
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Text('🧸', style: TextStyle(fontSize: 32)),
    );
    if (path == null) return placeholder;

    final url = ref.watch(signedImageProvider(path));
    return url.when(
      loading: () => placeholder,
      error: (_, __) => placeholder,
      data: (value) => value == null
          ? placeholder
          : Image.network(
              value,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
            ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
