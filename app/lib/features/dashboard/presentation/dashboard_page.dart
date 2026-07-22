import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/core/l10n/labels.dart';
import 'package:dollchecker/features/scan/data/scan_repository.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/skill_bar.dart';

/// Aggregated development profile for the selected child.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  // Skills shown on the radar (kept to 8 for readability).
  static const _radarSkills = [
    'fine_motor',
    'gross_motor',
    'creativity',
    'problem_solving',
    'language',
    'logic',
    'social_emotional',
    'imagination',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final agg = ref.watch(skillAveragesProvider);

    return agg.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(l.analysisFailed)),
      data: (data) {
        if (data.scanCount == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.dashboardEmpty, textAlign: TextAlign.center),
            ),
          );
        }
        final entries = data.averages.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final strengths = entries.take(5).toList();
        final growth = entries.reversed.take(5).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(skillAveragesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.toysScanned(data.scanCount),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 260,
                    child: _Radar(averages: data.averages),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(l.strengths,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final e in strengths)
                SkillBar(label: skillLabel(l, e.key), score: e.value.round()),
              const SizedBox(height: 20),
              Text(l.growthAreas,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final e in growth)
                SkillBar(label: skillLabel(l, e.key), score: e.value.round()),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _Radar extends StatelessWidget {
  const _Radar({required this.averages});
  final Map<String, double> averages;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final skills = DashboardPage._radarSkills;

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        tickCount: 4,
        ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
        radarBorderData: BorderSide(color: Colors.grey.withOpacity(0.3)),
        gridBorderData: BorderSide(color: Colors.grey.withOpacity(0.2)),
        tickBorderData: BorderSide(color: Colors.grey.withOpacity(0.2)),
        titleTextStyle: const TextStyle(fontSize: 10),
        getTitle: (index, angle) =>
            RadarChartTitle(text: skillLabel(l, skills[index])),
        dataSets: [
          // Phantom set to fix the scale to 0..100.
          RadarDataSet(
            dataEntries: [for (final _ in skills) const RadarEntry(value: 100)],
            borderColor: Colors.transparent,
            fillColor: Colors.transparent,
            entryRadius: 0,
            borderWidth: 0,
          ),
          RadarDataSet(
            dataEntries: [
              for (final s in skills) RadarEntry(value: averages[s] ?? 0),
            ],
            borderColor: primary,
            fillColor: primary.withOpacity(0.2),
            borderWidth: 2,
            entryRadius: 2,
          ),
        ],
      ),
    );
  }
}
