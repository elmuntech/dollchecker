import 'package:flutter/material.dart';

/// A labeled 0–100 horizontal skill bar.
class SkillBar extends StatelessWidget {
  const SkillBar({super.key, required this.label, required this.score});
  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      const Color(0xFFBDBDBD),
      Theme.of(context).colorScheme.primary,
      (score / 100).clamp(0, 1),
    )!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
              Text('$score',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
