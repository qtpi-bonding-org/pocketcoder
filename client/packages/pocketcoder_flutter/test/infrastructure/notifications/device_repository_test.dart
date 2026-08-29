import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/device.dart';
import 'package:pocketcoder_flutter/infrastructure/notifications/device_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/notifications/device_repository.dart';

class MockPocketBase extends Mock implements PocketBase {}

class MockDeviceDao extends Mock implements DeviceDao {}

class _FakeDevice extends Fake implements Device {
  @override
  String get id => 'device-1';
}

class _AuthedAuthStore extends Fake implements AuthStore {
  @override
  RecordModel? get record => _UserRecord();
}

class _UserRecord extends Fake implements RecordModel {
  @override
  String get id => 'user-1';
}

void main() {
  late MockPocketBase pb;
  late MockDeviceDao dao;
  late DeviceRepository repository;

  setUp(() {
    pb = MockPocketBase();
    dao = MockDeviceDao();
    when(() => pb.authStore).thenReturn(_AuthedAuthStore());
    repository = DeviceRepository(dao, pb);
  });

  test('stores the push-to-start token on matching devices', () async {
    when(() => dao.getFullList(filter: any(named: 'filter')))
        .thenAnswer((_) async => [_FakeDevice()]);
    when(() => dao.save(any(), any())).thenAnswer((_) async => _FakeDevice());

    await repository.setPushToStartToken('fcm-token', 'push-to-start-token');

    verify(() => dao.getFullList(
          filter: 'user = "user-1" && push_token = "fcm-token"',
        )).called(1);
    verify(() => dao.save('device-1', {
          'push_to_start_token': 'push-to-start-token',
        })).called(1);
  });
}
