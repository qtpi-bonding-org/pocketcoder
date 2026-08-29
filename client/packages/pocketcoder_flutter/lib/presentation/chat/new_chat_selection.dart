import 'package:path/path.dart' as p;
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/harness_oauth_account.dart';
import 'package:pocketcoder_flutter/domain/models/harness_provider.dart';
import 'package:pocketcoder_flutter/domain/models/provider_api_key.dart';
import 'package:pocketcoder_flutter/domain/models/credential_selection.dart';

/// Filters `harness_models` rows to the ones a user can actually pick for
/// [harnessId] — a model needs a `harness_models` row, a
/// `harness_providers` edge, and a usable credential for that provider.
List<HarnessModel> selectableModels({
  required String harnessId,
  required List<HarnessModel> harnessModels,
  required List<Model> models,
  required List<HarnessProvider> harnessProviders,
  required List<ProviderApiKey> providerAPIKeys,
  List<CredentialSelection> credentialSelections = const [],
  List<HarnessOauthAccount> harnessOAuthAccounts = const [],
}) {
  final modelsById = {for (final m in models) m.id: m};
  final usableProviders = <String>{};
  for (final edge in harnessProviders.where((e) => e.harness == harnessId)) {
    final selection = credentialSelections
        .where((s) => s.harness == harnessId && s.provider == edge.provider)
        .firstOrNull;
    if (selection?.mode == CredentialSelectionMode.none) continue;
    if (selection?.mode == CredentialSelectionMode.oauth) {
      final connected = harnessOAuthAccounts.any((account) =>
          account.harness == harnessId &&
          account.provider == edge.provider &&
          account.status == HarnessOauthAccountStatus.connected);
      if (edge.supportsOauth == true && connected) {
        usableProviders.add(edge.provider);
      }
    } else if (providerAPIKeys.any((key) => key.provider == edge.provider)) {
      usableProviders.add(edge.provider);
    }
  }

  return harnessModels.where((hm) {
    if (hm.harness != harnessId) return false;
    final model = modelsById[hm.model];
    if (model == null) return false;
    return harnessProviders.any((edge) =>
        edge.harness == harnessId &&
        edge.provider == model.provider &&
        usableProviders.contains(edge.provider));
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

  final normalized = p.normalize(path);

  if (normalized == root) return null;

  // Explicit segment-prefix check (not a bare startsWith(root)) — rejects a
  // string-prefix-but-not-segment-prefix case like "/workspace-evil".
  final withSlash = root.endsWith('/') ? root : '$root/';
  if (normalized.startsWith(withSlash)) return null;

  return WorkspacePathValidationError.outsideWorkspace;
}
