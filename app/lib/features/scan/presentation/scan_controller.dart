import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dollchecker/core/l10n/locale_controller.dart';
import 'package:dollchecker/features/child_profile/child_profile.dart';
import 'package:dollchecker/features/collection/data/toy_repository.dart';
import 'package:dollchecker/features/development/data/development_repository.dart';
import 'package:dollchecker/features/missions/data/mission_repository.dart';
import 'package:dollchecker/features/play/data/play_repository.dart';
import 'package:dollchecker/features/profile/data/profile_repository.dart';
import 'package:dollchecker/features/scan/data/scan_repository.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

/// Drives the scan → analyze → result flow. `AsyncValue<ScanResult?>`:
/// null data = idle, loading = analyzing, error = failed/quota.
final scanControllerProvider =
    StateNotifierProvider<ScanController, AsyncValue<ScanResult?>>((ref) {
  return ScanController(ref);
});

class ScanController extends StateNotifier<AsyncValue<ScanResult?>> {
  ScanController(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<void> analyze({
    required Uint8List imageBytes,
    required String mediaType,
  }) async {
    state = const AsyncValue.loading();
    try {
      final child = _ref.read(selectedChildProvider);
      final locale = _ref.read(localeProvider).languageCode;
      final result = await _ref.read(scanRepositoryProvider).analyze(
            imageBytes: imageBytes,
            mediaType: mediaType,
            childProfileId: child?.id,
            locale: locale,
          );
      // A scan feeds every surface: history, the collection entry it folds
      // into, the development aggregate, the play ideas, and the quota.
      _ref.invalidate(historyProvider);
      _ref.invalidate(collectionProvider);
      _ref.invalidate(developmentSummaryProvider);
      _ref.invalidate(playIdeasProvider);
      _ref.invalidate(quotaProvider);
      // The first scan is what makes missions possible at all, so the empty
      // missions tab has to re-evaluate.
      _ref.invalidate(todaysMissionsProvider);
      _ref.invalidate(rotationSuggestionsProvider);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

/// History list provider.
final historyProvider = FutureProvider<List<ScanSummary>>((ref) async {
  return ref.watch(scanRepositoryProvider).history();
});

/// Reopen a stored scan by id.
final scanByIdProvider =
    FutureProvider.family<ScanResult, String>((ref, id) async {
  return ref.watch(scanRepositoryProvider).getScan(id);
});

/// Signed URL for a private image path.
final signedImageProvider =
    FutureProvider.family<String?, String?>((ref, path) async {
  return ref.watch(scanRepositoryProvider).signedImageUrl(path);
});
