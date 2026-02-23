import 'system_health.dart';

abstract class IHealthRepository {
  Stream<List<SystemHealth>> watchHealth();
  Future<void> refreshHealth();
}
