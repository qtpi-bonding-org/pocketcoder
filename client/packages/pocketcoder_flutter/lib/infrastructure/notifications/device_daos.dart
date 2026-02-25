import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/notifications/device.dart';
import '../core/base_dao.dart';
import '../core/collections.dart';

@lazySingleton
class DeviceDao extends BaseDao<Device> {
  DeviceDao(PocketBase pb) : super(pb, Collections.devices, Device.fromJson);
}
