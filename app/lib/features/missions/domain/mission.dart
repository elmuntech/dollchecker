/// One concrete play task for one child on one day.
///
/// A mission keeps its own copy of the title/description rather than only
/// pointing at a play idea, so deleting a scan or a collection entry cannot
/// erase what the family actually did.
enum MissionStatus { pending, completed, skipped }

MissionStatus missionStatusFromKey(String? key) => switch (key) {
      'completed' => MissionStatus.completed,
      'skipped' => MissionStatus.skipped,
      _ => MissionStatus.pending,
    };

String missionStatusKey(MissionStatus status) => switch (status) {
      MissionStatus.completed => 'completed',
      MissionStatus.skipped => 'skipped',
      MissionStatus.pending => 'pending',
    };

class Mission {
  const Mission({
    required this.id,
    required this.childProfileId,
    required this.date,
    required this.slot,
    required this.playIdeaId,
    required this.toyId,
    required this.title,
    required this.description,
    required this.skill,
    required this.durationMinutes,
    required this.status,
    required this.completedAt,
  });

  final String id;
  final String childProfileId;

  /// Calendar day the mission belongs to (date-only, local).
  final DateTime date;
  final int slot;
  final String? playIdeaId;
  final String? toyId;
  final String title;
  final String description;
  final String? skill;
  final int? durationMinutes;
  final MissionStatus status;
  final DateTime? completedAt;

  bool get isDone => status == MissionStatus.completed;
  bool get isOpen => status == MissionStatus.pending;

  static const columns = 'id, child_profile_id, mission_date, slot, '
      'play_idea_id, toy_id, title, description, skill, duration_minutes, '
      'status, completed_at';

  factory Mission.fromRow(Map<String, dynamic> r) => Mission(
        id: r['id'].toString(),
        childProfileId: r['child_profile_id']?.toString() ?? '',
        date: DateTime.tryParse('${r['mission_date']}') ?? DateTime(1970),
        slot: r['slot'] is int ? r['slot'] as int : 0,
        playIdeaId: _nonEmpty(r['play_idea_id']),
        toyId: _nonEmpty(r['toy_id']),
        title: r['title']?.toString() ?? '',
        description: r['description']?.toString() ?? '',
        skill: _nonEmpty(r['skill']),
        durationMinutes: r['duration_minutes'] as int?,
        status: missionStatusFromKey(r['status'] as String?),
        completedAt: r['completed_at'] == null
            ? null
            : DateTime.tryParse('${r['completed_at']}')?.toLocal(),
      );

  Mission copyWith({MissionStatus? status, DateTime? completedAt}) => Mission(
        id: id,
        childProfileId: childProfileId,
        date: date,
        slot: slot,
        playIdeaId: playIdeaId,
        toyId: toyId,
        title: title,
        description: description,
        skill: skill,
        durationMinutes: durationMinutes,
        status: status ?? this.status,
        completedAt: completedAt ?? this.completedAt,
      );

  static String? _nonEmpty(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}
