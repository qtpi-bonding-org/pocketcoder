import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/scheduler/schedule_timezone.dart';

void main() {
  group('localToUtc / utcToLocal round-trip', () {
    // Deliberately timezone-agnostic: these must hold no matter what
    // timezone the machine running the test is in, since localToUtc and
    // utcToLocal are inverses of each other regardless of offset.
    for (final t in [
      const ScheduleLocalTime(hour: 0, minute: 0),
      const ScheduleLocalTime(hour: 9, minute: 30),
      const ScheduleLocalTime(hour: 23, minute: 59),
      const ScheduleLocalTime(hour: 12, minute: 0, daysOfWeek: {1, 3, 5}),
      const ScheduleLocalTime(hour: 0, minute: 0, daysOfWeek: {0, 6}),
      const ScheduleLocalTime(hour: 23, minute: 45, daysOfWeek: {0, 1, 2, 3, 4, 5, 6}),
    ]) {
      test(
          'localToUtc then utcToLocal restores '
          '${t.hour}:${t.minute} ${t.daysOfWeek}', () {
        final roundTripped = utcToLocal(localToUtc(t));
        expect(roundTripped.hour, t.hour);
        expect(roundTripped.minute, t.minute);
        expect(roundTripped.daysOfWeek, t.daysOfWeek);
      });
    }
  });

  group('localToUtc output is always in range', () {
    for (var h = 0; h < 24; h += 3) {
      for (var m = 0; m < 60; m += 15) {
        test('$h:$m produces a valid UTC hour/minute', () {
          final utc =
              localToUtc(ScheduleLocalTime(hour: h, minute: m, daysOfWeek: const {2}));
          expect(utc.hour, inInclusiveRange(0, 23));
          expect(utc.minute, inInclusiveRange(0, 59));
          expect(utc.daysOfWeek, hasLength(1));
          expect(utc.daysOfWeek.single, inInclusiveRange(0, 6));
        });
      }
    }
  });

  test('a UTC offset of zero is a no-op', () {
    // Not assertable in general (depends on the machine's timezone), but
    // when local IS utc this must hold exactly -- guard against a future
    // regression that always shifts by a fixed non-zero amount.
    final offset = DateTime.now().timeZoneOffset;
    if (offset == Duration.zero) {
      const t = ScheduleLocalTime(hour: 14, minute: 20, daysOfWeek: {2});
      final utc = localToUtc(t);
      expect(utc.hour, 14);
      expect(utc.minute, 20);
      expect(utc.daysOfWeek, {2});
    }
  });

  group('currentUtcOffsetLabel', () {
    test('matches the UTC+/-N[:MM] shape', () {
      expect(currentUtcOffsetLabel(), matches(RegExp(r'^UTC[+-]\d+(:\d{2})?$')));
    });
  });
}
