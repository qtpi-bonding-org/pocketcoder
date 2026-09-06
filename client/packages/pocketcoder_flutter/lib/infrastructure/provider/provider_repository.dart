import 'package:injectable/injectable.dart';
import 'package:pocketbase_drift/pocketbase_drift.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
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
    this._auth,
  );

  final HarnesseDao _harnesseDao;
  final ModelDao _modelDao;
  final HarnessModelDao _harnessModelDao;
  final ProviderAPIKeyDao _providerAPIKeyDao;
  final HarnessProviderDao _harnessProviderDao;
  final ProviderCatalogDao _providerCatalogDao;
  final IAuthRepository _auth;

  // Both catalogs are migration-seeded, read-only, and too large (7.5k-16k+
  // rows) to pay a networkFirst resync per subscriber -- memoized so each
  // only ever hits the network once per app session, not once per call site.
  late final _modelsCache =
      _CatalogCache(() => _modelDao.getFullList(
            requestPolicy: RequestPolicy.networkOnly,
          ));
  late final _harnessModelsCache =
      _CatalogCache(() => _harnessModelDao.getFullList(
            requestPolicy: RequestPolicy.networkOnly,
          ));

  @override
  Stream<List<Harnesse>> watchHarnesses() => _harnesseDao.watch();

  @override
  Future<List<Model>> fetchModels() => _modelsCache.fetch();

  @override
  Future<List<HarnessModel>> fetchHarnessModels() =>
      _harnessModelsCache.fetch();

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
          // A brand-new key's owner is always empty (the dialog only ever
          // copies an existing record's owner). provider_api_keys.createRule
          // requires owner = @request.auth.id, and PocketBase evaluates that
          // rule against the client-submitted data itself -- there is no
          // server-side hook that can fix up owner afterward, since the
          // access check runs before any OnRecordCreateRequest hook fires.
          // The client is the only place this can be set correctly.
          if (key.id.isEmpty) {
            body['owner'] = _auth.currentUserId;
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

/// A transient network error must not permanently poison every later call,
/// so only a successful [_fetch] gets memoized.
class _CatalogCache<T> {
  _CatalogCache(this._fetch);

  final Future<List<T>> Function() _fetch;
  Future<List<T>>? _future;

  Future<List<T>> fetch() => _future ??= _fetchFresh();

  Future<List<T>> _fetchFresh() async {
    try {
      return await _fetch();
    } catch (_) {
      _future = null;
      rethrow;
    }
  }
}
