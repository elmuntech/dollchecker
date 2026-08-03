import 'package:flutter/material.dart';

import 'package:dollchecker/l10n/app_localizations.dart';

/// The end of a paged list while more remains.
///
/// A spinner only while a page is actually in flight — one that turns whenever
/// there is more to fetch would claim the app is working when it is idle. The
/// rest of the time it is a button, which also covers the case where the scroll
/// listener never fires because everything already fits on screen.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({
    super.key,
    required this.loading,
    required this.onLoadMore,
  });

  final bool loading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(onPressed: onLoadMore, child: Text(l.loadMore)),
      ),
    );
  }
}

/// Calls [onEndApproached] when a scroll position gets near its end.
///
/// The threshold is generous on purpose: fetching only at the very bottom
/// means the list visibly stops before it continues.
class EndOfListLoader {
  EndOfListLoader(this.controller, this.onEndApproached) {
    controller.addListener(_onScroll);
  }

  final ScrollController controller;
  final VoidCallback onEndApproached;

  void _onScroll() {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      onEndApproached();
    }
  }

  void dispose() => controller.removeListener(_onScroll);
}
