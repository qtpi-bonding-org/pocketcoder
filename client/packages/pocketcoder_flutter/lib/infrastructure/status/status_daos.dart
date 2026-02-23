import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/healthcheck/healthcheck.dart';
import '../core/base_dao.dart';
import '../core/collections.dart';

@lazySingleton
class HealthcheckDao extends BaseDao<Healthcheck> {
  HealthcheckDao(PocketBase pb)
      : super(pb, Collections.healthchecks, Healthcheck.fromJson);
}
