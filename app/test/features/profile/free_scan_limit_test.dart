import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/profile/data/profile_repository.dart';

/// The free allowance is written down twice — once in Dart for the UI, once in
/// TypeScript for the Edge Function that passes it to `consume_scan_quota`.
/// Both files already say "must match the other one", and until now nothing
/// checked. Drift is not loud: the app would simply advertise and count down
/// from a number the server does not enforce, and nobody would notice until a
/// user complained about a limit that arrived early or late.
void main() {
  test('the Dart and TypeScript free-scan limits agree', () {
    // Flutter tests run with the working directory at `app/`.
    final source = File('../supabase/functions/analyze-toy/utils.ts');
    expect(
      source.existsSync(),
      isTrue,
      reason: 'expected ${source.absolute.path} to exist — if the constant '
          'moved, move this test with it rather than deleting it',
    );

    final match = RegExp(r'FREE_MONTHLY_SCANS\s*=\s*(\d+)')
        .firstMatch(source.readAsStringSync());
    expect(
      match,
      isNotNull,
      reason: 'FREE_MONTHLY_SCANS is no longer declared where this test looks',
    );

    expect(
      int.parse(match!.group(1)!),
      kFreeMonthlyScans,
      reason: 'The Edge Function and the app disagree about how many free '
          'scans a month is. The server wins, so the app is the one lying to '
          'the user — fix kFreeMonthlyScans.',
    );
  });
}
