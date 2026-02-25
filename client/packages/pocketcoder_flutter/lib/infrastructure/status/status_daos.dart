import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/healthcheck.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import 'package:pocketcoder_flutter/infrastructure/core/collections.dart';

@lazySingleton
class HealthcheckDao extends BaseDao<Healthcheck> {
  HealthcheckDao(PocketBase pb)
      : super(pb, Collections.healthchecks, Healthcheck.fromJson);
}
