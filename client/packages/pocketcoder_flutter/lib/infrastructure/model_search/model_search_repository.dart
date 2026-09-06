import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions/model_search_exception.dart';
import 'package:pocketcoder_flutter/domain/model_search/i_model_search_repository.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/infrastructure/provider/provider_daos.dart';

@LazySingleton(as: IModelSearchRepository)
class ModelSearchRepository implements IModelSearchRepository {
  ModelSearchRepository(
    this._harnesseDao,
    this._harnessModelDao,
    this._modelDao,
    this._providerCatalogDao,
    this._providerAPIKeyDao,
  );

  final HarnesseDao _harnesseDao;
  final HarnessModelDao _harnessModelDao;
  final ModelDao _modelDao;
  final ProviderCatalogDao _providerCatalogDao;
  final ProviderAPIKeyDao _providerAPIKeyDao;

  @override
  Future<Harnesse> harnessFor(String harnessId) => tryMethod(
        () => _harnesseDao.getOne(harnessId),
        ModelSearchException.new,
        'harnessFor',
      );

  @override
  Future<List<HarnessModel>> modelsFor(String harnessId,
          {String? providerId}) =>
      tryMethod(() async {
        final harnessModels = await _harnessModelsForHarness(harnessId);
        if (providerId == null) return harnessModels;
        final modelIdsForProvider = await _modelIdsForProvider(providerId);
        return harnessModels
            .where((hm) => modelIdsForProvider.contains(hm.model))
            .toList();
      }, ModelSearchException.new, 'modelsFor');

  @override
  Future<List<domain.Provider>> credentialedProvidersFor(String harnessId) =>
      tryMethod(() async {
        final harnessModels = await _harnessModelsForHarness(harnessId);
        if (harnessModels.isEmpty) return const <domain.Provider>[];

        final models = await _modelDao.getFullList();
        final modelById = {for (final m in models) m.id: m};
        final providerAPIKeys = await _providerAPIKeyDao.getFullList();
        final credentialedProviderIds =
            providerAPIKeys.map((k) => k.provider).toSet();

        final usableProviderIds = <String>{
          for (final hm in harnessModels)
            if (modelById[hm.model] != null &&
                credentialedProviderIds.contains(modelById[hm.model]!.provider))
              modelById[hm.model]!.provider,
        };
        if (usableProviderIds.isEmpty) return const <domain.Provider>[];

        final providers = await _providerCatalogDao.getFullList();
        return providers
            .where((p) => usableProviderIds.contains(p.id))
            .toList();
      }, ModelSearchException.new, 'credentialedProvidersFor');

  Future<List<HarnessModel>> _harnessModelsForHarness(String harnessId) =>
      _harnessModelDao.getFullList(
          filter:
              _harnessModelDao.pb.filter('harness = {:h}', {'h': harnessId}));

  Future<Set<String>> _modelIdsForProvider(String providerId) async {
    final models = await _modelDao.getFullList();
    return {for (final m in models) if (m.provider == providerId) m.id};
  }
}
