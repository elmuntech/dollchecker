import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/core/paging/paged_list.dart';
import 'package:dollchecker/features/history/presentation/history_screen.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';
import 'package:dollchecker/shared/widgets/error_retry.dart';

import '../../helpers.dart';

ScanSummary scan(String id, {String name = 'Blocks'}) => ScanSummary.fromRow({
      'id': id,
      'identification': {'name': name},
      'safety_overall': 'green',
      'educational_score': 80,
      'created_at': '2026-08-01T10:00:00Z',
    });

void main() {
  Future<void> pumpHistory(
    WidgetTester tester,
    PagedList<ScanSummary> page, {
    Locale locale = const Locale('en'),
  }) {
    return pumpApp(
      tester,
      const HistoryScreen(),
      locale: locale,
      overrides: [
        historyPageProvider.overrideWith(() => _StubHistory(page)),
      ],
    );
  }

  testWidgets('lists the scans it has', (tester) async {
    await pumpHistory(
      tester,
      PagedList.first([scan('1', name: 'Blocks'), scan('2', name: 'Rattle')],
          pageSize: 30),
    );
    expect(find.text('Blocks'), findsOneWidget);
    expect(find.text('Rattle'), findsOneWidget);
  });

  testWidgets('an empty history says so rather than showing nothing',
      (tester) async {
    await pumpHistory(tester, PagedList.empty<ScanSummary>());
    expect(find.textContaining('No scans yet'), findsOneWidget);
  });

  testWidgets('shows a footer while more pages remain', (tester) async {
    // A full page means the list continues, so the footer is the promise that
    // scrolling will fetch it.
    await pumpHistory(
      tester,
      PagedList(items: [scan('1')], hasMore: true),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('no footer once the list has ended', (tester) async {
    await pumpHistory(
      tester,
      PagedList(items: [scan('1')], hasMore: false),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failure offers a retry instead of an empty screen',
      (tester) async {
    await pumpApp(
      tester,
      const HistoryScreen(),
      overrides: [
        historyPageProvider.overrideWith(_FailingHistory.new),
      ],
    );
    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

class _StubHistory extends HistoryPageController {
  _StubHistory(this._page);
  final PagedList<ScanSummary> _page;

  @override
  Future<PagedList<ScanSummary>> build() async => _page;
}

class _FailingHistory extends HistoryPageController {
  @override
  Future<PagedList<ScanSummary>> build() async => throw Exception('offline');
}
