import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../domain/status/i_status_repository.dart';
import '../../domain/healthcheck/healthcheck.dart';
import '../../domain/exceptions.dart';
import '../../core/try_operation.dart';
import 'status_daos.dart';

@LazySingleton(as: IStatusRepository)
class StatusRepository implements IStatusRepository {
  final HealthcheckDao _healthcheckDao;
  final PocketBase _pb;

  StatusRepository(this._healthcheckDao, this._pb);

  @override
  Future<bool> checkPocketBaseHealth() async {
    return tryMethod(
      () async {
        final health = await _pb.health.check();
        return health.code == 200;
      },
      (msg, [cause]) => RepositoryException(msg, cause),
      'checkPocketBaseHealth',
    );
  }

  @override
  Future<List<Healthcheck>> getHealthchecks() async {
    return _healthcheckDao.getFullList(sort: '-created');
  }

  @override
  Stream<List<Healthcheck>> watchHealthchecks() {
    return _healthcheckDao.watch(sort: '-created');
  }
}
