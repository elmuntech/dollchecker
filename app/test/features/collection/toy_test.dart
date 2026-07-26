import 'package:flutter_test/flutter_test.dart';

import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

void main() {
  group('Toy.fromRow', () {
    test('reads a fully populated row', () {
      final toy = Toy.fromRow({
        'id': 'toy-1',
        'name': 'Wooden Blocks',
        'brand': 'Hape',
        'category': 'building blocks',
        'primary_image_url': 'user-1/abc.jpg',
        'owned': true,
        'scan_count': 3,
        'last_scanned_at': '2026-07-20T10:00:00Z',
        'latest_safety': 'green',
        'latest_educational_score': 88,
        'last_scan_id': 'scan-9',
      });
      expect(toy.id, 'toy-1');
      expect(toy.name, 'Wooden Blocks');
      expect(toy.brand, 'Hape');
      expect(toy.owned, isTrue);
      expect(toy.scanCount, 3);
      expect(toy.safety, SafetyLevel.green);
      expect(toy.educationalScore, 88);
      expect(toy.lastScanId, 'scan-9');
      expect(toy.lastScannedAt, isNotNull);
    });

    test('maps blank optional strings to null', () {
      final toy = Toy.fromRow({
        'id': 'toy-2',
        'name': 'Rattle',
        'brand': '',
        'category': '   ',
        'primary_image_url': null,
        'owned': false,
        'scan_count': 1,
      });
      expect(toy.brand, isNull);
      expect(toy.category, isNull);
      expect(toy.imagePath, isNull);
      expect(toy.lastScanId, isNull);
    });

    test('wishlist entries are the ones that are not owned', () {
      final toy = Toy.fromRow({'id': 't', 'name': 'X', 'owned': false});
      expect(toy.owned, isFalse);
    });

    test('defaults owned to true when the column is absent', () {
      final toy = Toy.fromRow({'id': 't', 'name': 'X'});
      expect(toy.owned, isTrue);
      expect(toy.scanCount, 0);
      expect(toy.safety, SafetyLevel.unknown);
      expect(toy.lastScannedAt, isNull);
    });

    test('an unparseable timestamp becomes null instead of throwing', () {
      final toy = Toy.fromRow({
        'id': 't',
        'name': 'X',
        'last_scanned_at': 'whenever',
      });
      expect(toy.lastScannedAt, isNull);
    });
  });

  group('copyWith', () {
    test('flips owned and leaves everything else alone', () {
      final toy = Toy.fromRow({
        'id': 'toy-1',
        'name': 'Blocks',
        'brand': 'Hape',
        'owned': true,
        'scan_count': 2,
      });
      final moved = toy.copyWith(owned: false);
      expect(moved.owned, isFalse);
      expect(moved.id, toy.id);
      expect(moved.name, toy.name);
      expect(moved.brand, toy.brand);
      expect(moved.scanCount, toy.scanCount);
    });
  });

  test('CollectionFilter covers all, owned and wishlist', () {
    expect(CollectionFilter.values, hasLength(3));
  });
}
