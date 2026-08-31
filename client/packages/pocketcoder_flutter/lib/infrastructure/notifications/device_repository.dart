import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/device.dart';
import 'package:pocketcoder_flutter/domain/notifications/i_device_repository.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'device_daos.dart';

@LazySingleton(as: IDeviceRepository)
class DeviceRepository implements IDeviceRepository {
  final DeviceDao _deviceDao;
  final PocketBase _pb;

  DeviceRepository(this._deviceDao, this._pb);

  @override
  Future<void> registerDevice({
    required String name,
    required String pushToken,
    required String pushService,
  }) async {
    return tryMethod(
      () async {
        final userId = _pb.authStore.record?.id;
        if (userId == null) return;

        final result = await _deviceDao.getFullList(
          filter: 'user = "$userId" && push_token = "$pushToken"',
        );

        final data = {
          'user': userId,
          'name': name,
          'push_token': pushToken,
          'push_service': pushService,
          'is_active': true,
        };

        if (result.isNotEmpty) {
          await _deviceDao.save(result.first.id, data);
        } else {
          await _deviceDao.save(null, data);
        }
      },
      RepositoryException.new,
      'registerDevice',
    );
  }

  @override
  Future<void> unregisterDevice(String pushToken) async {
    return tryMethod(
      () async {
        final userId = _pb.authStore.record?.id;
        if (userId == null) return;

        final result = await _deviceDao.getFullList(
          filter: 'user = "$userId" && push_token = "$pushToken"',
        );

        for (final item in result) {
          await _deviceDao.save(item.id, {'is_active': false});
        }
      },
      RepositoryException.new,
      'unregisterDevice',
    );
  }

  @override
  Future<void> setPushToStartToken(
    String pushToken,
    String pushToStartToken,
  ) async {
    return tryMethod(
      () async {
        final userId = _pb.authStore.record?.id;
        if (userId == null) return;

        final result = await _deviceDao.getFullList(
          filter: 'user = "$userId" && push_token = "$pushToken"',
        );

        for (final item in result) {
          await _deviceDao.save(item.id, {
            'push_to_start_token': pushToStartToken,
          });
        }
      },
      RepositoryException.new,
      'setPushToStartToken',
    );
  }

  @override
  Future<List<Device>> getDevices() async {
    return tryMethod(
      () async {
        final userId = _pb.authStore.record?.id;
        if (userId == null) return [];

        final result = await _deviceDao.getFullList(
          filter: 'user = "$userId" && is_active = true',
          sort: '-created',
        );

        return result.map((r) => Device.fromJson(r.toJson())).toList();
      },
      RepositoryException.new,
      'getDevices',
    );
  }
}
