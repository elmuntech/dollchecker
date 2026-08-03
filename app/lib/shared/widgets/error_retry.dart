import 'package:flutter/material.dart';

import 'package:dollchecker/l10n/app_localizations.dart';

/// What a screen shows when its data would not load.
///
/// The alternative the app used to have was an empty box: a failed request and
/// an empty collection looked identical, and there was nothing to press. A
/// failure is worth one line and one button.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    required this.onRetry,
    this.message,
    this.compact = false,
  });

  final VoidCallback onRetry;

  /// Defaults to the generic "could not load" line.
  final String? message;

  /// Inline version for a section inside a scrolling screen, rather than a
  /// whole empty page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: compact ? 28 : 40,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 8),
        Text(
          message ?? l.couldNotLoad,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l.retry),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.all(compact ? 16 : 32),
      child: compact ? content : Center(child: content),
    );
  }
}
