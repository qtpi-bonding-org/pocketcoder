import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';

/// Filters `harness_models` rows to the ones a user can actually pick for
/// [harnessId] — design spec §5.9: a model needs a `harness_models` row for
/// the selected harness, AND the current user needs a `provider_keys` row
/// for that model's provider. `models`/`providerKeys.provider` are plain,
/// uncanonicalized text (no shared enum, per the design spec's open
/// question) — this does an exact string match, which is what the spec
/// says makes a casing mismatch user-visible as "my model list is empty."
List<HarnessModel> selectableModels({
  required String harnessId,
  required List<HarnessModel> harnessModels,
  required List<Model> models,
  required List<ProviderKey> providerKeys,
}) {
  final modelsById = {for (final m in models) m.id: m};
  final keyedProviders = providerKeys.map((k) => k.provider).toSet();

  return harnessModels.where((hm) {
    if (hm.harness != harnessId) return false;
    final model = modelsById[hm.model];
    if (model == null) return false;
    return keyedProviders.contains(model.provider);
  }).toList();
}
