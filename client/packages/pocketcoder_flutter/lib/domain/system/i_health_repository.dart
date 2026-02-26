import "package:flutter_aeroform/domain/models/healthcheck.dart";

abstract class IHealthRepository {
  Stream<List<Healthcheck>> watchHealth();
  Future<void> refreshHealth();
}
