import 'package:flutter/material.dart';

import 'package:dollchecker/core/theme/app_theme.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

/// Small colored dot used in list rows.
class SafetyDot extends StatelessWidget {
  const SafetyDot({super.key, required this.level});
  final SafetyLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      SafetyLevel.green => AppTheme.safetyGreen,
      SafetyLevel.yellow => AppTheme.safetyYellow,
      SafetyLevel.red => AppTheme.safetyRed,
      SafetyLevel.unknown => Colors.grey,
    };
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class SafetyBadge extends StatelessWidget {
  const SafetyBadge({super.key, required this.level, required this.score});
  final SafetyLevel level;
  final int score;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (color, label, icon) = switch (level) {
      SafetyLevel.green => (AppTheme.safetyGreen, l.safetyGreen, Icons.check_circle),
      SafetyLevel.yellow => (AppTheme.safetyYellow, l.safetyYellow, Icons.warning_amber_rounded),
      SafetyLevel.red => (AppTheme.safetyRed, l.safetyRed, Icons.dangerous),
      SafetyLevel.unknown => (Colors.grey, '—', Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.safety,
                    style: Theme.of(context).textTheme.labelMedium),
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$score',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w800)),
              Text('/100', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
