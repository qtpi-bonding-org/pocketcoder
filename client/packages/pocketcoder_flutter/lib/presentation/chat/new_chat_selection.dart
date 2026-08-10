import 'package:path/path.dart' as p;
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

/// Only these adapters have a tested private-network Ollama configuration.
/// This intentionally mirrors the backend guard before a virtual tag is shown.
bool supportsOllamaHarness(String cliId) =>
    cliId == 'goose' || cliId == 'opencode';

enum WorkspacePathValidationError {
  empty,
  outsideWorkspace,
}

/// Validates that a workspace path is within the /workspace root directory.
///
/// Implements the textual, prefix-based check from the design spec (§5.8):
/// after path normalization, the value must equal the workspace root (/workspace)
/// or have it as a path-segment prefix (/workspace/...), with no ".." segments
/// surviving normalization.
///
/// This is a client-side fast-fail nicety — the server-side check in
/// buildSessionProfile (backend) is the actual guarantee. Returns null if valid,
/// or a descriptive error message if validation fails.
WorkspacePathValidationError? validateWorkspacePath(
  String path, {
  String root = '/workspace',
}) {
  if (path.isEmpty) {
    return WorkspacePathValidationError.empty;
  }

  // Normalize the path: resolves . and .., removes trailing slashes.
  final normalized = p.normalize(path);

  if (normalized == root) return null;

  // Explicit segment-prefix check (not a bare startsWith(root)) — rejects a
  // string-prefix-but-not-segment-prefix case like "/workspace-evil".
  final withSlash = root.endsWith('/') ? root : '$root/';
  if (normalized.startsWith(withSlash)) return null;

  return WorkspacePathValidationError.outsideWorkspace;
}
