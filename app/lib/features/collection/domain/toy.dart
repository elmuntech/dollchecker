import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

/// A single entry in the user's toy collection. Repeat scans of the same toy
/// fold into one row (see `upsert_toy_from_scan` in migration 0002), so
/// `scanCount` counts how many times it has been analyzed.
class Toy {
  const Toy({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.imagePath,
    required this.owned,
    required this.scanCount,
    required this.lastScannedAt,
    required this.safety,
    required this.educationalScore,
    required this.lastScanId,
  });

  final String id;
  final String name;
  final String? brand;
  final String? category;

  /// Storage object path in the private `toy-images` bucket, not a public URL.
  final String? imagePath;

  /// False means the toy sits on the wishlist rather than in the toy box.
  final bool owned;
  final int scanCount;
  final DateTime? lastScannedAt;
  final SafetyLevel safety;
  final int? educationalScore;
  final String? lastScanId;

  static const columns = 'id, name, brand, category, primary_image_url, owned, '
      'scan_count, last_scanned_at, latest_safety, latest_educational_score, '
      'last_scan_id';

  factory Toy.fromRow(Map<String, dynamic> r) => Toy(
        id: r['id'].toString(),
        name: r['name']?.toString() ?? '',
        brand: _nonEmpty(r['brand']),
        category: _nonEmpty(r['category']),
        imagePath: _nonEmpty(r['primary_image_url']),
        owned: r['owned'] != false,
        scanCount: r['scan_count'] is int ? r['scan_count'] as int : 0,
        lastScannedAt: r['last_scanned_at'] == null
            ? null
            : DateTime.tryParse('${r['last_scanned_at']}')?.toLocal(),
        safety: safetyLevelFromKey(r['latest_safety'] as String?),
        educationalScore: r['latest_educational_score'] as int?,
        lastScanId: _nonEmpty(r['last_scan_id']),
      );

  Toy copyWith({bool? owned}) => Toy(
        id: id,
        name: name,
        brand: brand,
        category: category,
        imagePath: imagePath,
        owned: owned ?? this.owned,
        scanCount: scanCount,
        lastScannedAt: lastScannedAt,
        safety: safety,
        educationalScore: educationalScore,
        lastScanId: lastScanId,
      );

  static String? _nonEmpty(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}

/// Which slice of the collection the grid shows.
enum CollectionFilter { all, owned, wishlist }
