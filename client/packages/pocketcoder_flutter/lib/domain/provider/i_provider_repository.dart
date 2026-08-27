import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';

abstract class IProviderRepository {
  Stream<List<Harnesse>> watchHarnesses();
  Stream<List<Model>> watchModels();
  Stream<List<HarnessModel>> watchHarnessModels();
  Stream<List<HarnessProvider>> watchHarnessProviders();
  Stream<List<ProviderApiKey>> watchProviderAPIKeys();
  Stream<List<domain.Provider>> watchProviderCatalog();
  Future<void> saveProviderAPIKey(ProviderApiKey key);
  Future<void> deleteProviderAPIKey(String id);
}
