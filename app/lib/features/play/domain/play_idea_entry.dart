/// A stored play idea, joined to the toy it came from.
class PlayIdeaEntry {
  const PlayIdeaEntry({
    required this.id,
    required this.scanId,
    required this.toyName,
    required this.title,
    required this.description,
    required this.skillsTargeted,
    required this.minAgeMonths,
    required this.durationMinutes,
    required this.difficulty,
    required this.isFavorited,
  });

  final String id;
  final String scanId;
  final String toyName;
  final String title;
  final String description;
  final List<String> skillsTargeted;
  final int? minAgeMonths;
  final int? durationMinutes;
  final String difficulty;
  final bool isFavorited;

  static const columns =
      'id, scan_id, title, description, skills_targeted, min_age_months, '
      'duration_minutes, difficulty, is_favorited, '
      'scans!inner(identification, child_profile_id)';

  factory PlayIdeaEntry.fromRow(Map<String, dynamic> r) {
    final scan = r['scans'];
    final ident = scan is Map ? scan['identification'] : null;
    return PlayIdeaEntry(
      id: r['id'].toString(),
      scanId: r['scan_id'].toString(),
      toyName: ident is Map ? (ident['name']?.toString() ?? '') : '',
      title: r['title']?.toString() ?? '',
      description: r['description']?.toString() ?? '',
      skillsTargeted: r['skills_targeted'] is List
          ? (r['skills_targeted'] as List).map((e) => '$e').toList()
          : const [],
      minAgeMonths: r['min_age_months'] as int?,
      durationMinutes: r['duration_minutes'] as int?,
      difficulty: r['difficulty']?.toString() ?? 'medium',
      isFavorited: r['is_favorited'] == true,
    );
  }

  PlayIdeaEntry copyWith({bool? isFavorited}) => PlayIdeaEntry(
        id: id,
        scanId: scanId,
        toyName: toyName,
        title: title,
        description: description,
        skillsTargeted: skillsTargeted,
        minAgeMonths: minAgeMonths,
        durationMinutes: durationMinutes,
        difficulty: difficulty,
        isFavorited: isFavorited ?? this.isFavorited,
      );
}

/// Picks the "idea of the day" — stable for a given calendar day so the
/// suggestion does not shuffle every time the screen rebuilds.
PlayIdeaEntry? ideaOfTheDay(List<PlayIdeaEntry> ideas, DateTime day) {
  if (ideas.isEmpty) return null;
  final epochDay =
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
  return ideas[epochDay.abs() % ideas.length];
}
