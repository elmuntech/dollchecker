/// Calendar-day helpers.
///
/// Streaks and daily missions compare days, not instants. Subtracting two
/// `DateTime`s and reading `inDays` is wrong across a daylight-saving boundary
/// (a 23-hour gap floors to 0 days), so everything here goes through a stable
/// day number instead.
library;

/// Days since the Unix epoch for the calendar day [d] falls on.
int epochDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;

/// [d] with the time of day stripped, in local time.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) => epochDay(a) == epochDay(b);

/// The date-only ISO string Postgres expects for a `date` column.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
