import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';

abstract class IProviderRepository {
  Stream<List<Harnesse>> watchHarnesses();
  Stream<List<Model>> watchModels();
  Stream<List<HarnessModel>> watchHarnessModels();
  Stream<List<ProviderKey>> watchProviderKeys();
  Stream<List<domain.Provider>> watchProviderCatalog();
  Future<void> saveProviderKey(ProviderKey key);
  Future<void> deleteProviderKey(String id);
}
