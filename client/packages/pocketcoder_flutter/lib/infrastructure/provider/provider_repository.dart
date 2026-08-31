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

  // Memoized so the 16k+ row catalog fetch (networkOnly, uncached) only
  // ever hits the network once per app session, not once per call site.
  Future<List<HarnessModel>>? _harnessModelsFuture;

  @override
  Stream<List<Harnesse>> watchHarnesses() => _harnesseDao.watch();

  @override
  Stream<List<Model>> watchModels() => _modelDao.watch();

  @override
  Future<List<HarnessModel>> fetchHarnessModels() {
    return _harnessModelsFuture ??= _fetchHarnessModelsFresh();
  }

  Future<List<HarnessModel>> _fetchHarnessModelsFresh() async {
    try {
      return await _harnessModelDao.getFullList(
        requestPolicy: RequestPolicy.networkOnly,
      );
    } catch (_) {
      // Don't let a failed fetch permanently poison every future call --
      // clear the cached future so the next call retries the network.
      _harnessModelsFuture = null;
      rethrow;
    }
  }

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
