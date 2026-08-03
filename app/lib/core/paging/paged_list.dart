/// A list that arrives one page at a time.
///
/// Every list in the app used to be a single query with a hard `limit`, which
/// is silent truncation: a family with more toys than the limit simply never
/// saw the rest, and nothing said so. This carries the one extra fact that
/// makes that visible — whether there is more to fetch.
class PagedList<T> {
  PagedList({
    required List<T> items,
    required this.hasMore,
    this.isLoadingMore = false,
  }) : items = List.unmodifiable(items);

  final List<T> items;

  /// Whether the last page came back full. A short page means the end.
  final bool hasMore;

  /// True while the next page is in flight, so the UI can show a footer
  /// spinner without confusing it with the initial load.
  final bool isLoadingMore;

  static PagedList<T> empty<T>() => PagedList<T>(items: const [], hasMore: false);

  bool get isEmpty => items.isEmpty;
  int get length => items.length;

  /// The first page of a list whose page size is [pageSize].
  factory PagedList.first(List<T> page, {required int pageSize}) =>
      PagedList<T>(items: page, hasMore: page.length >= pageSize);

  /// Appends a freshly loaded page.
  ///
  /// Pages are appended blindly rather than merged: an offset-based query can
  /// return a row twice if something was inserted between requests, and the
  /// caller that cares about identity (`appendUnique`) says so.
  PagedList<T> append(List<T> page, {required int pageSize}) => PagedList<T>(
        items: [...items, ...page],
        hasMore: page.length >= pageSize,
      );

  /// Appends a page, dropping anything already present by [key]. Guards the
  /// one case offset paging cannot: a new row shifting the window.
  PagedList<T> appendUnique(
    List<T> page, {
    required int pageSize,
    required Object Function(T) key,
  }) {
    final seen = items.map(key).toSet();
    return PagedList<T>(
      items: [...items, ...page.where((item) => seen.add(key(item)))],
      // Emptiness after de-duplication is not the end of the list — the page
      // itself is what says whether more exist.
      hasMore: page.length >= pageSize,
    );
  }

  PagedList<T> loading() =>
      PagedList<T>(items: items, hasMore: hasMore, isLoadingMore: true);

  PagedList<T> settled() =>
      PagedList<T>(items: items, hasMore: hasMore, isLoadingMore: false);
}
