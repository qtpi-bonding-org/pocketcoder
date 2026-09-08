import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/scheduler/friendly_schedule.dart';

void main() {
  group('FriendlySchedule.toCron', () {
    test('hourly runs on the hour', () {
      expect(FriendlySchedule(frequency: ScheduleFrequency.hourly)
          .toCron(), '0 * * * *');
    });

    test('daily uses the given hour and minute with wildcard day/month/dow',
        () {
      expect(
          FriendlySchedule(
                  frequency: ScheduleFrequency.daily, hour: 9, minute: 30)
              .toCron(),
          '30 9 * * *');
    });

    test('daily at midnight', () {
      expect(
          FriendlySchedule(
                  frequency: ScheduleFrequency.daily, hour: 0, minute: 0)
              .toCron(),
          '0 0 * * *');
    });

    test('weekly sorts and comma-joins the selected days', () {
      expect(
          FriendlySchedule(
                  frequency: ScheduleFrequency.weekly,
                  hour: 8,
                  minute: 0,
                  daysOfWeek: {5, 1, 3})
              .toCron(),
          '0 8 * * 1,3,5');
    });

    test('weekly with a single day', () {
      expect(
          FriendlySchedule(
                  frequency: ScheduleFrequency.weekly,
                  hour: 17,
                  minute: 45,
                  daysOfWeek: {0})
              .toCron(),
          '45 17 * * 0');
    });
  });

  group('FriendlySchedule construction', () {
    test('asserts weekly schedules have at least one day', () {
      expect(
          () => FriendlySchedule(
              frequency: ScheduleFrequency.weekly, daysOfWeek: const {}),
          throwsA(isA<AssertionError>()));
    });
  });

  group('FriendlySchedule.tryParseCron round-trips toCron output', () {
    for (final schedule in [
      FriendlySchedule(frequency: ScheduleFrequency.hourly),
      FriendlySchedule(
          frequency: ScheduleFrequency.daily, hour: 9, minute: 0),
      FriendlySchedule(
          frequency: ScheduleFrequency.daily, hour: 23, minute: 59),
      FriendlySchedule(
          frequency: ScheduleFrequency.weekly,
          hour: 8,
          minute: 15,
          daysOfWeek: {1, 3, 5}),
      FriendlySchedule(
          frequency: ScheduleFrequency.weekly,
          hour: 0,
          minute: 0,
          daysOfWeek: {0, 6}),
    ]) {
      test('round-trips ${schedule.toCron()}', () {
        final parsed = FriendlySchedule.tryParseCron(schedule.toCron());
        expect(parsed, isNotNull);
        expect(parsed!.frequency, schedule.frequency);
        if (schedule.frequency != ScheduleFrequency.hourly) {
          expect(parsed.hour, schedule.hour);
          expect(parsed.minute, schedule.minute);
        }
        if (schedule.frequency == ScheduleFrequency.weekly) {
          expect(parsed.daysOfWeek, schedule.daysOfWeek);
        }
      });
    }
  });

  group('FriendlySchedule.tryParseCron rejects anything it did not generate',
      () {
    for (final cron in [
      '', // empty
      '* * * * *', // too permissive, not one of our shapes
      '30 9 1 * *', // day-of-month pinned -- we never generate that
      '30 9 * 6 *', // month pinned -- we never generate that
      '0 25 * * *', // hour out of range
      '61 9 * * *', // minute out of range
      '0 9 * * 7', // day-of-week out of range (0-6 only)
      '@daily', // macro form -- valid to PocketBase, not one we emit
      'not a cron at all',
    ]) {
      test('rejects "$cron"', () {
        expect(FriendlySchedule.tryParseCron(cron), isNull);
      });
    }

    test('accepts a bare hourly-shaped cron even with extra whitespace', () {
      final parsed = FriendlySchedule.tryParseCron('0  *   *  *  *');
      expect(parsed, isNotNull);
      expect(parsed!.frequency, ScheduleFrequency.hourly);
    });
  });
}
