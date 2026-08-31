import 'package:pocketcoder_flutter/domain/models/healthcheck.dart';

abstract class IStatusRepository {
  /// Check if the PocketBase backend is reachable and healthy
  Future<bool> checkPocketBaseHealth();

  Future<List<Healthcheck>> getHealthchecks();
  Stream<List<Healthcheck>> watchHealthchecks();
}
