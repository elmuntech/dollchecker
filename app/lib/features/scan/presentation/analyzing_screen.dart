import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/core/errors/rate_limited.dart';
import 'package:dollchecker/features/scan/data/scan_repository.dart';
import 'package:dollchecker/features/scan/presentation/result_view.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Shows the live scan state: analyzing → result (or error). Reads the
/// controller populated by HomeScreen before navigation.
class AnalyzingScreen extends ConsumerWidget {
  const AnalyzingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(scanControllerProvider);

    return state.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(l.analyzing,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(l.analyzingHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('😕', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  e is RateLimitedException
                      ? l.rateLimited
                      : e is QuotaExceededException
                          ? l.quotaExceeded
                      : l.analysisFailed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    ref.read(scanControllerProvider.notifier).reset();
                    context.pop();
                  },
                  child: const Icon(Icons.arrow_back),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (result) {
        if (result == null) {
          // Nothing to show (came here without a pending scan).
          return Scaffold(appBar: AppBar());
        }
        return Scaffold(
          appBar: AppBar(title: Text(result.analysis.identification.name)),
          body: ResultView(result: result),
        );
      },
    );
  }
}
