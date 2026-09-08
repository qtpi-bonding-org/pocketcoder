/// Converts a schedule's time-of-day (and, for weekly schedules, its days)
/// between the device's local wall clock and UTC.
///
/// PocketBase's cron scheduler always runs in UTC -- nothing in the backend
/// calls `Cron().SetTimezone()` (see
/// server/pocketbase/internal/api/schedules.go) -- so a time the user picks
/// on their device has to be converted to UTC before it becomes a cron
/// string, and converted back to local when an existing cron is loaded for
/// editing. Converting the hour/minute alone isn't enough for a weekly
/// schedule: shifting across a UTC offset can push the moment to the day
/// before or after, so the selected day(s) have to shift with it.
///
/// DST caveat: the conversion is computed against *today's* UTC offset,
/// because a cron expression has no year/date to anchor a "future" offset
/// to. A schedule that survives a daylight-saving transition keeps firing
/// at the same UTC instant, which is the same *local* wall-clock time only
/// outside the transition window. There's no fix for that without the
/// backend itself becoming timezone-aware.
class ScheduleLocalTime {
  const ScheduleLocalTime({
    required this.hour,
    required this.minute,
    this.daysOfWeek = const {},
  });

  final int hour;
  final int minute;

  /// 0=Sunday .. 6=Saturday. Empty for schedules with no day concept.
  final Set<int> daysOfWeek;
}

ScheduleLocalTime localToUtc(ScheduleLocalTime local) {
  final now = DateTime.now();
  final localDt =
      DateTime(now.year, now.month, now.day, local.hour, local.minute);
  final utcDt = localDt.toUtc();
  final shift = _dayShift(from: localDt, to: utcDt);
  return ScheduleLocalTime(
    hour: utcDt.hour,
    minute: utcDt.minute,
    daysOfWeek: _shiftDays(local.daysOfWeek, shift),
  );
}

ScheduleLocalTime utcToLocal(ScheduleLocalTime utc) {
  final now = DateTime.now().toUtc();
  final utcDt = DateTime.utc(now.year, now.month, now.day, utc.hour, utc.minute);
  final localDt = utcDt.toLocal();
  final shift = _dayShift(from: utcDt, to: localDt);
  return ScheduleLocalTime(
    hour: localDt.hour,
    minute: localDt.minute,
    daysOfWeek: _shiftDays(utc.daysOfWeek, shift),
  );
}

int _dayShift({required DateTime from, required DateTime to}) {
  final fromDate = DateTime(from.year, from.month, from.day);
  final toDate = DateTime(to.year, to.month, to.day);
  return toDate.difference(fromDate).inDays;
}

Set<int> _shiftDays(Set<int> days, int shift) =>
    days.map((d) => ((d + shift) % 7 + 7) % 7).toSet();

/// A short label for the device's current UTC offset, e.g. "UTC-7" or
/// "UTC+5:30" -- shown next to the time picker so someone who has traveled
/// can see what zone their pick is being interpreted in right now.
String currentUtcOffsetLabel() {
  final offset = DateTime.now().timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final hours = abs.inHours;
  final minutes = abs.inMinutes.remainder(60);
  return minutes == 0
      ? 'UTC$sign$hours'
      : 'UTC$sign$hours:${minutes.toString().padLeft(2, '0')}';
}
