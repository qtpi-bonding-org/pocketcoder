import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/scheduler/schedule_owner_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/scheduler/scheduler_repository.dart';

import '../../helpers/capturing_dio_adapter.dart';

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
  late CapturingDioAdapter adapter;
  late MockScheduleOwnerDao dao;
  late SchedulerRepository repository;

  setUp(() {
    adapter = CapturingDioAdapter(
      (_, __) => jsonResponse({'status': 'started'}, statusCode: 202),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://pb.local'))
      ..httpClientAdapter = adapter;
    dao = MockScheduleOwnerDao();
    repository = SchedulerRepository(PocketCoderApiClient(dio: dio), dao);
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
    await repository.runNow('schedule1');

    expect(
      adapter.lastRequest?.path,
      '/api/pocketcoder/v1/schedules/schedule1/run',
    );
    expect(adapter.lastRequest?.method, 'POST');
  });
}
