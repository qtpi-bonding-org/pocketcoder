import 'package:injectable/injectable.dart';
import '../../domain/system/i_health_repository.dart';
import '../../domain/system/system_health.dart';
import '../../domain/exceptions.dart';
import '../../core/try_operation.dart';
import 'health_daos.dart';

@LazySingleton(as: IHealthRepository)
class HealthRepository implements IHealthRepository {
  final HealthDao _healthDao;

  HealthRepository(this._healthDao);

  @override
  Stream<List<SystemHealth>> watchHealth() {
    return _healthDao.watch();
  }

  @override
  Future<void> refreshHealth() async {
    return tryMethod(
      () async {
        await _healthDao.getFullList();
      },
      RepositoryException.new,
      'refreshHealth',
    );
  }
}
