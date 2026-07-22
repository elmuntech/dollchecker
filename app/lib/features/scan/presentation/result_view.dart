import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/core/l10n/labels.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/safety_badge.dart';
import 'package:dollchecker/shared/widgets/score_gauge.dart';
import 'package:dollchecker/shared/widgets/skill_bar.dart';

class ResultView extends ConsumerWidget {
  const ResultView({super.key, required this.result});
  final ScanResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final a = result.analysis;
    final ident = a.identification;
    final skills = [...a.development.skills]
      ..sort((x, y) => y.score.compareTo(x.score));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Image
        if (result.imagePath != null)
          _SignedImage(path: result.imagePath!),

        // Identification header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ident.name.isEmpty ? '—' : ident.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                [
                  if (ident.brand.isNotEmpty && ident.brand != 'unknown')
                    ident.brand,
                  if (ident.category.isNotEmpty) ident.category,
                ].join(' · '),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Chip('${l.ageRecommendation}: ${a.age.label}'),
                  if (a.materials.isNotEmpty)
                    _Chip('${l.materials}: ${a.materials.join(', ')}'),
                ],
              ),
            ],
          ),
        ),

        // Safety
        SafetyBadge(level: a.safety.overall, score: a.safety.score),
        const SizedBox(height: 8),
        _Section(
          title: l.hazards,
          child: a.safety.hazards.isEmpty
              ? Text(l.noHazards)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final h in a.safety.hazards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${hazardLabel(l, h.type)} · ${h.severity}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(h.description),
                                  if (h.recommendation.isNotEmpty)
                                    Text('→ ${h.recommendation}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (a.safety.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(a.safety.summary),
          ),

        // Educational value
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ScoreGauge(
                    score: a.development.educationalScore,
                    label: l.educationalValue),
                const SizedBox(width: 16),
                Expanded(child: Text(a.development.educationalSummary)),
              ],
            ),
          ),
        ),

        // Development skills
        _Section(
          title: l.development,
          child: Column(
            children: [
              for (final s in skills.take(10))
                SkillBar(label: skillLabel(l, s.skill), score: s.score),
            ],
          ),
        ),

        // Play ideas
        _Section(
          title: l.playIdeas,
          child: Column(
            children: [
              for (final idea in a.playIdeas)
                Card(
                  child: ListTile(
                    title: Text(idea.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(idea.description),
                        const SizedBox(height: 4),
                        Text(
                          [
                            difficultyLabel(l, idea.difficulty),
                            if (idea.durationMinutes > 0)
                              l.duration(idea.durationMinutes),
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Disclaimer
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(a.safety.disclaimer,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _SignedImage extends ConsumerWidget {
  const _SignedImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signedImageProvider(path));
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: url.when(
          loading: () => Container(color: Colors.black12),
          error: (_, __) => Container(color: Colors.black12),
          data: (u) => u == null
              ? Container(color: Colors.black12)
              : Image.network(u, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
