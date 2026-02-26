import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/system/i_health_repository.dart';
import "package:flutter_aeroform/domain/models/healthcheck.dart";
import 'package:flutter_aeroform/domain/exceptions.dart';
import 'package:flutter_aeroform/core/try_operation.dart';
import 'health_daos.dart';

@LazySingleton(as: IHealthRepository)
class HealthRepository implements IHealthRepository {
  final HealthcheckDao _healthDao;

  HealthRepository(this._healthDao);

  @override
  Stream<List<Healthcheck>> watchHealth() {
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
