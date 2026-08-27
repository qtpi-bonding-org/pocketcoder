import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions/provider_exception.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';

@LazySingleton(as: IProviderRepository)
class ProviderRepository implements IProviderRepository {
  ProviderRepository(
    this._harnesseDao,
    this._modelDao,
    this._harnessModelDao,
    this._providerAPIKeyDao,
    this._harnessProviderDao,
    this._providerCatalogDao,
  );

  final HarnesseDao _harnesseDao;
  final ModelDao _modelDao;
  final HarnessModelDao _harnessModelDao;
  final ProviderAPIKeyDao _providerAPIKeyDao;
  final HarnessProviderDao _harnessProviderDao;
  final ProviderCatalogDao _providerCatalogDao;

  @override
  Stream<List<Harnesse>> watchHarnesses() => _harnesseDao.watch();

  @override
  Stream<List<Model>> watchModels() => _modelDao.watch();

  @override
  Stream<List<HarnessModel>> watchHarnessModels() => _harnessModelDao.watch();

  @override
  Stream<List<HarnessProvider>> watchHarnessProviders() =>
      _harnessProviderDao.watch();

  @override
  Stream<List<ProviderApiKey>> watchProviderAPIKeys() =>
      _providerAPIKeyDao.watch();

  @override
  Stream<List<domain.Provider>> watchProviderCatalog() =>
      _providerCatalogDao.watch();

  @override
  Future<void> saveProviderAPIKey(ProviderApiKey key) => tryMethod(
        () async {
          final body = key.toJson();
          // The API key is hidden on reads. An empty key on an update means
          // that the existing secret should remain unchanged.
          if (key.id.isNotEmpty && key.apiKey.isEmpty) {
            body.remove('api_key');
          }
          await _providerAPIKeyDao.save(key.id, body);
        },
        ProviderException.new,
        'saveProviderAPIKey',
      );

  @override
  Future<void> deleteProviderAPIKey(String id) => tryMethod(
        () => _providerAPIKeyDao.delete(id),
        ProviderException.new,
        'deleteProviderAPIKey',
      );
}
