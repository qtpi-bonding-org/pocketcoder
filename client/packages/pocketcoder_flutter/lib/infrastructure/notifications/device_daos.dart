import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/device.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/core/collections.dart';

@lazySingleton
class DeviceDao extends BaseDao<Device> {
  DeviceDao(PocketBase pb) : super(pb, Collections.devices, Device.fromJson);
}
