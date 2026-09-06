// Tests for LiveActivityRepository.
//
// Mirrors notification_rule_repository_test.dart's structure for the
// PocketBase auth mocking, and scheduler_repository_test.dart's structure
// for exercising the PocketCoder operation call (endActivity) through a
// CapturingDioAdapter. The collision test is the main point of this file:
// the `live_activities` collection enforces one active row per
// (device, chat) pair via a unique partial index, and startActivity must
// treat a 400 from that constraint as "already started" rather than an
// error.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/live_activitie.dart';
import 'package:pocketcoder_flutter/infrastructure/core/pocketcoder_api_client.dart';
import 'package:pocketcoder_flutter/infrastructure/live_activities/live_activity_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/live_activities/live_activity_repository.dart';

import '../../helpers/capturing_dio_adapter.dart';

class MockPocketBase extends Mock implements PocketBase {}

class MockLiveActivityDao extends Mock implements LiveActivityDao {}

class _AuthedAuthStore extends Fake implements AuthStore {
  @override
  RecordModel? get record => _UserRecord();
}

class _UserRecord extends Fake implements RecordModel {
  @override
  String get id => 'user-1';
}

const activeActivity = LiveActivitie(
  id: 'activity-1',
  device: 'device-1',
  chat: 'chat-1',
  user: 'user-1',
  platform: LiveActivitiePlatform.ios,
  status: LiveActivitieStatus.active,
  contentStateVersion: 1,
);

void main() {
  late CapturingDioAdapter adapter;
  late MockPocketBase pb;
  late MockLiveActivityDao dao;
  late LiveActivityRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    adapter = CapturingDioAdapter(
      (_, __) => jsonResponse({'ok': true}),
    );
    final dio = Dio(BaseOptions(baseUrl: 'http://pb.local'))
      ..httpClientAdapter = adapter;
    pb = MockPocketBase();
    dao = MockLiveActivityDao();
    when(() => pb.authStore).thenReturn(_AuthedAuthStore());
    repository =
        LiveActivityRepository(dao, PocketCoderApiClient(dio: dio), pb);
  });

  group('LiveActivityRepository.startActivity', () {
    test('creates a new active row through the collection DAO', () async {
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenAnswer((_) async => <LiveActivitie>[]);
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => activeActivity);

      final result = await repository.startActivity(
        chatId: 'chat-1',
        deviceId: 'device-1',
        platform: 'ios',
        activityPushToken: 'token-1',
      );

      expect(result, activeActivity);
      verify(() => dao.save(null, {
            'user': 'user-1',
            'device': 'device-1',
            'chat': 'chat-1',
            'platform': 'ios',
            'status': 'active',
            'activity_push_token': 'token-1',
            'content_state_version': 1,
          })).called(1);
    });

    test(
        'returns the existing active row instead of erroring on a unique-index collision',
        () async {
      when(() => dao.save(any(), any())).thenThrow(
        ClientException(
            statusCode: 400, response: {'message': 'Failed to create record.'}),
      );
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenAnswer((_) async => [activeActivity]);

      final result = await repository.startActivity(
        chatId: 'chat-1',
        deviceId: 'device-1',
        platform: 'ios',
      );

      expect(result, activeActivity);
      verify(() => dao.getFullList(
            filter:
                'chat = "chat-1" && device = "device-1" && status = "active"',
          )).called(1);
    });

    test('rethrows a genuine 400 that is not the collision', () async {
      when(() => dao.save(any(), any())).thenThrow(
        ClientException(
            statusCode: 400, response: {'message': 'Failed to create record.'}),
      );
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenAnswer((_) async => <LiveActivitie>[]);

      expect(
        () => repository.startActivity(
          chatId: 'chat-1',
          deviceId: 'device-1',
          platform: 'ios',
        ),
        throwsA(isA<LiveActivityException>()),
      );
    });

    test('a non-400 failure is not treated as the collision', () async {
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenAnswer((_) async => <LiveActivitie>[]);
      when(() => dao.save(any(), any()))
          .thenThrow(ClientException(statusCode: 500));

      expect(
        () => repository.startActivity(
          chatId: 'chat-1',
          deviceId: 'device-1',
          platform: 'ios',
        ),
        throwsA(isA<LiveActivityException>()),
      );
      // getFullList is called once for the pre-create concurrency cap
      // check, but never with the collision-recovery filter -- that
      // lookup only fires on a 400 from dao.save, not this test's 500.
      verifyNever(() => dao.getFullList(
            filter:
                'chat = "chat-1" && device = "device-1" && status = "active"',
          ));
    });

    test('refuses to start a 6th concurrent active activity', () async {
      final fiveActive = List.generate(
        5,
        (i) => LiveActivitie(
          id: 'activity-$i',
          device: 'device-$i',
          chat: 'chat-$i',
          user: 'user-1',
          platform: LiveActivitiePlatform.ios,
          status: LiveActivitieStatus.active,
          contentStateVersion: 1,
        ),
      );
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenAnswer((_) async => fiveActive);

      expect(
        () => repository.startActivity(
          chatId: 'chat-6',
          deviceId: 'device-6',
          platform: 'ios',
        ),
        throwsA(isA<LiveActivityException>()),
      );
      verify(() =>
              dao.getFullList(filter: 'user = "user-1" && status = "active"'))
          .called(1);
      verifyNever(() => dao.save(any(), any()));
    });
  });

  test('endActivity calls the PocketCoder operation', () async {
    await repository.endActivity('activity-1');

    expect(
      adapter.lastRequest?.path,
      '/api/pocketcoder/v1/live-activities/activity-1/end',
    );
    expect(adapter.lastRequest?.method, 'POST');
  });

  group('LiveActivityRepository.getActiveActivities', () {
    test('lists all active rows for the signed-in user', () async {
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenAnswer((_) async => [activeActivity]);

      final result = await repository.getActiveActivities();

      expect(result, [activeActivity]);
      verify(() =>
              dao.getFullList(filter: 'user = "user-1" && status = "active"'))
          .called(1);
    });

    test('wraps a DAO failure in LiveActivityException', () async {
      when(() => dao.getFullList(filter: any(named: 'filter')))
          .thenThrow(Exception('offline'));

      expect(
        () => repository.getActiveActivities(),
        throwsA(isA<LiveActivityException>()),
      );
    });
  });
}
