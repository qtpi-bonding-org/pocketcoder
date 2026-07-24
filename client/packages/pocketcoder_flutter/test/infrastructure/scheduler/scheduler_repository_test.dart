import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/scheduler/scheduler_repository.dart';

class MockPocketBase extends Mock implements PocketBase {}

void main() {
  late SchedulerRepository repo;
  late MockPocketBase pb;

  setUp(() {
    pb = MockPocketBase();
    repo = SchedulerRepository(pb);
  });

  group('SchedulerRepository.listSchedules', () {
    test('posts to schedules/list and maps the response', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/list',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'schedules': [
              {
                'id': 'rec1',
                'displayName': 'Nightly Sync',
                'cron': '0 2 * * *',
                'paused': false,
                'currentlyRunning': false,
                'lastRun': null,
              }
            ]
          });

      final result = await repo.listSchedules();

      expect(result, hasLength(1));
      expect(result.first.displayName, 'Nightly Sync');
      expect(result.first.paused, isFalse);
      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/list',
            method: 'POST',
            body: {},
          )).called(1);
    });

    test('wraps failures in SchedulerException', () async {
      when(() => pb.send<dynamic>(
            any(),
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenThrow(Exception('boom'));

      await expectLater(() => repo.listSchedules(), throwsA(isA<SchedulerException>()));
    });
  });

  group('SchedulerRepository.createSchedule', () {
    test('posts displayName/cron/prompt', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/create',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'id': 'rec1',
            'displayName': 'Nightly Sync',
            'cron': '0 2 * * *',
            'paused': false,
            'currentlyRunning': false,
            'lastRun': null,
          });

      await repo.createSchedule(displayName: 'Nightly Sync', cron: '0 2 * * *', prompt: 'do the thing');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/create',
            method: 'POST',
            body: {
              'displayName': 'Nightly Sync',
              'cron': '0 2 * * *',
              'prompt': 'do the thing',
            },
          )).called(1);
    });
  });

  group('SchedulerRepository.renameSchedule', () {
    test('posts id/displayName', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/rename',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'id': 'rec1', 'displayName': 'Renamed'});

      await repo.renameSchedule(id: 'rec1', displayName: 'Renamed');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/rename',
            method: 'POST',
            body: {'id': 'rec1', 'displayName': 'Renamed'},
          )).called(1);
    });
  });

  group('SchedulerRepository.updateCron', () {
    test('posts id/cron', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/update-cron',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'id': 'rec1',
            'displayName': 'Nightly Sync',
            'cron': '0 3 * * *',
            'paused': false,
            'currentlyRunning': false,
            'lastRun': null,
          });

      await repo.updateCron(id: 'rec1', cron: '0 3 * * *');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/update-cron',
            method: 'POST',
            body: {'id': 'rec1', 'cron': '0 3 * * *'},
          )).called(1);
    });
  });

  group('SchedulerRepository.pauseSchedule', () {
    test('posts id', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/pause',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'ok': true});

      await repo.pauseSchedule('rec1');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/pause',
            method: 'POST',
            body: {'id': 'rec1'},
          )).called(1);
    });
  });

  group('SchedulerRepository.unpauseSchedule', () {
    test('posts id', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/unpause',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'ok': true});

      await repo.unpauseSchedule('rec1');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/unpause',
            method: 'POST',
            body: {'id': 'rec1'},
          )).called(1);
    });
  });

  group('SchedulerRepository.deleteSchedule', () {
    test('posts id', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/delete',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'deleted': true});

      await repo.deleteSchedule('rec1');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/delete',
            method: 'POST',
            body: {'id': 'rec1'},
          )).called(1);
    });

    test('wraps failures in SchedulerException', () async {
      when(() => pb.send<dynamic>(
            any(),
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenThrow(Exception('boom'));

      await expectLater(() => repo.deleteSchedule('rec1'), throwsA(isA<SchedulerException>()));
    });
  });

  group('SchedulerRepository.runNow', () {
    test('posts id', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/run-now',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'started'});

      await repo.runNow('rec1');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/run-now',
            method: 'POST',
            body: {'id': 'rec1'},
          )).called(1);
    });
  });
}
