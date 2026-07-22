import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dollchecker/features/scan/presentation/scan_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/safety_badge.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.history)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(historyProvider),
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text(l.analysisFailed)),
          data: (items) => items.isEmpty
              ? Center(child: Text(l.noScansYet))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final s = items[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: SafetyDot(level: s.safety),
                        title: Text(s.toyName.isEmpty ? '—' : s.toyName),
                        subtitle: Text(DateFormat.yMMMd().format(s.createdAt)),
                        trailing: s.educationalScore != null
                            ? Text('${s.educationalScore}/100')
                            : null,
                        onTap: () => context.push('/scan/${s.scanId}'),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
