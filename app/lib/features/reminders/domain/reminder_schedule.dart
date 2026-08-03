/// When, if ever, the app should nudge the family about today's missions.
///
/// A streak app without a reminder loses the streak: the loop only works if
/// something brings the parent back. Everything here is device-local — a
/// reminder is a property of the phone in someone's pocket, not of the account.
class ReminderSchedule {
  const ReminderSchedule({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;

  /// 24-hour clock, local time.
  final int hour;
  final int minute;

  /// Late afternoon: after nursery, before the bedtime rush.
  static const defaultSchedule =
      ReminderSchedule(enabled: false, hour: 18, minute: 0);

  ReminderSchedule copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSchedule(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  /// The next moment this reminder should fire, at or after [now].
  ///
  /// Today's slot counts only while it is still ahead; a reminder set for a
  /// time that has already passed belongs to tomorrow, not to a second ago.
  DateTime nextOccurrence(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  /// `HH:mm`, for the settings row.
  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Stored as one string so the whole setting moves atomically — an enabled
  /// flag that outlives its time would fire at midnight.
  String encode() => '${enabled ? 1 : 0}|$hour|$minute';

  /// Anything unparseable falls back to the default rather than throwing: a
  /// corrupted preference must not stop the app from starting.
  factory ReminderSchedule.decode(String? raw) {
    if (raw == null) return defaultSchedule;
    final parts = raw.split('|');
    if (parts.length != 3) return defaultSchedule;
    final hour = int.tryParse(parts[1]);
    final minute = int.tryParse(parts[2]);
    if (hour == null || minute == null) return defaultSchedule;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return defaultSchedule;
    }
    return ReminderSchedule(
      enabled: parts[0] == '1',
      hour: hour,
      minute: minute,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSchedule &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(enabled, hour, minute);

  @override
  String toString() => 'ReminderSchedule($enabled, $label)';
}
