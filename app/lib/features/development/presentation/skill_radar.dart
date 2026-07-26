import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:dollchecker/core/l10n/labels.dart';
import 'package:dollchecker/features/development/domain/development_summary.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Six-axis radar of the developmental domains. Twenty individual skills would
/// be unreadable as axes, so the dashboard plots the rolled-up groups instead.
class SkillRadar extends StatelessWidget {
  const SkillRadar({super.key, required this.groups});

  final List<GroupSummary> groups;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 1.15,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          radarBackgroundColor: Colors.transparent,
          radarBorderData: BorderSide(color: scheme.outlineVariant),
          gridBorderData: BorderSide(color: scheme.outlineVariant, width: 1),
          tickBorderData: const BorderSide(color: Colors.transparent),
          tickCount: 4,
          // The axis labels carry the meaning; numeric ticks just add noise.
          ticksTextStyle:
              const TextStyle(color: Colors.transparent, fontSize: 10),
          titleTextStyle: Theme.of(context).textTheme.labelMedium,
          titlePositionPercentageOffset: 0.18,
          getTitle: (index, angle) => RadarChartTitle(
            text: skillGroupLabel(l, groups[index].group),
          ),
          dataSets: [
            RadarDataSet(
              fillColor: scheme.primary.withValues(alpha: 0.22),
              borderColor: scheme.primary,
              borderWidth: 2,
              entryRadius: 2.5,
              dataEntries: [
                for (final group in groups) RadarEntry(value: group.avgScore),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
