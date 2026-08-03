import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/paging/paged_list.dart';
import 'package:dollchecker/features/collection/data/toy_repository.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/collection/presentation/collection_screen.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';

import '../../helpers.dart';

Toy toy(String name, {bool owned = true, String? image}) => Toy.fromRow({
      'id': 'toy-$name',
      'name': name,
      'brand': 'Hape',
      'category': 'blocks',
      'primary_image_url': image,
      'owned': owned,
      'scan_count': 2,
      'latest_safety': 'green',
      'latest_educational_score': 80,
    });

void main() {
  Future<void> pumpCollection(
    WidgetTester tester,
    List<Toy> toys, {
    Locale locale = const Locale('en'),
    bool hasMore = false,
    _StubCollection? stub,
  }) {
    return pumpApp(
      tester,
      const CollectionScreen(),
      locale: locale,
      overrides: [
        collectionProvider.overrideWith(
          () =>
              stub ?? _StubCollection(PagedList(items: toys, hasMore: hasMore)),
        ),
        // Images live in a private bucket; the signed URL needs a live client.
        signedImageProvider.overrideWith((ref, arg) async => null),
      ],
    );
  }

  testWidgets('empty collection explains where toys come from', (tester) async {
    await pumpCollection(tester, const []);
    expect(find.textContaining('Your collection is empty'), findsOneWidget);
  });

  testWidgets('renders a card per toy with its scores', (tester) async {
    await pumpCollection(tester, [toy('Blocks'), toy('Rattle')]);
    expect(find.text('Blocks'), findsOneWidget);
    expect(find.text('Rattle'), findsOneWidget);
    expect(find.text('80/100'), findsNWidgets(2));
  });

  testWidgets('offers all / owned / wishlist filters', (tester) async {
    await pumpCollection(tester, [toy('Blocks')]);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Owned'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);
  });

  testWidgets('selecting a filter updates the provider', (tester) async {
    await pumpCollection(tester, [toy('Blocks')]);
    await tester.tap(find.text('Wishlist'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CollectionScreen)),
    );
    expect(container.read(collectionFilterProvider), CollectionFilter.wishlist);
  });

  testWidgets('typing in the search box updates the provider', (tester) async {
    await pumpCollection(tester, [toy('Blocks')]);
    await tester.enterText(find.byType(TextField), 'lego');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CollectionScreen)),
    );
    expect(container.read(collectionSearchProvider), 'lego');
  });

  testWidgets('a toy with an image path still renders without a client',
      (tester) async {
    await pumpCollection(tester, [toy('Blocks', image: 'user-1/a.jpg')]);
    expect(find.text('Blocks'), findsOneWidget);
  });

  testWidgets('offers the next page instead of stopping at a hidden cap',
      (tester) async {
    await pumpCollection(tester, [toy('Blocks')], hasMore: true);
    expect(find.text('Load more'), findsOneWidget);
    // Idle, not loading — the footer must not claim the app is busy.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no footer once the collection has ended', (tester) async {
    await pumpCollection(tester, [toy('Blocks')]);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('tapping the footer asks for the next page', (tester) async {
    final stub = _StubCollection(
      PagedList(items: [toy('Blocks')], hasMore: true),
    );
    await pumpCollection(tester, const [], stub: stub);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(stub.loadMoreCalls, 1);
  });

  testWidgets('renders in Russian', (tester) async {
    await pumpCollection(tester, [toy('Blocks')],
        locale: const Locale('ru'));
    expect(find.text('Коллекция'), findsOneWidget);
    expect(find.text('Хочу купить'), findsOneWidget);
  });
}

class _StubCollection extends CollectionPageController {
  _StubCollection(this._page);
  final PagedList<Toy> _page;

  int loadMoreCalls = 0;

  @override
  Future<PagedList<Toy>> build() async => _page;

  @override
  Future<void> loadMore() async => loadMoreCalls++;
}
