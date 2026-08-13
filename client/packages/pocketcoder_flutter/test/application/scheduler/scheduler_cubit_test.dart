import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_cubit.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_state.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/domain/scheduler/i_scheduler_repository.dart';

class MockSchedulerRepository extends Mock implements ISchedulerRepository {}

const _schedule = ScheduleOwner(
  id: 'rec1',
  user: 'user1',
  displayName: 'Nightly Sync',
  cron: '0 2 * * *',
  paused: false,
);

void main() {
  late MockSchedulerRepository repo;
  SchedulerCubit? lastCubit;

  SchedulerCubit buildCubit() {
    final cubit = SchedulerCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockSchedulerRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('SchedulerCubit.loadSchedules', () {
    test('emits loading then loaded on success', () async {
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      final states = <SchedulerState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadSchedules();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [
        const SchedulerState.loading(),
        const SchedulerState.loaded([_schedule]),
      ]);
    });

    test('emits error on repository failure', () async {
      when(() => repo.listSchedules()).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.loadSchedules();

      expect(cubit.state.hasError, isTrue);
    });
  });

  group('SchedulerCubit.createSchedule', () {
    test('calls repository.createSchedule then reloads', () async {
      when(() => repo.createSchedule(
            displayName: any(named: 'displayName'),
            cron: any(named: 'cron'),
            prompt: any(named: 'prompt'),
          )).thenAnswer((_) async => _schedule);
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.createSchedule(
          displayName: 'Nightly Sync',
          cron: '0 2 * * *',
          prompt: 'do the thing');

      verify(() => repo.createSchedule(
            displayName: 'Nightly Sync',
            cron: '0 2 * * *',
            prompt: 'do the thing',
          )).called(1);
      verify(() => repo.listSchedules()).called(1);
    });

    test('emits error on repository failure without reloading', () async {
      when(() => repo.createSchedule(
            displayName: any(named: 'displayName'),
            cron: any(named: 'cron'),
            prompt: any(named: 'prompt'),
          )).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.createSchedule(displayName: 'x', cron: 'y', prompt: 'z');

      expect(cubit.state.hasError, isTrue);
      verifyNever(() => repo.listSchedules());
    });
  });

  group('SchedulerCubit.renameSchedule', () {
    test('calls repository.renameSchedule then reloads', () async {
      when(() => repo.renameSchedule(
            id: any(named: 'id'),
            displayName: any(named: 'displayName'),
          )).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.renameSchedule(id: 'rec1', displayName: 'Renamed');

      verify(() => repo.renameSchedule(id: 'rec1', displayName: 'Renamed'))
          .called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });

  group('SchedulerCubit.updateCron', () {
    test('calls repository.updateCron then reloads', () async {
      when(() =>
              repo.updateCron(id: any(named: 'id'), cron: any(named: 'cron')))
          .thenAnswer((_) async => _schedule);
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.updateCron(id: 'rec1', cron: '0 3 * * *');

      verify(() => repo.updateCron(id: 'rec1', cron: '0 3 * * *')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });

  group('SchedulerCubit.pauseSchedule', () {
    test('calls repository.pauseSchedule then reloads', () async {
      when(() => repo.pauseSchedule(any())).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.pauseSchedule('rec1');

      verify(() => repo.pauseSchedule('rec1')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });

  group('SchedulerCubit.unpauseSchedule', () {
    test('calls repository.unpauseSchedule then reloads', () async {
      when(() => repo.unpauseSchedule(any())).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.unpauseSchedule('rec1');

      verify(() => repo.unpauseSchedule('rec1')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });

  group('SchedulerCubit.deleteSchedule', () {
    test('calls repository.deleteSchedule then reloads', () async {
      when(() => repo.deleteSchedule(any())).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => []);

      final cubit = buildCubit();
      await cubit.deleteSchedule('rec1');

      verify(() => repo.deleteSchedule('rec1')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });

    test('emits error on repository failure without reloading', () async {
      when(() => repo.deleteSchedule(any())).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.deleteSchedule('rec1');

      expect(cubit.state.hasError, isTrue);
      verifyNever(() => repo.listSchedules());
    });
  });

  group('SchedulerCubit.runNow', () {
    test('calls repository.runNow then reloads', () async {
      when(() => repo.runNow(any())).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.runNow('rec1');

      verify(() => repo.runNow('rec1')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });
}
