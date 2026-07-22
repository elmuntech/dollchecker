import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dollchecker/core/utils/image_input.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/scan/presentation/scan_controller.dart';
import 'package:dollchecker/l10n/app_localizations.dart';
import 'package:dollchecker/shared/widgets/safety_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _scan(
      BuildContext context, WidgetRef ref, ImageSource source) async {
    final picked = await pickAndCompress(source);
    if (picked == null || !context.mounted) return;
    ref.read(scanControllerProvider.notifier).analyze(
          imageBytes: picked.bytes,
          mediaType: picked.mediaType,
        );
    context.push('/analyzing');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final child = ref.watch(selectedChildProvider);
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(child == null ? l.appTitle : l.homeGreeting(child.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('📷', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 8),
                    Text(l.scanToy,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(l.scanHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _scan(context, ref, ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(l.takePhoto),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _scan(context, ref, ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(l.chooseFromGallery),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.history,
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.push('/history'),
                  child: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            history.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l.noScansYet)))
                  : Column(
                      children: [
                        for (final s in items.take(5))
                          Card(
                            child: ListTile(
                              leading: SafetyDot(level: s.safety),
                              title: Text(s.toyName.isEmpty ? '—' : s.toyName),
                              subtitle: s.educationalScore != null
                                  ? Text('${l.educationalValue}: '
                                      '${s.educationalScore}/100')
                                  : null,
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/scan/${s.scanId}'),
                            ),
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
