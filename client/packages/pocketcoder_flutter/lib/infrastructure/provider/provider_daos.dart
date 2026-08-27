import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class HarnesseDao extends BaseDao<Harnesse> {
  HarnesseDao(PocketBase pb)
      : super(pb, Collections.harnesses, Harnesse.fromJson);
}

@lazySingleton
class ModelDao extends BaseDao<Model> {
  ModelDao(PocketBase pb) : super(pb, Collections.models, Model.fromJson);
}

@lazySingleton
class HarnessModelDao extends BaseDao<HarnessModel> {
  HarnessModelDao(PocketBase pb)
      : super(pb, Collections.harnessModels, HarnessModel.fromJson);
}

@lazySingleton
class ProviderAPIKeyDao extends BaseDao<ProviderApiKey> {
  ProviderAPIKeyDao(PocketBase pb)
      : super(pb, Collections.providerApiKeys, ProviderApiKey.fromJson);
}

@lazySingleton
class HarnessProviderDao extends BaseDao<HarnessProvider> {
  HarnessProviderDao(PocketBase pb)
      : super(pb, Collections.harnessProviders, HarnessProvider.fromJson);
}

/// The models.dev-synced provider catalog (internal/modelcatalog on the
/// backend) -- id, display name, and real API key env var name for every
/// provider Goose/OpenCode can use. Aliased as `domain.Provider` to avoid
/// colliding with Flutter's own ambient `Provider` name.
@lazySingleton
class ProviderCatalogDao extends BaseDao<domain.Provider> {
  ProviderCatalogDao(PocketBase pb)
      : super(pb, Collections.providers, domain.Provider.fromJson);
}
