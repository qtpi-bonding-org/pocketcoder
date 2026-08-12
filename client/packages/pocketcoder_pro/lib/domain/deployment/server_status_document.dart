import 'dart:convert';

class ServerStatusDocument {
  ServerStatusDocument({
    required this.schema,
    required this.runId,
    required this.phase,
    required this.updatedAt,
    required Map<String, Object?> raw,
    this.detail,
    this.sourceCommit,
    this.error,
  }) : raw = Map<String, Object?>.unmodifiable(raw);

  final int schema;
  final String runId;
  final String phase;
  final String? detail;
  final String? sourceCommit;
  final DateTime updatedAt;
  final String? error;

  /// The complete status payload, retained so newer server fields are not
  /// discarded by an older client that does not understand them yet.
  final Map<String, Object?> raw;

  /// Reads an optional backend-owned phase progress value without assigning
  /// meaning to a missing field. Older deployments expose lifecycle phases
  /// only, so callers must retain their stage-based fallback in that case.
  double? progressFor(String phase) {
    final progress = raw['progress'];
    final candidate = progress is Map<String, Object?>
        ? progress[phase]
        : raw['${phase}Progress'];
    if (candidate is! num) return null;
    final value = candidate.toDouble();
    if (value < 0 || value > 1) return null;
    return value;
  }

  static ServerStatusDocument? tryParse(String body) {
    try {
      final value = jsonDecode(body);
      if (value is! Map<String, dynamic>) return null;
      final updated = DateTime.tryParse(value['updatedAt']?.toString() ?? '');
      final runId = value['runId']?.toString();
      final phase = value['phase']?.toString();
      if (updated == null || runId == null || phase == null) return null;
      return ServerStatusDocument(
        schema: value['schema'] is num ? (value['schema'] as num).toInt() : 1,
        runId: runId,
        phase: phase,
        updatedAt: updated,
        detail: value['detail']?.toString(),
        sourceCommit: value['sourceCommit']?.toString(),
        error: value['error']?.toString(),
        raw: Map<String, Object?>.from(value),
      );
    } on Object {
      return null;
    }
  }
}
