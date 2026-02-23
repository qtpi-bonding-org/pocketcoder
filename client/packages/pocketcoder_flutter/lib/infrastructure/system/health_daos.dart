import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/system/system_health.dart';
import '../core/base_dao.dart';
import '../core/collections.dart';

@lazySingleton
class HealthDao extends BaseDao<SystemHealth> {
  HealthDao(PocketBase pb)
      : super(pb, Collections.healthchecks, SystemHealth.fromJson);
}
