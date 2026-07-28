import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/parents/domain/safety_watch.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

Toy toy(String name, {String? safety, String? scannedAt}) => Toy.fromRow({
      'id': 'toy-$name',
      'name': name,
      'owned': true,
      'scan_count': 1,
      'latest_safety': safety,
      'last_scanned_at': scannedAt,
    });

void main() {
  test('keeps only the toys that are not green', () {
    final watch = SafetyWatch.from([
      toy('Blocks', safety: 'green'),
      toy('Magnet set', safety: 'red'),
      toy('Rattle', safety: 'yellow'),
      toy('Mystery', safety: null),
    ]);
    expect(watch.toys.map((t) => t.name), ['Magnet set', 'Rattle']);
    expect(watch.count, 2);
    expect(watch.redCount, 1);
    expect(watch.yellowCount, 1);
    expect(watch.isNotEmpty, isTrue);
  });

  test('puts red before yellow whatever order the rows arrive in', () {
    final watch = SafetyWatch.from([
      toy('Rattle', safety: 'yellow', scannedAt: '2026-07-26T10:00:00Z'),
      toy('Magnet set', safety: 'red', scannedAt: '2026-01-01T10:00:00Z'),
    ]);
    expect(watch.toys.first.name, 'Magnet set');
  });

  test('within a level, the most recent scan comes first', () {
    final watch = SafetyWatch.from([
      toy('Old', safety: 'yellow', scannedAt: '2026-01-01T10:00:00Z'),
      toy('New', safety: 'yellow', scannedAt: '2026-07-26T10:00:00Z'),
    ]);
    expect(watch.toys.map((t) => t.name), ['New', 'Old']);
  });

  test('toys never scanned sort last, by name', () {
    final watch = SafetyWatch.from([
      toy('Zebra', safety: 'yellow'),
      toy('Apple', safety: 'yellow'),
      toy('Dated', safety: 'yellow', scannedAt: '2026-01-01T10:00:00Z'),
    ]);
    expect(watch.toys.map((t) => t.name), ['Dated', 'Apple', 'Zebra']);
  });

  test('an all-green collection has nothing to review', () {
    final watch = SafetyWatch.from([toy('Blocks', safety: 'green')]);
    expect(watch.isEmpty, isTrue);
    expect(watch.redCount, 0);
    expect(SafetyWatch.empty.isEmpty, isTrue);
  });

  test('the flagged toys keep their safety level', () {
    final watch = SafetyWatch.from([toy('Magnet set', safety: 'red')]);
    expect(watch.toys.single.safety, SafetyLevel.red);
  });
}
