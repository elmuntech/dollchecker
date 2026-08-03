import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/features/scan/presentation/result_view.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Reopen a stored scan by id (from history).
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.scanId});
  final String scanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scan = ref.watch(scanByIdProvider(scanId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: l.askAboutToy,
            onPressed: () => context.push('/chat/$scanId'),
          ),
        ],
      ),
      body: scan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l.analysisFailed)),
        data: (result) => ResultView(result: result),
      ),
    );
  }
}
