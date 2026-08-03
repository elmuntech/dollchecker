import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dollchecker/features/scan/domain/toy_analysis.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/error_retry.dart';
import 'package:dollchecker/shared/widgets/safety_badge.dart';

/// Every scan ever made, newest first, loaded a page at a time as the list is
/// scrolled — a family that scans often should not stop seeing their history at
/// an arbitrary cutoff.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// Fetches the next page a little before the end, so the list rarely stops.
  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(historyPageProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final history = ref.watch(historyPageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.history)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(historyPageProvider),
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorRetry(
            onRetry: () => ref.invalidate(historyPageProvider),
          ),
          data: (page) => page.isEmpty
              ? Center(child: Text(l.noScansYet))
              : ListView.builder(
                  controller: _controller,
                  padding: const EdgeInsets.all(16),
                  // One extra row for the footer while more is on its way.
                  itemCount: page.length + (page.hasMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= page.length) {
                      return _LoadMoreFooter(
                        loading: page.isLoadingMore,
                        onLoadMore: () =>
                            ref.read(historyPageProvider.notifier).loadMore(),
                      );
                    }
                    return _HistoryRow(scan: page.items[i]);
                  },
                ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.scan});
  final ScanSummary scan;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: SafetyDot(level: scan.safety),
        title: Text(scan.toyName.isEmpty ? '—' : scan.toyName),
        subtitle: Text(DateFormat.yMMMd().format(scan.createdAt)),
        trailing: scan.educationalScore != null
            ? Text('${scan.educationalScore}/100')
            : null,
        onTap: () => context.push('/scan/${scan.scanId}'),
      ),
    );
  }
}

/// The end of the list while more remains.
///
/// A spinner only while a page is actually in flight — one that turns whenever
/// there is more to fetch would claim the app is working when it is idle. The
/// rest of the time it is a button, which also covers the case where the scroll
/// listener never fires because everything already fits on screen.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.loading, required this.onLoadMore});

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
