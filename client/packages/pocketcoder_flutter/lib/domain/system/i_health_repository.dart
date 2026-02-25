import 'package:pocketcoder_flutter/domain/models/healthcheck.dart';

abstract class IHealthRepository {
  Stream<List<Healthcheck>> watchHealth();
  Future<void> refreshHealth();
}
