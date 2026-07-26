import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dollchecker/core/domain/skills.dart';
import 'package:dollchecker/core/l10n/labels.dart';
import 'package:dollchecker/features/child_profile/presentation/child_switcher.dart';
import 'package:dollchecker/features/play/data/play_repository.dart';
import 'package:dollchecker/features/play/domain/play_idea_entry.dart';
import 'package:dollchecker/l10n/app_localizations.dart';

/// Every play idea the analyzer has produced, filterable and favoritable.
class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  Future<void> _toggleFavorite(WidgetRef ref, PlayIdeaEntry idea) async {
    await ref
        .read(playRepositoryProvider)
        .setFavorite(idea.id, !idea.isFavorited);
    ref.invalidate(playIdeasProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ideas = ref.watch(playIdeasProvider);
    final favoritesOnly = ref.watch(playFavoritesOnlyProvider);
    final skillFilter = ref.watch(playSkillFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.playCoach),
        actions: const [ChildSwitcherAction(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                FilterChip(
                  label: Text(l.favoritesOnly),
                  avatar: const Icon(Icons.star, size: 18),
                  selected: favoritesOnly,
                  onSelected: (v) =>
                      ref.read(playFavoritesOnlyProvider.notifier).state = v,
                ),
                const SizedBox(width: 8),
                _SkillFilterChip(selected: skillFilter),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(playIdeasProvider),
              child: ideas.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _Message(text: l.analysisFailed),
                data: (items) {
                  if (items.isEmpty) {
                    final filtered = favoritesOnly || skillFilter != null;
                    return _Message(
                        text: filtered ? l.playNoMatches : l.playEmpty);
                  }
                  final featured = ideaOfTheDay(items, DateTime.now());
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (featured != null) ...[
                        Text(l.ideaOfTheDay,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _IdeaCard(
                          idea: featured,
                          highlighted: true,
                          onFavorite: () => _toggleFavorite(ref, featured),
                        ),
                        const SizedBox(height: 20),
                        Text(l.playIdeas,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                      ],
                      for (final idea in items)
                        _IdeaCard(
                          idea: idea,
                          onFavorite: () => _toggleFavorite(ref, idea),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A skill picked in the filter sheet; `skill == null` means "any skill".
class _SkillChoice {
  const _SkillChoice(this.skill);
  final String? skill;
}

class _SkillFilterChip extends ConsumerWidget {
  const _SkillFilterChip({required this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return ActionChip(
      avatar: const Icon(Icons.filter_list, size: 18),
      label: Text(selected == null ? l.anySkill : skillLabel(l, selected!)),
      onPressed: () async {
        // Wrapped in _SkillChoice so a dismissed sheet (null) is distinct from
        // an explicit "Any skill" pick (a choice holding null).
        final picked = await showModalBottomSheet<_SkillChoice>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(l.anySkill),
                  trailing: selected == null ? const Icon(Icons.check) : null,
                  onTap: () =>
                      Navigator.of(sheetContext).pop(const _SkillChoice(null)),
                ),
                const Divider(height: 1),
                for (final skill in kSkillKeys)
                  ListTile(
                    title: Text(skillLabel(l, skill)),
                    trailing:
                        skill == selected ? const Icon(Icons.check) : null,
                    onTap: () =>
                        Navigator.of(sheetContext).pop(_SkillChoice(skill)),
                  ),
              ],
            ),
          ),
        );
        if (picked == null) return;
        ref.read(playSkillFilterProvider.notifier).state = picked.skill;
      },
    );
  }
}

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({
    required this.idea,
    required this.onFavorite,
    this.highlighted = false,
  });

  final PlayIdeaEntry idea;
  final VoidCallback onFavorite;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: highlighted ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(idea.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: idea.isFavorited
                      ? l.removeFromFavorites
                      : l.addToFavorites,
                  icon: Icon(
                      idea.isFavorited ? Icons.star : Icons.star_border),
                  onPressed: onFavorite,
                ),
              ],
            ),
            if (idea.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(idea.description,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (idea.durationMinutes != null)
                  _Meta(
                      icon: Icons.schedule,
                      text: l.duration(idea.durationMinutes!)),
                _Meta(
                    icon: Icons.speed,
                    text: difficultyLabel(l, idea.difficulty)),
                for (final skill in idea.skillsTargeted.take(3))
                  _Meta(icon: Icons.psychology, text: skillLabel(l, skill)),
              ],
            ),
            if (idea.toyName.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => context.push('/scan/${idea.scanId}'),
                child: Text(
                  l.fromToy(idea.toyName),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
        ),
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

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
