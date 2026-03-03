import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/collections.dart';
import 'package:pocketcoder_flutter/domain/models/llm_key.dart';
import 'package:pocketcoder_flutter/domain/models/model_selection.dart';
import 'package:pocketcoder_flutter/domain/models/llm_provider.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';

@lazySingleton
class LlmKeyDao extends BaseDao<LlmKey> {
  LlmKeyDao(PocketBase pb)
      : super(pb, Collections.llmKeys, LlmKey.fromJson);
}

@lazySingleton
class ModelSelectionDao extends BaseDao<ModelSelection> {
  ModelSelectionDao(PocketBase pb)
      : super(pb, Collections.modelSelection, ModelSelection.fromJson);
}

@lazySingleton
class LlmProviderDao extends BaseDao<LlmProvider> {
  LlmProviderDao(PocketBase pb)
      : super(pb, Collections.llmProviders, LlmProvider.fromJson);
}
