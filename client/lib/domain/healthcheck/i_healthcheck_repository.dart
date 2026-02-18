import 'package:pocketbase/pocketbase.dart';

import 'healthcheck.dart';

abstract class IHealthcheckRepository {
  Future<List<Healthcheck>> getHealthchecks();
  Future<Healthcheck?> getServiceStatus(String serviceName);
  Stream<List<RecordModel>> watchHealthchecks();
}