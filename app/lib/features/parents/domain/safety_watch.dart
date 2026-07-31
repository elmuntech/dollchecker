import 'package:dollchecker/features/collection/domain/toy.dart';
import 'package:dollchecker/features/scan/domain/toy_analysis.dart';

/// The toys a parent should look at again: everything in the collection whose
/// latest analysis came back red or yellow.
///
/// Ordering is decided here rather than in the query, so the list reads the same
/// whichever way the rows arrive: red before yellow, then most recently scanned
/// first — a hazard found this morning outranks one found last month.
class SafetyWatch {
  SafetyWatch(List<Toy> toys) : toys = List.unmodifiable(toys);

  final List<Toy> toys;

  static final empty = SafetyWatch(const []);

  factory SafetyWatch.from(Iterable<Toy> toys) {
    final flagged = toys.where((t) => _rank(t.safety) > 0).toList()
      ..sort((a, b) {
        final byLevel = _rank(b.safety).compareTo(_rank(a.safety));
        if (byLevel != 0) return byLevel;
        final aAt = a.lastScannedAt;
        final bAt = b.lastScannedAt;
        if (aAt == null || bAt == null) {
          return aAt == bAt ? a.name.compareTo(b.name) : (aAt == null ? 1 : -1);
        }
        return bAt.compareTo(aAt);
      });
    return SafetyWatch(flagged);
  }

  bool get isEmpty => toys.isEmpty;
  bool get isNotEmpty => toys.isNotEmpty;
  int get count => toys.length;

  int get redCount => toys.where((t) => t.safety == SafetyLevel.red).length;
  int get yellowCount =>
      toys.where((t) => t.safety == SafetyLevel.yellow).length;

  /// Red outranks yellow; everything else is not worth a parent's attention.
  static int _rank(SafetyLevel level) => switch (level) {
        SafetyLevel.red => 2,
        SafetyLevel.yellow => 1,
        SafetyLevel.green || SafetyLevel.unknown => 0,
      };
}
