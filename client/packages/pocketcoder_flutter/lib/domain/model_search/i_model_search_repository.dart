import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/provider.dart' as domain;

abstract class IModelSearchRepository {
  Future<Harnesse> harnessFor(String harnessId);

  /// Only meaningful when harness.providerFanout is true -- a
  /// single-provider harness has nothing to choose between.
  Future<List<domain.Provider>> credentialedProvidersFor(String harnessId);

  Future<List<HarnessModel>> modelsFor(String harnessId, {String? providerId});
}
