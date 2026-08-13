import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/infrastructure/scheduler/schedule_owner_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/scheduler/scheduler_repository.dart';

class MockPocketBase extends Mock implements PocketBase {}

class MockScheduleOwnerDao extends Mock implements ScheduleOwnerDao {}

const schedule = ScheduleOwner(
  id: 'schedule1',
  user: 'user1',
  displayName: 'Nightly review',
  cron: '0 2 * * *',
  prompt: 'Review the repository.',
  paused: false,
);

void main() {
  late MockPocketBase pocketBase;
  late MockScheduleOwnerDao dao;
  late SchedulerRepository repository;

  setUp(() {
    pocketBase = MockPocketBase();
    dao = MockScheduleOwnerDao();
    repository = SchedulerRepository(pocketBase, dao);
  });

  test('lists schedule records through the collection DAO', () async {
    when(() => dao.getFullList(sort: 'display_name'))
        .thenAnswer((_) async => [schedule]);

    expect(await repository.listSchedules(), [schedule]);
  });

  test('creates, updates, pauses, and deletes through collection CRUD',
      () async {
    when(() => dao.save(any(), any())).thenAnswer((_) async => schedule);
    when(() => dao.delete(any())).thenAnswer((_) async {});

    await repository.createSchedule(
      displayName: 'Nightly review',
      cron: '0 2 * * *',
      prompt: 'Review the repository.',
    );
    await repository.renameSchedule(id: 'schedule1', displayName: 'Review');
    await repository.updateCron(id: 'schedule1', cron: '0 3 * * *');
    await repository.pauseSchedule('schedule1');
    await repository.unpauseSchedule('schedule1');
    await repository.deleteSchedule('schedule1');

    verify(() => dao.save(any(), any())).called(5);
    verify(() => dao.delete('schedule1')).called(1);
  });

  test('run now remains a PocketCoder operation', () async {
    when(() => pocketBase.send<dynamic>(
          '/api/pocketcoder/schedules/run-now',
          method: 'POST',
          body: {'id': 'schedule1'},
        )).thenAnswer((_) async => {'status': 'started'});

    await repository.runNow('schedule1');

    verify(() => pocketBase.send<dynamic>(
          '/api/pocketcoder/schedules/run-now',
          method: 'POST',
          body: {'id': 'schedule1'},
        )).called(1);
  });
}
