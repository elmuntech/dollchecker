import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/paging/paged_list.dart';

void main() {
  group('first page', () {
    test('a full page means there may be more', () {
      final page = PagedList.first([1, 2, 3], pageSize: 3);
      expect(page.items, [1, 2, 3]);
      expect(page.hasMore, isTrue);
    });

    test('a short page is the end of the list', () {
      expect(PagedList.first([1, 2], pageSize: 3).hasMore, isFalse);
    });

    test('an empty first page is an empty list, not a pending one', () {
      final page = PagedList.first(<int>[], pageSize: 3);
      expect(page.isEmpty, isTrue);
      expect(page.hasMore, isFalse);
    });
  });

  group('append', () {
    test('adds the page and re-reads whether more remain', () {
      final page = PagedList.first([1, 2], pageSize: 2).append([3], pageSize: 2);
      expect(page.items, [1, 2, 3]);
      expect(page.hasMore, isFalse);
    });

    test('a full second page keeps the list open', () {
      final page =
          PagedList.first([1, 2], pageSize: 2).append([3, 4], pageSize: 2);
      expect(page.hasMore, isTrue);
      expect(page.length, 4);
    });
  });

  group('appendUnique', () {
    test('drops rows the window shifted into view twice', () {
      // A scan finishing between two requests pushes everything down one, so
      // offset paging hands back a row that is already on screen.
      final page = PagedList.first(['a', 'b'], pageSize: 2)
          .appendUnique(['b', 'c'], pageSize: 2, key: (s) => s);
      expect(page.items, ['a', 'b', 'c']);
    });

    test('a page that is entirely duplicates still leaves the list open', () {
      // Nothing new arrived, but the page was full — the list has not ended.
      final page = PagedList.first(['a', 'b'], pageSize: 2)
          .appendUnique(['a', 'b'], pageSize: 2, key: (s) => s);
      expect(page.items, ['a', 'b']);
      expect(page.hasMore, isTrue);
    });

    test('de-duplicates within the incoming page too', () {
      final page = PagedList.first(<String>[], pageSize: 3)
          .appendUnique(['a', 'a', 'b'], pageSize: 3, key: (s) => s);
      expect(page.items, ['a', 'b']);
    });
  });

  group('loading flag', () {
    test('marks and clears the in-flight state without touching the items', () {
      final page = PagedList.first([1], pageSize: 1);
      expect(page.isLoadingMore, isFalse);

      final loading = page.loading();
      expect(loading.isLoadingMore, isTrue);
      expect(loading.items, [1]);
      expect(loading.hasMore, isTrue);

      expect(loading.settled().isLoadingMore, isFalse);
    });
  });

  test('the empty list is empty and closed', () {
    final page = PagedList.empty<int>();
    expect(page.isEmpty, isTrue);
    expect(page.hasMore, isFalse);
  });
}
