import 'package:pocketcoder_flutter/domain/models/healthcheck.dart';
import 'package:pocketbase/pocketbase.dart';

abstract class IHealthcheckRepository {
  Future<List<Healthcheck>> getHealthchecks();
  Future<Healthcheck?> getServiceStatus(String serviceName);
  Stream<List<RecordModel>> watchHealthchecks();
}
