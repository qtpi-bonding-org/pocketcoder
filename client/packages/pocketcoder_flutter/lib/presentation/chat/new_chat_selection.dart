import 'package:path/path.dart' as p;

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
