import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';

abstract class IProviderRepository {
  Stream<List<Harnesse>> watchHarnesses();
  Stream<List<Model>> watchModels();

  /// One-shot, never-cached fetch -- harness_models is a read-only catalog
  /// (harness x model.dev-synced models) that can run to 16,000+ rows.
  /// Deliberately not a Stream: with RequestPolicy.networkOnly there is no
  /// local table to observe changes on, and this data doesn't need live
  /// reactivity (it's seeded by migrations, not user-editable).
  Future<List<HarnessModel>> fetchHarnessModels();
  Stream<List<HarnessProvider>> watchHarnessProviders();
  Stream<List<ProviderApiKey>> watchProviderAPIKeys();
  Stream<List<domain.Provider>> watchProviderCatalog();
  Future<void> saveProviderAPIKey(ProviderApiKey key);
  Future<void> deleteProviderAPIKey(String id);
}
