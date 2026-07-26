import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/core/l10n/labels.dart';
import 'package:dollchecker/features/child_profile/presentation/child_switcher.dart';
import 'package:dollchecker/features/development/data/development_repository.dart';
import 'package:dollchecker/features/development/domain/development_summary.dart';
import 'package:dollchecker/features/development/presentation/skill_radar.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/score_gauge.dart';
import 'package:dollchecker/shared/widgets/skill_bar.dart';

/// Aggregates every scan for the selected child into one picture of what the
/// child's toys develop — and what they miss.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final summary = ref.watch(developmentSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.developmentDashboard),
        actions: const [ChildSwitcherAction(), SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(developmentSummaryProvider),
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ErrorState(
            onRetry: () => ref.invalidate(developmentSummaryProvider),
          ),
          data: (data) =>
              data.isEmpty ? const _EmptyState() : _DashboardBody(data: data),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});
  final DevelopmentSummary data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final groups = data.groups;
    final hasRadarData = groups.any((g) => g.avgScore > 0);
    final uncovered = data.uncoveredSkills;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ScoreGauge(score: data.overallIndex, label: l.developmentIndex),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.basedOnScans(data.scanCount),
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        '${l.strengths}: '
                        '${skillLabel(l, data.skills.first.skill)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasRadarData) ...[
          const SizedBox(height: 16),
          _Section(
            title: l.skillBalance,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SkillRadar(groups: groups),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Section(
          title: l.strengths,
          child: Column(
            children: [
              for (final skill in data.strengths()) _SkillRow(summary: skill),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: l.gaps,
          subtitle: l.gapsHint,
          child: Column(
            children: [
              for (final skill in data.gaps()) _SkillRow(summary: skill),
            ],
          ),
        ),
        if (uncovered.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: l.notMeasuredYet,
            subtitle: l.notMeasuredHint,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final skill in uncovered)
                  Chip(label: Text(skillLabel(l, skill))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.summary});
  final SkillSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: () => showSkillDetailSheet(context, summary),
      borderRadius: BorderRadius.circular(10),
      child: SkillBar(
        label: skillLabel(l, summary.skill),
        score: summary.avgScore.round(),
      ),
    );
  }
}

/// Shows which toys drive a skill, with the coaching tip from the best one.
Future<void> showSkillDetailSheet(
  BuildContext context,
  SkillSummary summary,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SkillDetailSheet(summary: summary),
  );
}

class _SkillDetailSheet extends ConsumerWidget {
  const _SkillDetailSheet({required this.summary});
  final SkillSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final highlights = ref.watch(skillHighlightsProvider(summary.skill));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(skillLabel(l, summary.skill),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l.basedOnScans(summary.scanCount),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            SkillBar(
              label: l.developmentIndex,
              score: summary.avgScore.round(),
            ),
            const SizedBox(height: 16),
            Text(l.bestToysForSkill,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            highlights.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Text(l.analysisFailed),
              data: (items) => items.isEmpty
                  ? Text(l.noHighlights)
                  : Column(
                      children: [
                        for (final item in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                item.toyName.isEmpty ? '—' : item.toyName),
                            subtitle: item.howToMaximize.isEmpty
                                ? null
                                : Text(item.howToMaximize),
                            trailing: Text('${item.score}'),
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/scan/${item.scanId}');
                            },
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
          child: Column(
            children: [
              const Text('📊', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text(l.developmentEmpty, textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
          child: Column(
            children: [
              Text(l.analysisFailed, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(l.retry)),
            ],
          ),
        ),
      ],
    );
  }
}
