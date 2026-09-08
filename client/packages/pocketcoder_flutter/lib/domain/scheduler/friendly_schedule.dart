/// The three schedule shapes exposed by the friendly picker UI. Not a
/// general cron editor -- every value that reaches the backend still goes
/// through [FriendlySchedule.toCron], which only ever emits one of these
/// three patterns.
enum ScheduleFrequency { hourly, daily, weekly }

/// A schedule expressed the way a person picks it (frequency + time of day
/// + days of the week), translated to/from the 5-field cron expression the
/// backend actually stores. The backend still validates with PocketBase's
/// own `tools/cron.NewSchedule` (minute hour day month day-of-week, days
/// 0-6 with Sunday=0) -- [toCron] only needs to stay inside what that
/// parser accepts, not reimplement it.
class FriendlySchedule {
  FriendlySchedule({
    required this.frequency,
    this.hour = 9,
    this.minute = 0,
    this.daysOfWeek = const {},
  })  : assert(hour >= 0 && hour <= 23),
        assert(minute >= 0 && minute <= 59),
        assert(
            frequency != ScheduleFrequency.weekly || daysOfWeek.isNotEmpty,
            'weekly schedules need at least one day');

  /// How often the schedule repeats.
  final ScheduleFrequency frequency;

  /// Hour of day, 0-23. Ignored for [ScheduleFrequency.hourly].
  final int hour;

  /// Minute of hour, 0-59. Ignored for [ScheduleFrequency.hourly].
  final int minute;

  /// 0=Sunday .. 6=Saturday. Only meaningful for [ScheduleFrequency.weekly],
  /// and must be non-empty there.
  final Set<int> daysOfWeek;

  String toCron() {
    switch (frequency) {
      case ScheduleFrequency.hourly:
        return '0 * * * *';
      case ScheduleFrequency.daily:
        return '$minute $hour * * *';
      case ScheduleFrequency.weekly:
        final days = (daysOfWeek.toList()..sort()).join(',');
        return '$minute $hour * * $days';
    }
  }

  /// Reverse-parses a cron string previously produced by [toCron]. Returns
  /// null for anything that doesn't match one of those three shapes (e.g. a
  /// schedule hand-authored before this UI existed), so the caller can fall
  /// back to a safe default instead of crashing on someone else's cron.
  static FriendlySchedule? tryParseCron(String cron) {
    final segments = cron.trim().split(RegExp(r'\s+'));
    if (segments.length != 5) return null;
    final minuteSeg = segments[0];
    final hourSeg = segments[1];
    final daySeg = segments[2];
    final monthSeg = segments[3];
    final dowSeg = segments[4];

    // Every shape we generate leaves day-of-month and month as wildcards.
    if (daySeg != '*' || monthSeg != '*') return null;

    if (minuteSeg == '0' && hourSeg == '*' && dowSeg == '*') {
      return FriendlySchedule(frequency: ScheduleFrequency.hourly);
    }

    final minute = int.tryParse(minuteSeg);
    final hour = int.tryParse(hourSeg);
    if (minute == null || minute < 0 || minute > 59) return null;
    if (hour == null || hour < 0 || hour > 23) return null;

    if (dowSeg == '*') {
      return FriendlySchedule(
          frequency: ScheduleFrequency.daily, hour: hour, minute: minute);
    }

    final dayStrings = dowSeg.split(',');
    final days = <int>{};
    for (final s in dayStrings) {
      final d = int.tryParse(s);
      if (d == null || d < 0 || d > 6) return null;
      days.add(d);
    }
    if (days.isEmpty) return null;

    return FriendlySchedule(
        frequency: ScheduleFrequency.weekly,
        hour: hour,
        minute: minute,
        daysOfWeek: days);
  }
}
