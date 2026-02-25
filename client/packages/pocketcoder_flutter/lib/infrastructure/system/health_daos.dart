import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/system/system_health.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/core/collections.dart';

@lazySingleton
class HealthDao extends BaseDao<SystemHealth> {
  HealthDao(PocketBase pb)
      : super(pb, Collections.healthchecks, SystemHealth.fromJson);
}
