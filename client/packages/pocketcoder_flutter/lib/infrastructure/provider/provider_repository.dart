import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions/provider_exception.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';

@LazySingleton(as: IProviderRepository)
class ProviderRepository implements IProviderRepository {
  ProviderRepository(
    this._harnesseDao,
    this._modelDao,
    this._harnessModelDao,
    this._providerKeyDao,
    this._providerCatalogDao,
  );

  final HarnesseDao _harnesseDao;
  final ModelDao _modelDao;
  final HarnessModelDao _harnessModelDao;
  final ProviderKeyDao _providerKeyDao;
  final ProviderCatalogDao _providerCatalogDao;

  @override
  Stream<List<Harnesse>> watchHarnesses() => _harnesseDao.watch();

  @override
  Stream<List<Model>> watchModels() => _modelDao.watch();

  @override
  Stream<List<HarnessModel>> watchHarnessModels() => _harnessModelDao.watch();

  @override
  Stream<List<ProviderKey>> watchProviderKeys() => _providerKeyDao.watch();

  @override
  Stream<List<domain.Provider>> watchProviderCatalog() =>
      _providerCatalogDao.watch();

  @override
  Future<void> saveProviderKey(ProviderKey key) => tryMethod(
        () async {
          await _providerKeyDao.save(key.id, key.toJson());
        },
        ProviderException.new,
        'saveProviderKey',
      );

  @override
  Future<void> deleteProviderKey(String id) => tryMethod(
        () => _providerKeyDao.delete(id),
        ProviderException.new,
        'deleteProviderKey',
      );
}
