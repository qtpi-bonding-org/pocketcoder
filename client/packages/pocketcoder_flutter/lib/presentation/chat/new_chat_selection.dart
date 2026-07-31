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
String? validateWorkspacePath(String path) {
  const workspaceRoot = '/workspace';

  // Empty path is invalid
  if (path.isEmpty) {
    return 'Path cannot be empty';
  }

  // Normalize the path: resolves . and .., removes trailing slashes
  final normalized = p.normalize(path);

  // Check if any ".." segments survived normalization by comparing
  // the number of ".." in the original with the normalized version
  if (normalized.contains('..')) {
    return 'Path cannot escape the workspace root via ".." traversal';
  }

  // Path must be either the workspace root itself or start with workspace root + "/"
  if (normalized == workspaceRoot || normalized.startsWith('$workspaceRoot/')) {
    return null; // Valid
  }

  // Reject relative paths and paths outside /workspace
  return 'Workspace path must be within $workspaceRoot';
}
