import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dollchecker/core/l10n/labels.dart';
import 'package:dollchecker/features/child_profile/presentation/child_switcher.dart';
import 'package:dollchecker/features/collection/data/toy_repository.dart';
import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/collection/presentation/collection_screen.dart';
import 'package:dollchecker/features/development/data/development_repository.dart';
import 'package:dollchecker/features/missions/data/mission_repository.dart';
import 'package:dollchecker/features/missions/domain/mission.dart';
import 'package:dollchecker/features/missions/domain/mission_stats.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// The daily hook: three play missions for the selected child, the streak they
/// feed, and the toys due to come back out of the cupboard.
class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  Future<void> _setStatus(
    WidgetRef ref,
    Mission mission,
    MissionStatus status,
  ) async {
    await ref.read(missionRepositoryProvider).setStatus(mission.id, status);
    ref.invalidate(todaysMissionsProvider);
    ref.invalidate(missionStatsProvider);
    // Completing a mission stamps the toy's last-played date, which reorders
    // both the rotation list and tomorrow's mission selection.
    ref.invalidate(rotationSuggestionsProvider);
    ref.invalidate(collectionProvider);
    ref.invalidate(developmentSummaryProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final missions = ref.watch(todaysMissionsProvider);
    final stats = ref.watch(missionStatsProvider).valueOrNull;
    final rotation = ref.watch(rotationSuggestionsProvider).valueOrNull;
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.missions),
        actions: const [ChildSwitcherAction(), SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todaysMissionsProvider);
          ref.invalidate(missionStatsProvider);
          ref.invalidate(rotationSuggestionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (stats != null) StreakCard(stats: stats, today: today),
            const SizedBox(height: 16),
            Text(l.missionsToday,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            missions.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.analysisFailed),
              ),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.missionsEmpty, textAlign: TextAlign.center),
                    )
                  : Column(
                      children: [
                        _MissionProgress(missions: items),
                        const SizedBox(height: 8),
                        for (final mission in items)
                          MissionCard(
                            mission: mission,
                            onComplete: () => _setStatus(
                                ref, mission, MissionStatus.completed),
                            onSkip: () =>
                                _setStatus(ref, mission, MissionStatus.skipped),
                            onUndo: () =>
                                _setStatus(ref, mission, MissionStatus.pending),
                          ),
                      ],
                    ),
            ),
            if (stats != null && stats.badges.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(l.badges, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final badge in stats.badges)
                    Chip(
                      avatar: const Icon(Icons.emoji_events, size: 18),
                      label: Text(missionBadgeLabel(l, badge)),
                    ),
                ],
              ),
            ],
            if (rotation != null && rotation.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(l.toyRotation,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(l.toyRotationHint,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final toy in rotation) _RotationTile(toy: toy),
            ],
          ],
        ),
      ),
    );
  }
}

/// Streak, best streak, total, and a seven-day strip.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.stats, required this.today});

  final MissionStats stats;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final week = stats.recentDays(today);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  stats.currentStreak > 0 ? '🔥' : '🌱',
                  style: const TextStyle(fontSize: 34),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.streakDays(stats.currentStreak),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${l.longestStreak(stats.longestStreak)} · '
                        '${l.totalMissions(stats.totalCompleted)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l.thisWeek, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < week.length; i++)
                  _DayDot(
                    day: today.subtract(Duration(days: week.length - 1 - i)),
                    done: week[i],
                    color: scheme.primary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.done, required this.color});

  final DateTime day;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: done ? color : scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: done
              ? Icon(Icons.check, size: 18, color: scheme.onPrimary)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat.E(Localizations.localeOf(context).languageCode).format(day),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _MissionProgress extends StatelessWidget {
  const _MissionProgress({required this.missions});
  final List<Mission> missions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final done = missions.where((m) => m.isDone).length;
    final allHandled = missions.every((m) => !m.isOpen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: missions.isEmpty ? 0 : done / missions.length,
            minHeight: 8,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          allHandled && done == missions.length
              ? l.missionsAllDone
              : l.missionsProgress(done, missions.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    required this.onComplete,
    required this.onSkip,
    required this.onUndo,
  });

  final Mission mission;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settled = !mission.isOpen;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: mission.isDone ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  mission.isDone
                      ? Icons.check_circle
                      : mission.status == MissionStatus.skipped
                          ? Icons.remove_circle_outline
                          : Icons.radio_button_unchecked,
                  color: mission.isDone ? scheme.primary : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mission.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          decoration: mission.status == MissionStatus.skipped
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                  ),
                ),
              ],
            ),
            if (mission.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(mission.description,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (mission.durationMinutes != null)
                  _Meta(
                      icon: Icons.schedule,
                      text: l.duration(mission.durationMinutes!)),
                if (mission.skill != null)
                  _Meta(
                      icon: Icons.psychology,
                      text: skillLabel(l, mission.skill!)),
                if (mission.status == MissionStatus.skipped)
                  _Meta(icon: Icons.remove_circle_outline, text: l.missionSkipped),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (settled)
                  TextButton.icon(
                    onPressed: onUndo,
                    icon: const Icon(Icons.undo, size: 18),
                    label: Text(l.missionUndo),
                  )
                else ...[
                  FilledButton.tonalIcon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(l.missionComplete),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: onSkip, child: Text(l.missionSkip)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RotationTile extends StatelessWidget {
  const _RotationTile({required this.toy});
  final Toy toy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ToyThumbnail(path: toy.imagePath),
          ),
        ),
        title: Text(toy.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          toy.lastPlayedAt == null
              ? l.neverPlayed
              : l.lastPlayed(DateFormat.yMMMd().format(toy.lastPlayedAt!)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/toy/${toy.id}'),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
